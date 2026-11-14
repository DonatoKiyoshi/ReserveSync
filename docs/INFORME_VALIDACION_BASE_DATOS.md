# INFORME TÉCNICO DE VALIDACIÓN DE BASES DE DATOS — RESERVESYNC

**Proyecto:** ReserveSync — Sistema de Gestión de Reservaciones y Sincronización
**Documento:** Informe Técnico de Validación de Capa de Datos
**Versión:** 1.2
**Fecha de emisión:** 14 de noviembre de 2026
**Motores evaluados:** SQLite 3 (Almacenamiento Local Offline-First) y PostgreSQL 18.7 (Base Centralizada)
**Estado de la evaluación:** APROBADO (28/28 pruebas aprobadas en los escenarios evaluados)

---

## 1. Introducción

El presente informe documenta formalmente los resultados obtenidos tras la ejecución y auditoría de las baterías de pruebas automatizadas aplicadas a la capa de persistencia del proyecto **ReserveSync**.

ReserveSync adopta una arquitectura híbrida orientada a la continuidad operativa (*offline-first*):
- **Base de datos local (SQLite):** Permite a la aplicación de escritorio operar de manera autónoma sin conexión a Internet, aplicando validaciones locales de disponibilidad mediante triggers y registrando mutaciones en colas de salida (`sync_outbox`).
- **Base de datos centralizada (PostgreSQL):** Administra el repositorio autoritativo de reservaciones, clientes, mesas y cierres, asegurando la consistencia transaccional mediante bloqueos pesimistas deterministas y funciones PL/pgSQL ante accesos concurrentes de la web pública y múltiples terminales de escritorio.

Para evaluar la solidez del diseño relacional antes de iniciar la construcción del backend (Spring Boot) y la aplicación de escritorio (JavaFX), se sometieron ambos esquemas a pruebas automatizadas de integridad estructural, validación de reglas de negocio y concurrencia transaccional en escenarios controlados.

---

## 2. Objetivo de la Validación

Verificar que los esquemas relacionales, restricciones de integridad, datos semilla y triggers de ReserveSync responden conforme a los requisitos de diseño arquitectónico en los casos evaluados:

1. **Integridad de Dominio y Formato:** Normalización estricta de instantes temporales en UTC (ISO-8601 con formato fijo de 24 caracteres en SQLite y `TIMESTAMPTZ` nativo en PostgreSQL).
2. **Idempotencia de Inicialización:** Capacidad de re-ejecutar scripts semilla sin producir colisiones de clave primaria ni violaciones de unicidad.
3. **Consistencia de Disponibilidad:** Rechazo automático de asignaciones incompatibles (solapamiento horario, mesas inactivas, reservaciones canceladas o periodos de cierre programado).
4. **Protección Administrativa Bidireccional:** Rechazo transaccional al modificar el estado operativo de una mesa o registrar un cierre que afecte reservaciones activas preexistentes.
5. **Determinismo y Mitigación de Interbloqueos (*Deadlocks*):** Demostración empírica de que la estrategia de bloqueo pesimista ordenado (`ORDER BY id ASC FOR UPDATE`) mitiga carreras críticas y previene bloqueos mutuos en los escenarios concurrentes evaluados.

---

## 3. Alcance de las Pruebas

El proceso de validación abarcó la totalidad de las **15 tablas** que integran formalmente el modelo relacional del sistema en ambos motores:

1. `roles`
2. `usuarios`
3. `clientes`
4. `mesas`
5. `reservaciones`
6. `detalle_reservacion`
7. `horarios`
8. `cierres`
9. `configuracion`
10. `historial_reservaciones`
11. `codigos_acceso`
12. `notificaciones`
13. `sync_outbox`
14. `sync_cursor`
15. `sync_conflictos`

*(Nota de alcance: Se constató en los esquemas DDL definitivos que no existe una tabla denominada `turnos`; los horarios operativos se gestionan mediante la tabla `horarios`).*

