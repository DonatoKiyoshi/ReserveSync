# Modelo Entidad-Relación y Diccionario de Datos — ReserveSync

Este documento contiene la arquitectura de datos definitiva para **ReserveSync**, compatible con **SQLite** (aplicación de escritorio offline) y **PostgreSQL** (backend central Spring Boot), tras la auditoría final y corrección de integridad transaccional, concurrencia, normalización de marcas de tiempo y sincronización.

---

## 1. Diagrama Entidad-Relación (Mermaid)

```mermaid
erDiagram
    roles ||--o{ usuarios : "agrupa"
    usuarios ||--o{ reservaciones : "registra_localmente"
    usuarios ||--o{ historial_reservaciones : "audita_evento"
    usuarios ||--o{ sync_conflictos : "resuelve_manualmente"

    clientes ||--o{ reservaciones : "pertenece_a"

    reservaciones ||--|{ detalle_reservacion : "ocupa"
    mesas ||--o{ detalle_reservacion : "es_asignada"

    mesas ||--o{ cierres : "bloqueo_por_mantenimiento"

    reservaciones ||--o{ historial_reservaciones : "registra_historial (ON DELETE RESTRICT)"
    reservaciones ||--o{ codigos_acceso : "habilita_autoconsulta (ON DELETE CASCADE)"
    reservaciones ||--o{ notificaciones : "genera_alertas (ON DELETE SET NULL)"

    sync_outbox ||--o{ sync_conflictos : "registra_colision"

    %% Entidades y atributos principales
    roles {
        uuid id PK
        string nombre UK
        string descripcion
        timestamp created_at
    }

    usuarios {
        uuid id PK
        uuid rol_id FK
        string nombre
        string email UK
        string password_hash
        boolean activo
        timestamp created_at
        timestamp updated_at
        int version
        timestamp deleted_at
    }

    clientes {
        uuid id PK
        string nombre
        string telefono
        string email
        text notas_preferencias
        timestamp created_at
        timestamp updated_at
        int version
        timestamp deleted_at
    }

    mesas {
        uuid id PK
        string numero_mesa UK
        string zona
        int capacidad_minima
        int capacidad_maxima
        string estado_operativo "ACTIVA, MANTENIMIENTO, INACTIVA"
        timestamp created_at
        timestamp updated_at
        int version
        timestamp deleted_at
    }

    reservaciones {
        uuid id PK
        string codigo_reserva UK
        uuid cliente_id FK
        uuid usuario_creador_id FK
        string canal_origen "WEB_PUBLICA, DESKTOP_LOCAL, TELEFONO"
        date fecha_reserva
        timestamp fecha_hora_inicio "UTC estricto YYYY-MM-DDTHH:MM:SS.SSSZ / TIMESTAMPTZ"
        timestamp fecha_hora_fin "UTC estricto YYYY-MM-DDTHH:MM:SS.SSSZ / TIMESTAMPTZ"
        int cantidad_personas
        text notas_cliente
        text notas_internas
        string estado_reserva "PENDIENTE, CONFIRMADA, SENTADA, COMPLETADA, CANCELADA, NO_ASISTIO, RECHAZADA"
        string estado_sync "SYNCED, PENDIENTE_SYNC, CONFLICTO"
        timestamp created_at
        timestamp updated_at
        int version
        timestamp deleted_at
    }

    detalle_reservacion {
        uuid id PK
        uuid reservacion_id FK
        uuid mesa_id FK
        timestamp created_at
        int version
    }

    horarios {
        uuid id PK
        int dia_semana "1=Lunes a 7=Domingo"
        string turno "COMIDA, CENA"
        time hora_apertura "Hora local de pared"
        time hora_cierre "Hora local de pared"
        int intervalo_reserva_min
        int duracion_estandar_min
        boolean activo
        timestamp created_at
        timestamp updated_at
        int version
    }

    cierres {
        uuid id PK
        timestamp fecha_hora_inicio "UTC estricto YYYY-MM-DDTHH:MM:SS.SSSZ / TIMESTAMPTZ"
        timestamp fecha_hora_fin "UTC estricto YYYY-MM-DDTHH:MM:SS.SSSZ / TIMESTAMPTZ"
        string tipo_cierre "TOTAL_RESTAURANTE, ZONA, MESA_ESPECIFICA"
        string zona "Opcional si tipo es ZONA, NULL en otros"
        uuid mesa_id FK "Opcional si tipo es MESA_ESPECIFICA, NULL en otros"
        string motivo
        timestamp created_at
        timestamp updated_at
        int version
    }

    configuracion {
        string clave PK
        text valor
        string tipo_dato "STRING, INTEGER, BOOLEAN, JSON"
        string descripcion
        timestamp updated_at
        int version
    }

    historial_reservaciones {
        uuid id PK
        uuid reservacion_id FK "ON DELETE RESTRICT"
        uuid usuario_id FK
        string accion
        string estado_anterior
        string estado_nuevo
        text motivo
        timestamp fecha_evento
    }

    codigos_acceso {
        uuid id PK
        uuid reservacion_id FK "ON DELETE CASCADE"
        string token_hash
        timestamp expiracion
        boolean utilizado
        int intentos_fallidos
        timestamp created_at
    }

    notificaciones {
        uuid id PK
        uuid reservacion_id FK "ON DELETE SET NULL"
        string canal "EMAIL, WHATSAPP, SISTEMA_LOCAL"
        string destinatario
        string tipo
        text contenido
        string estado_envio "PENDIENTE, ENVIADO, FALLIDO"
        timestamp fecha_programada
        timestamp fecha_envio
        text error_mensaje
        timestamp created_at
        int version
    }

    sync_outbox {
        uuid id PK
        uuid operation_id UK "Idempotencia global"
        string terminal_id
        string entity_name
        uuid entity_id
        string action "CREATE, UPDATE, DELETE"
        json payload
        int entity_version
        string status "PENDIENTE, EN_PROCESO, COMPLETADO, CONFLICTO, FALLIDO"
        int retry_count
        string error_code
        text last_error
        timestamp created_at
        timestamp processed_at
    }

    sync_cursor {
        uuid id PK
        string terminal_id
        string direccion "PUSH, PULL"
        timestamp last_sync_timestamp
        uuid last_sync_id "Rompe empates de timestamp"
        bigint last_sync_sequence "Secuencia monotónica"
        timestamp updated_at
    }

    sync_conflictos {
        uuid id PK
        uuid operation_id FK
        string entity_name
        uuid entity_id
        string codigo_reserva
        json client_payload
        json server_payload
        string tipo_conflicto "MESA_SUPERPUESTA, VERSION_CONCURRENTE, CLIENTE_DESACTUALIZADO, OTRO"
        text descripcion_problema
        text sugerencia_accion
        string estado_resolucion "PENDIENTE, SERVIDOR_GANA, CLIENTE_GANA, RESOLUCION_MANUAL"
        uuid resuelto_por FK
        text resolucion_notas
        timestamp created_at
        timestamp resolved_at
    }
```

