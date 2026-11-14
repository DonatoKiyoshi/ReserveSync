<#
.SYNOPSIS
    Ejecutor Automatizado de Pruebas de Concurrencia en PostgreSQL (2 Sesiones Paralelas).
.DESCRIPTION
    Ejecuta 5 escenarios de concurrencia real entre dos conexiones independientes:
    1. Dos sesiones compitiendo por la misma mesa (Race condition).
    2. Dos sesiones compitiendo por mesas compartidas en orden inverso (Prevención de Deadlocks).
    3. Creación concurrente de un cierre vs asignación de mesa afectada.
    4. Desactivación administrativa de mesa vs asignación concurrente.
    5. Reactivación de reservación cancelada vs desactivación concurrente de mesa (M-05).

    Verificaciones rigurosas:
    - Comprobación real de conectividad inicial sin bloqueos interactivos (-w).
    - Validación explícita del código de salida ($LASTEXITCODE) en cada paso de inicialización DDL y semillas.
    - Preparación y verificación previa en BD antes de iniciar la concurrencia del Escenario 5.
    - Sincronización determinista de alta precisión mediante pg_locks y pg_stat_activity.
    - Detección y rechazo inequívoco de timeouts (SQLSTATE P0001 nunca se acepta como éxito).
    - Sesión 1 debe finalizar con código 0 (éxito total).
    - Sesión 2 debe ser rechazada específicamente por el trigger correspondiente con SQLSTATE 23514.
    - Descarte de falsos positivos (errores de sintaxis 42601, UUID 22P02, FK 23503 o timeouts P0001).
    - Consultas finales de integridad con conteos exactos en la base de datos.
    - Código de salida 0 si todos los escenarios pasan, 1 si hay fallos, 2 si PostgreSQL no está disponible.
#>

param(
    [string]$DbName = "reservesync_test_db",
    [string]$DbUser = "postgres",
    [string]$DbHost = "localhost",
    [string]$DbPort = "5432",
    [string]$DbPassword = $env:PGPASSWORD
)

if ($DbPassword) {
    $env:PGPASSWORD = $DbPassword
}

$psqlCmd = "psql"
if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
    $commonPaths = @(
        "C:\Program Files\PostgreSQL\18\bin\psql.exe",
        "C:\Program Files\PostgreSQL\17\bin\psql.exe",
        "C:\Program Files\PostgreSQL\16\bin\psql.exe",
        "C:\Program Files\PostgreSQL\15\bin\psql.exe"
    )
    foreach ($p in $commonPaths) {
        if (Test-Path $p) {
            $psqlCmd = $p
            break
        }
    }
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "RESERVESYNC - PRUEBAS DE CONCURRENCIA REAL EN POSTGRESQL (2 CONEXIONES)" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Binario: $psqlCmd"
Write-Host "Destino de pruebas: ${DbUser}@${DbHost}:${DbPort}/${DbName}"

# 1. Comprobación preliminar de conectividad (con flag -w para evitar prompts interactivos)
$testConn = & $psqlCmd -U $DbUser -h $DbHost -p $DbPort -w -c "SELECT 1;" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[AVISO CRITICO DE ENTORNO]" -ForegroundColor Yellow
    Write-Host "No se pudo establecer conexion al servidor PostgreSQL local (${DbUser}@${DbHost}:${DbPort})." -ForegroundColor Yellow
    Write-Host "Motivo: Autenticacion rechazada o contrasena no configurada en `$env:PGPASSWORD / parametro -DbPassword." -ForegroundColor Yellow
    Write-Host "Estado de la prueba: DECLARADA PENDIENTE DE EJECUCION LOCAL." -ForegroundColor Yellow
    Write-Host "Para ejecutarla manualmente suministrando la contrasena:" -ForegroundColor White
    Write-Host "  powershell -ExecutionPolicy Bypass -File .\database\tests\test_postgresql_concurrency.ps1 -DbPassword 'tu_password'`n" -ForegroundColor Gray
    exit 2
}

# 2. Inicialización estricta de la base de datos de pruebas (NO PRODUCCION)
Write-Host "`n[PASO 1] Inicializando base de datos de prueba '$DbName'..." -ForegroundColor White