El alcance específico comprendió tres baterías de evaluación:
- **Suite SQLite:** 14 pruebas automatizadas ejecutadas mediante un arnés en Python.
- **Suite de Integridad PostgreSQL:** 9 pruebas funcionales y de restricciones ejecutadas con `psql` bajo directiva de parada en error (`ON_ERROR_STOP=1`).
- **Suite de Concurrencia PostgreSQL:** 5 escenarios de ejecución paralela con dos sesiones concurrentes independientes administradas por Windows PowerShell.

---

## 4. Entorno de Ejecución

Las pruebas se desarrollaron y ejecutaron sobre la estación de trabajo local, registrando los siguientes parámetros verificados del entorno:

| Parámetro | Detalle del Entorno | Verificación |
|---|---|:---:|
| **Sistema Operativo** | Microsoft Windows 11 Pro (Windows NT 10.0.22621.0) | Verificado en host |
| **Entorno de Shell** | Windows PowerShell 5.1 (Build 10.0.22621.4249, Desktop Edition) | Verificado en host |
| **Motor de Base Central** | PostgreSQL 18.7 x64 (`C:\Program Files\PostgreSQL\18\bin\psql.exe`) | Verificado en host |
| **Instancia y Puerto** | `localhost:5432`, Base de datos dedicada: `reservesync_test_db` | Verificado en host |
| **Motor Local de Pruebas** | SQLite 3 (Módulo nativo `sqlite3` en Python 3.15.2) | Verificado en host |
| **Módulos Auxiliares** | Biblioteca Python `bcrypt` (Cálculo de hashes referenciales) | Referencial |
| **Codificación y Finales de Línea** | UTF-8 sin BOM, finales de línea LF (`\n`) | Limitado a los archivos de evidencia que fueron normalizados |

---

## 5. Metodología de Validación

Se implementó un esquema de pruebas estructurado para evaluar el comportamiento del motor tanto en operaciones válidas como en intentos de transgresión de reglas de negocio:

### 1. Aislamiento y Preparación del Entorno por Suite

La preparación de las bases de datos responde de forma diferenciada a los objetivos de cada arnés:

- **Suite SQLite ([test_sqlite_suite.py](../database/tests/test_sqlite_suite.py)):**
  El arnés busca si existe previamente el archivo físico de base de datos (`reservesync_test_suite.db`) en el directorio de pruebas y lo elimina del sistema de archivos para garantizar un estado inicial limpio e independiente. A continuación, abre la conexión en modo autocommit (`isolation_level = None`), ejecuta secuencialmente el esquema DDL ([schema.sql](../database/sqlite/schema.sql)), aplica las semillas comunes ([sqlite_seed.sql](../database/seed/sqlite_seed.sql)) y las semillas offline ([sqlite_offline_seed.sql](../database/seed/sqlite_offline_seed.sql)), verifica la idempotencia re-ejecutando ambos scripts semilla, y procede con la ejecución de las pruebas unitarias de restricciones y triggers.

- **Suite de Integridad PostgreSQL ([test_postgresql_integrity.sql](../database/tests/test_postgresql_integrity.sql)):**
  No recrea la base de datos a nivel de servidor; se conecta directamente a la base de pruebas preexistente (`reservesync_test_db`) configurando la directiva `ON_ERROR_STOP=1`. En su fase inicial, ejecuta el script de semillas ([postgresql_seed.sql](../database/seed/postgresql_seed.sql)) mediante la directiva `\i` para validar la idempotencia (`ON CONFLICT DO NOTHING`) sobre datos ya persistidos. Posteriormente, ejecuta 9 bloques anónimos PL/pgSQL estructurados con bloques de excepción (`EXCEPTION WHEN check_violation THEN`), verificando que los triggers rechacen las operaciones indebidas sin provocar una terminación anormal del script.