---

## 2. Diccionario de Datos y Reglas de Integridad

### 2.1 Normalización Estricta de Timestamps UTC
- **En SQLite (TEXT):**
  Las marcas temporales de `reservaciones` (`fecha_hora_inicio`, `fecha_hora_fin`) y `cierres` (`fecha_hora_inicio`, `fecha_hora_fin`) exigen por restricción `CHECK`:
  1. Longitud exacta de 24 caracteres: `length(ts) = 24`.
  2. Patrón estricto ISO-8601 con milisegundos y terminación literal en `Z`:
     `GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9].[0-9][0-9][0-9]Z'`.
  3. Validación de fecha y hora real: `datetime(ts) IS NOT NULL AND strftime('%Y-%m-%dT%H:%M:%S', ts) = substr(ts, 1, 19)`.
  4. Se rechazan offsets horarios (ej. `-06:00`), fechas inválidas (ej. 31 de febrero) y precisiones variables. Esto garantiza orden lexicográfico equivalente al orden cronológico absoluto.
- **En PostgreSQL (TIMESTAMPTZ):**
  Se preserva el tipo nativo `TIMESTAMPTZ` con precisión de microsegundos, serializando en UTC.

### 2.2 Restricciones de Alcance de Cierres
- `TOTAL_RESTAURANTE`: exige `zona IS NULL AND mesa_id IS NULL`.
- `ZONA`: exige `zona NOT NULL AND mesa_id IS NULL`.
- `MESA_ESPECIFICA`: exige `mesa_id NOT NULL AND zona IS NULL`.
- Intervalo positivo obligatorio: `CHECK (fecha_hora_fin > fecha_hora_inicio)`.

### 2.3 Estados que Ocupan Mesas y Reglas de Reactivación
- **Estados Activos que Bloquean Mesas:** `PENDIENTE`, `CONFIRMADA` y `SENTADA`.
- **Estados Inactivos que Liberan Mesas:** `COMPLETADA`, `CANCELADA`, `NO_ASISTIO` y `RECHAZADA`.
- **Reactivación de Reservaciones:** Cuando una reservación cancelada o eliminada lógicamente pasa a estado activo, el trigger `trg_validar_reserva_update` / `fn_validar_reserva_update` valida **todas las mesas asignadas** a dicha reservación:
  - Si alguna mesa fue desactivada (`estado_operativo != 'ACTIVA'`), eliminada lógicamente (`deleted_at IS NOT NULL`) o ya no existe, la reactivación es rechazada.
  - Se revalidan solapamientos con otras reservas activas y colisiones con cierres.

### 2.4 Bitácora de Auditoría Inmutable
- `historial_reservaciones.reservacion_id` aplica **`ON DELETE RESTRICT`**.
- La bitácora histórica nunca puede ser eliminada en cascada por un borrado físico accidental de la reservación padre.

### 2.5 Propuesta de Secuencia Monotónica y Sincronización
- `sync_cursor` mantiene punteros independientes para `PUSH` (subida terminal -> servidor) y `PULL` (descarga servidor -> terminal).
- La columna `last_sync_sequence` se asociará en el backend a un generador global de secuencias (`global_sync_seq`) en PostgreSQL vinculado a una bitácora inmutable de eventos (`sync_changelog`).
- La columna `last_sync_id` rompe empates cuando dos mutaciones comparten exactamente la misma marca de tiempo.