function Ejecutar-PsqlComando {
    param(
        [string]$Descripcion,
        [string[]]$Argumentos
    )
    Write-Host "  -> $Descripcion..." -NoNewline
    $res = & $psqlCmd @Argumentos 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host " FALLO" -ForegroundColor Red
        Write-Host "Error durante: $Descripcion" -ForegroundColor Red
        Write-Host ($res | Out-String) -ForegroundColor DarkRed
        exit 1
    }
    Write-Host " OK" -ForegroundColor Green
}

# Conexión a la base de mantenimiento 'postgres' para recrear la base de pruebas
Ejecutar-PsqlComando -Descripcion "DROP DATABASE IF EXISTS $DbName" -Argumentos @("-U", $DbUser, "-h", $DbHost, "-p", $DbPort, "-d", "postgres", "-c", "DROP DATABASE IF EXISTS $DbName;")
Ejecutar-PsqlComando -Descripcion "CREATE DATABASE $DbName ENCODING 'UTF8'" -Argumentos @("-U", $DbUser, "-h", $DbHost, "-p", $DbPort, "-d", "postgres", "-c", "CREATE DATABASE $DbName ENCODING 'UTF8';")

# Carga de DDL y datos semilla en la base recién creada con validación estricta de errores
Ejecutar-PsqlComando -Descripcion "Carga de esquema DDL (schema.sql)" -Argumentos @("-U", $DbUser, "-h", $DbHost, "-p", $DbPort, "-d", $DbName, "-v", "ON_ERROR_STOP=1", "-f", "database/postgresql/schema.sql")
Ejecutar-PsqlComando -Descripcion "Carga de semillas iniciales (postgresql_seed.sql)" -Argumentos @("-U", $DbUser, "-h", $DbHost, "-p", $DbPort, "-d", $DbName, "-v", "ON_ERROR_STOP=1", "-f", "database/seed/postgresql_seed.sql")

Write-Host "  -> Base de pruebas inicializada y verificada correctamente al 100%." -ForegroundColor Green

$script:huboFallos = $false