- **Suite de Concurrencia PostgreSQL ([test_postgresql_concurrency.ps1](../database/tests/test_postgresql_concurrency.ps1)):**
  Realiza una comprobación inicial no bloqueante de conectividad (`psql -w`). Si la autenticación es exitosa, se conecta a la base de datos administrativa de mantenimiento (`postgres`) para recrear íntegramente la base de datos de pruebas mediante instrucciones `DROP DATABASE IF EXISTS reservesync_test_db;` y `CREATE DATABASE reservesync_test_db ENCODING 'UTF8';`. Posteriormente, aplica el esquema DDL ([schema.sql](../database/postgresql/schema.sql)) y el dataset inicial ([postgresql_seed.sql](../database/seed/postgresql_seed.sql)), validando en cada comando que `$LASTEXITCODE -eq 0`. Finalmente, administra la ejecución asíncrona de 5 escenarios mediante pares de scripts SQL asignados a dos sesiones concurrentes independientes.

### 2. Detección y Clasificación Rigurosa de Fallos

- Los rechazos legítimos por reglas de negocio deben emitir específicamente el código `SQLSTATE 23514` (`check_violation`).
- En la suite de concurrencia, el arnés PowerShell distingue los rechazos de disponibilidad respecto a falsos positivos. Se rechazan y consideran errores los fallos por timeout de coordinación (`SQLSTATE P0001`), sintaxis SQL (`42601`), UUID inválido (`22P02`) o violación de clave foránea (`23503`). Para validar la Sesión 2, se exige la recepción de `SQLSTATE 23514` junto con la verificación del patrón textual del trigger de negocio.

### 3. Verificación Atómica de Consistencia Post-Transacción

Al término de cada caso o escenario concurrente, se ejecutan consultas SQL directas de conteo (`SELECT count(*) ...`) para verificar que el número final de registros confirmados y los estados de las entidades en la base de datos coincidan unívocamente con el resultado esperado tras el aislamiento transaccional.

---

## 6. Resultados de la Validación de SQLite

La suite de pruebas automatizadas de SQLite ([test_sqlite_suite.py](../database/tests/test_sqlite_suite.py)) evaluó la integridad relacional y los triggers DDL locales. Se obtuvieron **14 pruebas aprobadas de 14 ejecutadas (100% de éxito en los casos evaluados)**.

### Tabla de Resultados — Suite SQLite

| # | Caso de Prueba / Operación Evaluada | Regla o Mecanismo Auditado | Resultado |
|---|---|---|:---:|
| 1 | Creación del esquema DDL | Ejecución de 15 tablas, índices y triggers | **APROBADO** |
| 2 | Inserción de semillas comunes | Carga de reservaciones R1, R2 y R3 ([sqlite_seed.sql](../database/seed/sqlite_seed.sql)) | **APROBADO** |
| 3 | Inserción de semillas exclusivas offline | Registro de reservación R4 y cola `sync_outbox` ([sqlite_offline_seed.sql](../database/seed/sqlite_offline_seed.sql)) | **APROBADO** |
| 4 | Verificación de idempotencia de semillas | Re-ejecución completa de semillas sin colisión de PK/UNIQUE | **APROBADO** |
| 5 | Integridad referencial general | Ejecución de `PRAGMA foreign_key_check` (0 violaciones) | **APROBADO** |
| 6 | Asignación de mesa eliminada lógicamente | Trigger `trg_validar_detalle_reserva_insert` (Rechazo: mesa inactiva/eliminada) | **APROBADO** |
| 7 | Asignación a reservación cancelada | Trigger `trg_validar_detalle_reserva_insert` (Rechazo: reserva cancelada) | **APROBADO** |
| 8 | Modificación por solapamiento horario | Trigger `trg_validar_detalle_reserva_update` (Rechazo: mesa ya ocupada) | **APROBADO** |
| 9 | Creación de cierre sobre reserva activa | Trigger `trg_proteger_cierre_insert` (Rechazo: conflicto con reservación activa) | **APROBADO** |
| 10 | Asignación en periodo de cierre UTC | Trigger de disponibilidad frente a intervalo de cierre de mesa B-02 | **APROBADO** |
| 11 | Desactivación de mesa con reservas futuras | Trigger `trg_proteger_mesa_update` (Rechazo: mesa tiene reservas activas futuras) | **APROBADO** |
| 12 | Reactivación con mesa en mantenimiento | Trigger `trg_validar_reserva_update` (Rechazo: mesa asignada no está activa) | **APROBADO** |
| 13 | Inserción de timestamp con offset (-06:00) | Restricción CHECK `chk_reserva_ts_inicio` (Rechazo: formato no UTC Z estricto) | **APROBADO** |
| 14 | Cierre con alcance inconsistente | Restricción CHECK `chk_cierres_tipo_alcance` (MESA_ESPECIFICA con zona no nula) | **APROBADO** |

