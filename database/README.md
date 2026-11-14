# Base de Datos de ReserveSync (SQLite y PostgreSQL)

Este directorio contiene los esquemas DDL, datos iniciales de prueba, scripts de auditoría y documentación técnica de persistencia para **ReserveSync**:

1. **SQLite (`database/sqlite/`)**: Base de datos local embebida para la aplicación de escritorio JavaFX (operación *offline-first*).
2. **PostgreSQL (`database/postgresql/`)**: Base de datos central para el servidor backend en Spring Boot (gestión central y web pública).

Ambos motores comparten el mismo modelo conceptual, idénticos UUIDs de prueba y las mismas reglas de integridad de negocio.

---

## 1. Estructura de Archivos

```text
database/
├── diagrams/
│   └── modelo-er.md                  # Diagrama ER en Mermaid y diccionario de datos definitivo
├── postgresql/
│   └── schema.sql                    # DDL para PostgreSQL (TIMESTAMPTZ, triggers FOR UPDATE ordenados)
├── seed/
│   ├── postgresql_seed.sql           # Semilla común para PostgreSQL (R1 a R3, cierres UTC, BCrypt real)
│   ├── sqlite_seed.sql               # Semilla común para SQLite (R1 a R3, timestamps normalizados, idempotente)
│   └── sqlite_offline_seed.sql       # Semilla exclusiva offline para SQLite (Reservación R4 y Outbox)
├── sqlite/
│   └── schema.sql                    # DDL para SQLite (FOREIGN KEYS, triggers, CHECK estricto de timestamps)
├── tests/
│   ├── test_sqlite_suite.py          # Batería de 14 pruebas automatizadas de integridad en SQLite
│   ├── test_postgresql_integrity.sql # Script SQL de validación de integridad para PostgreSQL (\set ON_ERROR_STOP on)
│   ├── test_postgresql_concurrency.ps1 # Automatización PowerShell de pruebas de concurrencia en paralelo
│   ├── concurrencia_escenario1_s1.sql  # Escenario 1 - Sesión 1: Reserva de mesa M-02 con retención FOR UPDATE
│   ├── concurrencia_escenario1_s2.sql  # Escenario 1 - Sesión 2: Intento simultáneo sobre mesa M-02
│   ├── concurrencia_escenario2_s1.sql  # Escenario 2 - Sesión 1: Reserva grupal M-03 y M-04 ordenada
│   ├── concurrencia_escenario2_s2.sql  # Escenario 2 - Sesión 2: Reserva grupal M-04 y M-03 en orden inverso (No Deadlock)
│   ├── concurrencia_escenario3_s1.sql  # Escenario 3 - Sesión 1: Creación de cierre en TERRAZA
│   ├── concurrencia_escenario3_s2.sql  # Escenario 3 - Sesión 2: Intento simultáneo de reservar en TERRAZA
│   ├── concurrencia_escenario4_s1.sql  # Escenario 4 - Sesión 1: Desactivación de mesa M-06 a MANTENIMIENTO
│   └── concurrencia_escenario4_s2.sql  # Escenario 4 - Sesión 2: Intento simultáneo de reservar mesa M-06
└── README.md                         # Esta guía técnica de arquitectura y ejecución
```

---

## 2. Normalización Estricta de Timestamps en SQLite

SQLite carece de un tipo nativo `TIMESTAMPTZ`. Si se almacena texto libre o fechas con diferentes zonas horarias (ej. `-06:00`), las comparaciones lexicográficas estándar (`<`, `>`, `<=`, `>=`) fallan silenciosamente.

Por ello, el esquema de SQLite establece el formato obligatorio de precisión fija de **24 caracteres**:
```text
YYYY-MM-DDTHH:MM:SS.SSSZ
```

### 2.1 Restricciones CHECK Implementadas
En las columnas `fecha_hora_inicio` y `fecha_hora_fin` de `reservaciones` y `cierres`, se aplican las siguientes reglas:
1. Longitud exacta: `length(ts) = 24`.
2. Patrón de caracteres con milisegundos de 3 dígitos y terminador literal `Z`:
   `ts GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9].[0-9][0-9][0-9]Z'`.
3. Validación de calendario real: `datetime(ts) IS NOT NULL AND strftime('%Y-%m-%dT%H:%M:%S', ts) = substr(ts, 1, 19)`.
   Esto rechaza automáticamente anomalías como el 31 de febrero, horas mayores a 23, minutos mayores a 59 o años no bisiestos inválidos.
4. Rechazo total de husos horarios locales (ej. `2026-11-15T14:00:00-06:00`).