function Ejecutar-Escenario {
    param(
        [string]$Nombre,
        [string]$ScriptS1,
        [string]$ScriptS2,
        [string]$QueryVerificacion,
        [int]$ResultadoEsperadoQuery,
        [string]$PatronEsperadoS2 = $null,
        [string]$MensajeExitoS2 = $null,
        [string]$AppS1 = $null,
        [string]$AppS2 = $null
    )

    Write-Host "`n--- Ejecutando $Nombre ---" -ForegroundColor Yellow
    $f1 = Join-Path $PSScriptRoot $ScriptS1
    $f2 = Join-Path $PSScriptRoot $ScriptS2

    $passParam = $env:PGPASSWORD

    $job1 = Start-Job -ScriptBlock {
        param($cmd, $u, $h, $p, $d, $pw, $f, $appname)
        if ($pw) { $env:PGPASSWORD = $pw }
        if ($appname) { $env:PGAPPNAME = $appname }
        & $cmd -U $u -h $h -p $p -d $d -v VERBOSITY=verbose -f $f 2>&1
        return $LASTEXITCODE
    } -ArgumentList $psqlCmd, $DbUser, $DbHost, $DbPort, $DbName, $passParam, $f1, $AppS1

    Start-Sleep -Milliseconds 250

    $job2 = Start-Job -ScriptBlock {
        param($cmd, $u, $h, $p, $d, $pw, $f, $appname)
        if ($pw) { $env:PGPASSWORD = $pw }
        if ($appname) { $env:PGAPPNAME = $appname }
        & $cmd -U $u -h $h -p $p -d $d -v VERBOSITY=verbose -f $f 2>&1
        return $LASTEXITCODE
    } -ArgumentList $psqlCmd, $DbUser, $DbHost, $DbPort, $DbName, $passParam, $f2, $AppS2

    Wait-Job $job1, $job2 | Out-Null

    $out1 = Receive-Job $job1
    $out2 = Receive-Job $job2
    $code1 = $out1[-1]
    $code2 = $out2[-1]

    Remove-Job $job1, $job2

    $rawOut1 = ($out1 | Out-String)
    $rawOut2 = ($out2 | Out-String)

    # 1. Validación Sesión 1: Debe terminar sin errores (código 0)
    $s1Ok = ($code1 -eq 0)
    if ($s1Ok) {
        Write-Host "  [Sesion 1] OK: Completo y confirmo su transaccion exitosamente (exit code 0)." -ForegroundColor Green
    } else {
        Write-Host "  [Sesion 1] FALLO: Termino con error no esperado (exit code $code1)." -ForegroundColor Red
        Write-Host "    Detalle Sesion 1:`n$rawOut1" -ForegroundColor DarkRed
    }

    # 2. Validación Sesión 2: Descarte explícito de TIMEOUT y errores no deseados
    $esTimeout = ($rawOut2 -match "P0001|Timeout de sincronizacion")
    $esErrorInvalido = ($rawOut2 -match "42601|syntax error|22P02|invalid input syntax|23503|foreign key constraint|23502|violates not-null")

    # 3. Comprobación del SQLSTATE 23514 y patrón de texto específico
    $esError23514 = ($rawOut2 -match "23514|check_violation")
    $cumplePatronTexto = $true
    if ($PatronEsperadoS2) {
        $cumplePatronTexto = ($rawOut2 -match $PatronEsperadoS2)
    } else {
        $cumplePatronTexto = ($rawOut2 -match "Conflicto|Disponibilidad|Integridad")
    }

    # 4. Confirmación de detección y espera del bloqueo previo (si aplica)
    $cumpleEspera = $true
    if ($MensajeExitoS2) {
        $cumpleEspera = ($rawOut2 -match [regex]::Escape($MensajeExitoS2))
    }

    $s2Ok = ($code2 -ne 0) -and (-not $esTimeout) -and (-not $esErrorInvalido) -and $esError23514 -and $cumplePatronTexto -and $cumpleEspera

    if ($s2Ok) {
        Write-Host "  [Sesion 2] OK: Bloqueo detectado, retenida en espera y rechazada por regla de negocio esperada (SQLSTATE 23514)." -ForegroundColor Green
    } else {
        Write-Host "  [Sesion 2] FALLO: No se obtuvo el comportamiento esperado de concurrencia." -ForegroundColor Red
        if ($code2 -eq 0) {
            Write-Host "    Motivo: Sesion 2 termino con exito (permitio colision indebida)." -ForegroundColor DarkRed
        } elseif ($esTimeout) {
            Write-Host "    Motivo: Sesion 2 fallo por TIMEOUT DE SINCRONIZACION (SQLSTATE P0001). No se detecto el bloqueo de Sesion 1 a tiempo." -ForegroundColor DarkRed
        } elseif ($esErrorInvalido) {
            Write-Host "    Motivo: Sesion 2 fallo por error invalido (sintaxis 42601, UUID 22P02 o FK 23503)." -ForegroundColor DarkRed
        } elseif (-not $esError23514) {
            Write-Host "    Motivo: Sesion 2 no arrojo el SQLSTATE 23514 (check_violation)." -ForegroundColor DarkRed
        } elseif (-not $cumplePatronTexto) {
            Write-Host "    Motivo: El mensaje de error de Sesion 2 no coincide con el trigger esperado: '$PatronEsperadoS2'." -ForegroundColor DarkRed
        } elseif (-not $cumpleEspera) {
            Write-Host "    Motivo: Sesion 2 no confirmo haber detectado el bloqueo RowShareLock antes de actuar: '$MensajeExitoS2'." -ForegroundColor DarkRed
        }
        Write-Host "    Detalle Sesion 2:`n$rawOut2" -ForegroundColor DarkRed
    }

    # 5. Validación en BD: Conteo exacto mediante consulta SQL
    $dbCheckOk = $false
    if ($QueryVerificacion) {
        $countResult = & $psqlCmd -U $DbUser -h $DbHost -p $DbPort -d $DbName -t -A -c $QueryVerificacion 2>&1
        $count = [int]($countResult.ToString().Trim())
        if ($count -eq $ResultadoEsperadoQuery) {
            Write-Host "  [Integridad en BD] OK: Conteo exacto registrado en BD ($count, esperado $ResultadoEsperadoQuery)." -ForegroundColor Green
            $dbCheckOk = $true
        } else {
            Write-Host "  [Integridad en BD] FALLO: Se registraron $count registros en BD (esperados: $ResultadoEsperadoQuery)." -ForegroundColor Red
            $dbCheckOk = $false
        }
    } else {
        $dbCheckOk = $true
    }

    $escenarioAprobado = $s1Ok -and $s2Ok -and $dbCheckOk
    if ($escenarioAprobado) {
        Write-Host "  ==> RESUMEN $Nombre : APROBADO" -ForegroundColor Green
    } else {
        Write-Host "  ==> RESUMEN $Nombre : FALLIDO" -ForegroundColor Red
        $script:huboFallos = $true
    }
}