---

## 7. Resultados de Integridad en PostgreSQL

La suite de integridad de PostgreSQL ([test_postgresql_integrity.sql](../database/tests/test_postgresql_integrity.sql)) se ejecutó mediante `psql` con control de errores activo (`ON_ERROR_STOP=1`). Se confirmaron **9 pruebas aprobadas de 9 ejecutadas (100% de éxito en los casos evaluados)** con código de salida `0`.

### Tabla de Resultados — Integridad PostgreSQL

| # | Prueba / Regla de Negocio | Mecanismo Evaluado / Mensaje del Trigger | Resultado |
|---|---|---|:---:|
| 1 | Idempotencia de semillas | Re-ejecución de [postgresql_seed.sql](../database/seed/postgresql_seed.sql) mediante cláusulas `ON CONFLICT DO NOTHING` | **APROBADO** |
| 2 | Mesa eliminada lógicamente | `fn_validar_detalle_reservacion()`: Rechazo por mesa eliminada/inactiva | **APROBADO** |
| 3 | Mesa asignada a reserva cancelada | `fn_validar_detalle_reservacion()`: Rechazo por estado inactivo (`CANCELADA`) | **APROBADO** |
| 4 | Reasignación con solapamiento horario | `fn_validar_detalle_reservacion()`: Rechazo por conflicto con reservación R1 | **APROBADO** |
| 5 | Creación de cierre total en horario de R1 | `fn_proteger_cierre()`: Rechazo por conflicto con reservación activa | **APROBADO** |
| 6 | Asignación en cierre parcial UTC (B-02) | `fn_validar_detalle_reservacion()`: Rechazo por intervalo de cierre programado | **APROBADO** |
| 7 | Desactivación de mesa M-01 (con reservas) | `fn_proteger_mesa_update()`: Rechazo por reservaciones activas futuras asociadas | **APROBADO** |
| 8 | Reactivación de reserva con mesa inactiva | `fn_validar_reserva_update()`: Rechazo por mesa asignada (`M-T8`) en mantenimiento | **APROBADO** |
| 9 | Restricción estricta de alcance en cierres | Restricción CHECK `chk_cierres_tipo_alcance` (`SQLSTATE 23514`) | **APROBADO** |

---

## 8. Resultados de Concurrencia en PostgreSQL

La evaluación de concurrencia transaccional se orquestó mediante [test_postgresql_concurrency.ps1](../database/tests/test_postgresql_concurrency.ps1), ejecutando 5 escenarios en los que dos procesos independientes de `psql` interactuaron simultáneamente sobre la misma base de datos. Se obtuvieron **5 escenarios aprobados de 5 ejecutados (100% de éxito en los casos evaluados)**.

### Tabla de Resultados — Concurrencia PostgreSQL (2 Conexiones Paralelas)