### 2.2 Generación en el Backend Java (Spring Boot / JavaFX)
El backend nunca debe añadir simplemente una `Z` al final de una hora local, ya que eso falsearía el instante real por 6 horas. La conversión debe realizarse explícitamente mediante la API de fecha y hora de Java 21 (`java.time`):

```java
// Ejemplo canónico de conversión en el servicio backend
ZoneId zonaRestaurante = ZoneId.of("America/Mexico_City");

// 1. Captura de hora local seleccionada por el cliente (ej. 14:00 CDMX)
LocalDateTime horaLocal = LocalDateTime.of(2026, 11, 15, 14, 0, 0);

// 2. Vinculación al huso oficial del establecimiento (UTC-6)
ZonedDateTime horaConZona = horaLocal.atZone(zonaRestaurante);

// 3. Conversión al instante absoluto UTC
Instant instanteUtc = horaConZona.toInstant();

// 4. Formateo estricto con milisegundos y sufijo Z
DateTimeFormatter formateadorUtc = DateTimeFormatter.ofPattern("uuuu-MM-dd'T'HH:mm:ss.SSS'Z'")
                                                   .withZone(ZoneOffset.UTC);

String timestampNormalizado = formateadorUtc.format(instanteUtc);
// Resultado: "2026-11-15T20:00:00.000Z" (exactamente 24 caracteres)
```

En PostgreSQL, las columnas utilizan el tipo nativo `TIMESTAMPTZ`, el cual almacena internamente la época Unix en microsegundos y preserva la compatibilidad nativa de PostgreSQL.

---

## 3. Alcance Estricto de la Tabla `cierres`

Para garantizar que ningún registro de cierre sea ambiguo o incompleto, SQLite y PostgreSQL imponen la siguiente restricción de dominio:

```sql
CONSTRAINT chk_cierres_tipo_alcance CHECK (
    (tipo_cierre = 'TOTAL_RESTAURANTE' AND zona IS NULL AND mesa_id IS NULL)
    OR (tipo_cierre = 'ZONA' AND zona IS NOT NULL AND mesa_id IS NULL)
    OR (tipo_cierre = 'MESA_ESPECIFICA' AND mesa_id IS NOT NULL AND zona IS NULL)
),
CONSTRAINT chk_cierres_intervalo CHECK (fecha_hora_fin > fecha_hora_inicio)
```

- Un cierre `TOTAL_RESTAURANTE` rechaza cualquier especificación de zona o mesa.
- Un cierre `ZONA` exige una zona válida y rechaza identificadores de mesa.
- Un cierre `MESA_ESPECIFICA` exige obligatoriamente `mesa_id` y exige que `zona` sea `NULL`.

---

## 4. Reglas de Asignación y Reactivación de Reservaciones

### 4.1 Definición de Estados de Ocupación
- **Estados que OCUPAN una mesa:** `PENDIENTE`, `CONFIRMADA` y `SENTADA`.
- **Estados que LIBERAN una mesa (no bloquean disponibilidad):** `COMPLETADA`, `CANCELADA`, `NO_ASISTIO` y `RECHAZADA`.

### 4.2 Reactivación de Reservaciones
Cuando una reservación cancelada o eliminada lógicamente se intenta reactivar (cambio a `PENDIENTE`, `CONFIRMADA` o `SENTADA`, o eliminación de `deleted_at`), los triggers `trg_validar_reserva_update` (SQLite) y `fn_validar_reserva_update` (PostgreSQL) inspeccionan **todas las mesas asignadas**:
1. Si alguna mesa ya no existe en el catálogo, la operación se cancela.
2. Si alguna mesa tiene `estado_operativo != 'ACTIVA'` (ej. fue puesta en mantenimiento mientras la reserva estuvo cancelada), la reactivación se cancela.
3. Si alguna mesa tiene `deleted_at IS NOT NULL` (fue eliminada lógicamente), la reactivación se cancela.
4. Se revalida que ninguna de las mesas colisione con otras reservaciones activas en el horario actual.
5. Se revalida que el restaurante o las mesas no tengan un cierre activo en ese intervalo.

---

## 5. Concurrencia y Prevención de Deadlocks en PostgreSQL

Para garantizar que no existan condiciones de carrera ni bloqueos mutuos (*deadlocks*):