# ============================================================================
# ESCENARIOS 1 A 4 (CONSERVADOS INTACTOS)
# ============================================================================

# ESCENARIO 1: Misma mesa simultánea (M-02)
Ejecutar-Escenario `
    -Nombre "Escenario 1: Dos sesiones reservando la misma mesa (M-02)" `
    -ScriptS1 "concurrencia_escenario1_s1.sql" `
    -ScriptS2 "concurrencia_escenario1_s2.sql" `
    -QueryVerificacion "SELECT count(*) FROM detalle_reservacion WHERE mesa_id = '20000000-0000-0000-0000-000000000002'::uuid AND reservacion_id IN ('60000000-0000-0000-0000-000000000101'::uuid, '60000000-0000-0000-0000-000000000102'::uuid);" `
    -ResultadoEsperadoQuery 1

# ESCENARIO 2: Dos mesas compartidas en orden inverso (Prevención de Deadlocks)
Ejecutar-Escenario `
    -Nombre "Escenario 2: Mesas compartidas en orden inverso (Prevención de Deadlocks)" `
    -ScriptS1 "concurrencia_escenario2_s1.sql" `
    -ScriptS2 "concurrencia_escenario2_s2.sql" `
    -QueryVerificacion "SELECT count(DISTINCT reservacion_id) FROM detalle_reservacion WHERE reservacion_id IN ('60000000-0000-0000-0000-000000000201'::uuid, '60000000-0000-0000-0000-000000000202'::uuid);" `
    -ResultadoEsperadoQuery 1

# ESCENARIO 3: Creación de cierre vs Asignación concurrente
Ejecutar-Escenario `
    -Nombre "Escenario 3: Cierre programado en TERRAZA vs Reserva simultánea" `
    -ScriptS1 "concurrencia_escenario3_s1.sql" `
    -ScriptS2 "concurrencia_escenario3_s2.sql" `
    -QueryVerificacion "SELECT count(*) FROM detalle_reservacion WHERE reservacion_id = '60000000-0000-0000-0000-000000000302'::uuid;" `
    -ResultadoEsperadoQuery 0

# ESCENARIO 4: Desactivación de mesa vs Reserva concurrente
Ejecutar-Escenario `
    -Nombre "Escenario 4: Desactivación de mesa M-06 vs Reserva simultánea" `
    -ScriptS1 "concurrencia_escenario4_s1.sql" `
    -ScriptS2 "concurrencia_escenario4_s2.sql" `
    -QueryVerificacion "SELECT count(*) FROM detalle_reservacion WHERE reservacion_id = '60000000-0000-0000-0000-000000000402'::uuid;" `
    -ResultadoEsperadoQuery 0

# ============================================================================
# ESCENARIO 5: Reactivación de reservación vs Desactivación concurrente de mesa (M-05)
# ============================================================================
Write-Host "`n--- Preparando Escenario 5: Creacion de reservacion previa CANCELADA con mesa M-05 asignada ---" -ForegroundColor Yellow

$sqlPreparacionE5 = @"
-- Limpieza defensiva de registros previos de E5
DELETE FROM detalle_reservacion WHERE reservacion_id = '60000000-0000-0000-0000-000000000501'::uuid;
DELETE FROM reservaciones WHERE id = '60000000-0000-0000-0000-000000000501'::uuid;

-- 1. Crear la reservacion RS-CONC-E5-S1 inicialmente en estado CONFIRMADA
INSERT INTO reservaciones (
    id, codigo_reserva, cliente_id, canal_origen, fecha_reserva,
    fecha_hora_inicio, fecha_hora_fin, cantidad_personas, estado_reserva, estado_sync
) VALUES (
    '60000000-0000-0000-0000-000000000501'::uuid, 'RS-CONC-E5-S1',
    '50000000-0000-0000-0000-000000000001'::uuid, 'DESKTOP_LOCAL', '2026-11-29',
    '2026-11-29T20:00:00Z', '2026-11-29T22:00:00Z', 4, 'CONFIRMADA', 'SYNCED'
);