| Escenario | Conflicto Evaluado | Comportamiento Sesión 1 | Comportamiento Sesión 2 | Verificación en Base de Datos | Estatus |
|---|---|---|---|---|:---:|
| **1** | Dos sesiones reservando la misma mesa (M-02) | Adquiere bloqueo pesimista y confirma transacción (`exit 0`). | Entra en espera; al liberarse S1, es rechazada por solapamiento (`SQLSTATE 23514`). | Exactamente 1 detalle de asignación registrado en BD. | **APROBADO** |
| **2** | Mesas compartidas (M-03 y M-04) en orden inverso | Bloqueo ordenado determinista (`ORDER BY id ASC FOR UPDATE`). Confirma. | Solicita mesas en orden inverso pero adquiere bloqueos en orden `ASC`. Espera lineal sin deadlock; rechazo por colisión. | Exactamente 1 reservación confirmada registrada en BD. | **APROBADO** |
| **3** | Cierre de zona (TERRAZA) vs Reserva simultánea | Bloquea mesas de TERRAZA e inserta cierre programado. Confirma. | Espera por bloqueo de cierre; al despertar es rechazada por colisión con el cierre. | Exactamente 0 reservaciones registradas en el periodo. | **APROBADO** |
| **4** | Desactivación de mesa M-06 vs Reserva simultánea | Actualiza M-06 a `MANTENIMIENTO` y confirma. | Retenida por bloqueo; al despertar es rechazada por mesa en mantenimiento. | Exactamente 0 reservaciones asociadas a M-06. | **APROBADO** |
| **5** | Reactivación de reserva vs Desactivación de mesa M-05 | Reactiva reservación a `CONFIRMADA` bloqueando M-05 (`RowShareLock`). Confirma. | Detecta bloqueo vía `pg_locks`; queda en cola de espera. Al despertar, `fn_proteger_mesa_update()` rechaza el mantenimiento. | Exactamente 1 reservación `CONFIRMADA` y mesa M-05 `ACTIVA`. | **APROBADO** |

---

## 9. Resumen General de Resultados

La siguiente tabla consolida los resultados obtenidos en las tres baterías de validación:

| Suite de Validación | Motor Evaluado | Pruebas Programadas | Pruebas Aprobadas | Tasa de Éxito | Resultado Final |
|---|---|:---:|:---:|:---:|:---:|
| **Suite Local Automatizada** | SQLite 3 | 14 | 14 | 100.0% | **APROBADO** |
| **Integridad y Reglas de Negocio** | PostgreSQL 18.7 | 9 | 9 | 100.0% | **APROBADO** |
| **Concurrencia Transaccional Real** | PostgreSQL 18.7 | 5 | 5 | 100.0% | **APROBADO** |
| **TOTAL CONSOLIDADO** | **Ambos Motores** | **28** | **28** | **100.0%** | **APROBADO** |

---

## 10. Evidencias y Ubicación de Archivos

Las transcripciones completas, salidas estándar de consola y registros de ejecución que respaldan cada resultado se encuentran almacenados en el repositorio:

- **Evidencia de SQLite (14 pruebas):**
  [evidencias/validacion-base-datos/sqlite_tests.txt](evidencias/validacion-base-datos/sqlite_tests.txt)
- **Evidencia de Integridad PostgreSQL (9 pruebas, exit code 0):**
  [evidencias/validacion-base-datos/postgresql_integrity.txt](evidencias/validacion-base-datos/postgresql_integrity.txt)
- **Evidencia de Concurrencia PostgreSQL (Transcripción PowerShell de 5 escenarios):**
  [evidencias/validacion-base-datos/postgresql_concurrency.txt](evidencias/validacion-base-datos/postgresql_concurrency.txt)