1. **Serialización Pesimista:** Al asignar mesas o revalidar reservas, se adquieren bloqueos exclusivos sobre las filas de `mesas` mediante `SELECT ... FOR UPDATE;`.
2. **Orden Determinista Obligatorio:** En reservaciones que abarcan múltiples mesas (ej. M-03 y M-04), los identificadores de las mesas se ordenan ascendentemente antes de solicitar los bloqueos:
   ```sql
   PERFORM 1 FROM mesas
   WHERE id IN (SELECT mesa_id FROM detalle_reservacion WHERE reservacion_id = NEW.id)
   ORDER BY id ASC
   FOR UPDATE;
   ```
   **Regla para la capa de servicio Java:** La aplicación Spring Boot debe ordenar siempre la lista de mesas por su UUID antes de ejecutar la transacción de asignación:
   `SELECT id FROM mesas WHERE id IN (:mesaIds) ORDER BY id ASC FOR UPDATE;`.
   Esto garantiza que dos peticiones simultáneas que compitan por las mismas mesas soliciten los recursos en el mismo orden, transformando un potencial *deadlock* en una espera lineal pasiva.

---

## 6. Propuesta Arquitectónica de Sincronización Monotónica

La columna `sync_cursor.last_sync_sequence` proporciona un punto de corte monotónico para las terminales de escritorio. A continuación se documenta el diseño para la futura etapa de backend:

### 6.1 Modelo de Bitácora Central en PostgreSQL
En la base de datos central se creará una secuencia global y una bitácora de eventos inmutable:
```sql
CREATE SEQUENCE global_sync_seq START WITH 1 INCREMENT BY 1;

CREATE TABLE sync_changelog (
    sequence_number BIGINT PRIMARY KEY DEFAULT nextval('global_sync_seq'),
    entity_name VARCHAR(50) NOT NULL,
    entity_id UUID NOT NULL,
    action VARCHAR(20) NOT NULL CHECK (action IN ('CREATE', 'UPDATE', 'DELETE')),
    origin_terminal_id VARCHAR(60) NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_sync_changelog_seq ON sync_changelog (sequence_number);
```

### 6.2 Flujo PULL (Servidor Central -> Terminal de Escritorio)
1. La aplicación de escritorio solicita cambios: `GET /api/v1/sync/pull?terminal_id=TERMINAL_CAJA_01&since_sequence=120`.
2. El backend consulta:
   ```sql
   SELECT sequence_number, entity_name, entity_id, action, payload, created_at
   FROM sync_changelog
   WHERE sequence_number > :since_sequence
     AND origin_terminal_id != :terminal_id
   ORDER BY sequence_number ASC
   LIMIT 100;
   ```
3. La aplicación de escritorio aplica el lote localmente dentro de una única transacción SQLite y actualiza su cursor:
   ```sql
   UPDATE sync_cursor
   SET last_sync_sequence = :max_seq,
       last_sync_id = :last_entity_id,
       last_sync_timestamp = :last_created_at,
       updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
   WHERE terminal_id = 'TERMINAL_CAJA_01' AND direccion = 'PULL';
   ```

### 6.3 Flujo PUSH (Terminal de Escritorio -> Servidor Central)
1. La aplicación de escritorio lee registros en `sync_outbox WHERE status = 'PENDIENTE'` en orden de creación.
2. Envía las mutaciones al backend mediante `POST /api/v1/sync/push`.
3. El backend procesa las operaciones en PostgreSQL de forma atómica:
   - Valida la disponibilidad e inserta/actualiza las entidades.
   - Inserta un registro en `sync_changelog` para cada cambio (obteniendo un nuevo `sequence_number`).
   - Responde con la lista de `operation_id` aprobados.
4. La aplicación de escritorio marca las operaciones locales en `sync_outbox` como `COMPLETADO`.

---

## 7. Instrucciones de Ejecución en Windows (PowerShell)

### A. Para SQLite (Validado 100% con 14 Pruebas)

Ejecuta en una consola de PowerShell posicionándote en la raíz del proyecto (`C:\Projects\ReserveSync`):

```powershell
# 1. Crear base de datos local
sqlite3 reservesync_local.db ".read database/sqlite/schema.sql"

# 2. Cargar datos comunes iniciales
sqlite3 reservesync_local.db ".read database/seed/sqlite_seed.sql"

# 3. Cargar reservación offline R4 y cola outbox
sqlite3 reservesync_local.db ".read database/seed/sqlite_offline_seed.sql"

# 4. Ejecutar la batería de 14 pruebas automatizadas
python database/tests/test_sqlite_suite.py
```

### B. Para PostgreSQL (Base de Pruebas Dedicada)

```powershell
# 1. Configurar la contraseña de la sesión de PostgreSQL
$env:PGPASSWORD = "tu_password_local"
$psql = "C:\Program Files\PostgreSQL\18\bin\psql.exe"

# 2. Ejecutar la batería de pruebas de integridad SQL
& $psql -U postgres -d reservesync_test_db -f database/tests/test_postgresql_integrity.sql

# 3. Ejecutar la batería de 5 escenarios de concurrencia real en paralelo
powershell -ExecutionPolicy Bypass -File .\database\tests\test_postgresql_concurrency.ps1
```