-- 2. Asignarle la mesa M-05 (valida porque estado_reserva es CONFIRMADA)
INSERT INTO detalle_reservacion (id, reservacion_id, mesa_id) VALUES (
    '70000000-0000-0000-0000-000000000501'::uuid,
    '60000000-0000-0000-0000-000000000501'::uuid,
    '20000000-0000-0000-0000-000000000005'::uuid -- M-05
);

-- 3. Cambiar posteriormente la reservacion a CANCELADA (conservando detalle_reservacion)
UPDATE reservaciones
SET estado_reserva = 'CANCELADA'
WHERE id = '60000000-0000-0000-0000-000000000501'::uuid;
"@

$prepResult = & $psqlCmd -U $DbUser -h $DbHost -p $DbPort -d $DbName -v ON_ERROR_STOP=1 -c $sqlPreparacionE5 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  [Preparacion E5] FALLO: Error al ejecutar la preparacion previa." -ForegroundColor Red
    Write-Host "  Detalle:`n$prepResult" -ForegroundColor DarkRed
    $script:huboFallos = $true
} else {
    # 4. Verificar que la preparación terminó correctamente antes de iniciar la concurrencia
    $checkPrep = & $psqlCmd -U $DbUser -h $DbHost -p $DbPort -d $DbName -t -A -c "SELECT count(*) FROM reservaciones r JOIN detalle_reservacion dr ON dr.reservacion_id = r.id WHERE r.id = '60000000-0000-0000-0000-000000000501'::uuid AND r.estado_reserva = 'CANCELADA' AND dr.mesa_id = '20000000-0000-0000-0000-000000000005'::uuid;" 2>&1
    if ([int]($checkPrep.ToString().Trim()) -eq 1) {
        Write-Host "  [Preparacion E5] OK: Reservacion CANCELADA con mesa M-05 asignada verificada en BD." -ForegroundColor Green

        # Ejecución concurrente determinista con validación de trigger específico y comprobación de espera
        Ejecutar-Escenario `
            -Nombre "Escenario 5: Reactivacion de reservacion vs Desactivacion concurrente de mesa (M-05)" `
            -ScriptS1 "concurrencia_escenario5_s1.sql" `
            -ScriptS2 "concurrencia_escenario5_s2.sql" `
            -QueryVerificacion "SELECT count(*) FROM reservaciones r JOIN detalle_reservacion dr ON dr.reservacion_id = r.id JOIN mesas m ON dr.mesa_id = m.id WHERE r.id = '60000000-0000-0000-0000-000000000501'::uuid AND r.estado_reserva = 'CONFIRMADA' AND r.deleted_at IS NULL AND m.id = '20000000-0000-0000-0000-000000000005'::uuid AND m.estado_operativo = 'ACTIVA' AND m.deleted_at IS NULL;" `
            -ResultadoEsperadoQuery 1 `
            -PatronEsperadoS2 "RS-CONC-E5-S1" `
            -MensajeExitoS2 "Bloqueo RowShareLock de Sesion 1 detectado en public.mesas" `
            -AppS1 "reservesync_e5_s1" `
            -AppS2 "reservesync_e5_s2"
    } else {
        Write-Host "  [Preparacion E5] FALLO: Verificacion en BD de la preparacion no arrojo el conteo esperado (1)." -ForegroundColor Red
        $script:huboFallos = $true
    }
}

# ============================================================================
# BALANCE FINAL DE LA BATERÍA
# ============================================================================
Write-Host "`n======================================================================" -ForegroundColor Cyan
if ($script:huboFallos) {
    Write-Host "BATERIA DE CONCURRENCIA EN POSTGRESQL FINALIZADA CON ERRORES" -ForegroundColor Red
    Write-Host "======================================================================" -ForegroundColor Cyan
    exit 1
} else {
    Write-Host "TODOS LOS ESCENARIOS DE CONCURRENCIA EN POSTGRESQL APROBADOS (5/5)" -ForegroundColor Green
    Write-Host "======================================================================" -ForegroundColor Cyan
    exit 0
}