### Scripts Ejecutables Utilizados:
- Arnés de pruebas SQLite: [test_sqlite_suite.py](../database/tests/test_sqlite_suite.py)
- Batería de integridad PostgreSQL: [test_postgresql_integrity.sql](../database/tests/test_postgresql_integrity.sql)
- Ejecutor de concurrencia PostgreSQL: [test_postgresql_concurrency.ps1](../database/tests/test_postgresql_concurrency.ps1)
- Scripts de sesiones concurrentes:
  [concurrencia_escenario1_s1.sql](../database/tests/concurrencia_escenario1_s1.sql) / [s2.sql](../database/tests/concurrencia_escenario1_s2.sql)
  [concurrencia_escenario2_s1.sql](../database/tests/concurrencia_escenario2_s1.sql) / [s2.sql](../database/tests/concurrencia_escenario2_s2.sql)
  [concurrencia_escenario3_s1.sql](../database/tests/concurrencia_escenario3_s1.sql) / [s2.sql](../database/tests/concurrencia_escenario3_s2.sql)
  [concurrencia_escenario4_s1.sql](../database/tests/concurrencia_escenario4_s1.sql) / [s2.sql](../database/tests/concurrencia_escenario4_s2.sql)
  [concurrencia_escenario5_s1.sql](../database/tests/concurrencia_escenario5_s1.sql) / [s2.sql](../database/tests/concurrencia_escenario5_s2.sql)

---

## 11. Conclusiones

1. **Estructura y Validación Funcional del Modelo Relacional:** Se verificó la correcta creación estructural del modelo de 15 tablas en ambos motores de base de datos. Sobre dicha base relacional, la ejecución de los escenarios automatizados permitió validar funcionalmente los mecanismos de integridad referencial, la normalización temporal en UTC y la idempotencia en la inserción de semillas.
2. **Comportamiento de Reglas de Negocio en Escenarios Específicos:** En los escenarios evaluados para cada motor, las restricciones, triggers y funciones respondieron conforme a lo esperado (rechazo por solapamiento horario, validación de estado operativo de mesas, alcances de cierre y reactivación condicional). Esto constata el cumplimiento de las reglas bajo las condiciones probadas, sin implicar una equivalencia funcional completa entre SQLite y PostgreSQL más allá del alcance de dichos escenarios.
3. **Mitigación de Concurrencia en Escenarios Evaluados:** Los resultados respaldan la estrategia de bloqueo pesimista ordenado (`ORDER BY id ASC FOR UPDATE`) implementada en PostgreSQL, la cual previno bloqueos mutuos (*deadlocks*) y resolvió carreras críticas en los escenarios evaluados de reservaciones simultáneas, cierres de zona y mantenimiento de mesas.
4. **Validación como Base de Continuidad:** La validación cubre satisfactoriamente los escenarios definidos en las suites automatizadas, proporcionando una base técnica verificada para continuar con las etapas posteriores de desarrollo del backend en Spring Boot y la aplicación de escritorio en JavaFX.

---

## 12. Limitaciones y Consideraciones

- **Alcance Delimitado de las Pruebas:** La aprobación de las 28 pruebas indica que el sistema responde de forma correcta y determinista en los escenarios explícitamente diseñados y ejecutados. No constituye una afirmación de que el sistema esté libre de errores ante cargas no evaluadas, condiciones de estrés masivo o casos de borde fuera del alcance de estas baterías.
- **Disciplina Transaccional en Capas Superiores (Spring Boot / JavaFX):** Para preservar la mitigación de interbloqueos (*deadlocks*) observada en el Escenario 2, el backend Spring Boot debe ordenar obligatoriamente las colecciones de identificadores de mesas en orden ascendente antes de solicitar bloqueos pesimistas en PostgreSQL.
- **Normalización Temporal en Aplicación:** La capa de software (Spring Boot y JavaFX) deberá utilizar de manera obligatoria la clase `java.time.Instant` convertida explícitamente a UTC para interactuar con los campos de fecha y hora, preservando el formato estricto de 24 caracteres (`YYYY-MM-DDTHH:MM:SS.SSSZ`) auditado en SQLite.
