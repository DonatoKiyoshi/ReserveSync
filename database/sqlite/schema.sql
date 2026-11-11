-- ============================================================================
-- ReserveSync — Esquema de Base de Datos Local (SQLite)
-- Aplicación de escritorio JavaFX (Operación Offline-First)
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ----------------------------------------------------------------------------
-- 1. Tabla: roles
-- Catálogo de perfiles de acceso
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS roles (
    id TEXT PRIMARY KEY,
    nombre TEXT NOT NULL UNIQUE,
    descripcion TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- ----------------------------------------------------------------------------
-- 2. Tabla: usuarios
-- Empleados del restaurante con acceso a la app de escritorio
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS usuarios (
    id TEXT PRIMARY KEY,
    rol_id TEXT NOT NULL,
    nombre TEXT NOT NULL,
    email TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    activo INTEGER NOT NULL DEFAULT 1 CHECK (activo IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    version INTEGER NOT NULL DEFAULT 1,
    deleted_at TEXT,
    FOREIGN KEY (rol_id) REFERENCES roles (id) ON DELETE RESTRICT
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_usuarios_email_activo 
ON usuarios (email) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_usuarios_rol 
ON usuarios (rol_id);

-- ----------------------------------------------------------------------------
-- 3. Tabla: clientes
-- Clientes comensales (creados desde web o capturados en recepción)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS clientes (
    id TEXT PRIMARY KEY,
    nombre TEXT NOT NULL,
    telefono TEXT NOT NULL,
    email TEXT,
    notas_preferencias TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    version INTEGER NOT NULL DEFAULT 1,
    deleted_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_clientes_telefono 
ON clientes (telefono);

CREATE INDEX IF NOT EXISTS idx_clientes_email 
ON clientes (email);

CREATE INDEX IF NOT EXISTS idx_clientes_delta_sync 
ON clientes (updated_at, deleted_at);

-- ----------------------------------------------------------------------------
-- 4. Tabla: mesas
-- Distribución física del local y capacidades
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mesas (
    id TEXT PRIMARY KEY,
    numero_mesa TEXT NOT NULL,
    zona TEXT NOT NULL,
    capacidad_minima INTEGER NOT NULL CHECK (capacidad_minima >= 1),
    capacidad_maxima INTEGER NOT NULL CHECK (capacidad_maxima >= capacidad_minima),
    estado_operativo TEXT NOT NULL DEFAULT 'ACTIVA' CHECK (estado_operativo IN ('ACTIVA', 'MANTENIMIENTO', 'INACTIVA')),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    version INTEGER NOT NULL DEFAULT 1,
    deleted_at TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_mesas_numero_activo 
ON mesas (numero_mesa) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_mesas_zona 
ON mesas (zona, estado_operativo);

CREATE INDEX IF NOT EXISTS idx_mesas_delta_sync 
ON mesas (updated_at, deleted_at);

-- ----------------------------------------------------------------------------
-- 5. Tabla: reservaciones
-- Cabecera principal de reservaciones
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reservaciones (
    id TEXT PRIMARY KEY,
    codigo_reserva TEXT NOT NULL UNIQUE,
    cliente_id TEXT NOT NULL,
    usuario_creador_id TEXT,
    canal_origen TEXT NOT NULL CHECK (canal_origen IN ('WEB_PUBLICA', 'DESKTOP_LOCAL', 'TELEFONO')),
    fecha_reserva TEXT NOT NULL,              -- Formato: 'YYYY-MM-DD'
    fecha_hora_inicio TEXT NOT NULL,          -- Formato ISO-8601 UTC: 'YYYY-MM-DDTHH:MM:SSZ'
    fecha_hora_fin TEXT NOT NULL,             -- Formato ISO-8601 UTC: 'YYYY-MM-DDTHH:MM:SSZ'
    cantidad_personas INTEGER NOT NULL CHECK (cantidad_personas >= 1),
    notas_cliente TEXT,
    notas_internas TEXT,
    estado_reserva TEXT NOT NULL CHECK (
        estado_reserva IN ('PENDIENTE', 'CONFIRMADA', 'SENTADA', 'COMPLETADA', 'CANCELADA', 'NO_ASISTIO', 'RECHAZADA')
    ),
    estado_sync TEXT NOT NULL CHECK (
        estado_sync IN ('SYNCED', 'PENDIENTE_SYNC', 'CONFLICTO')
    ),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    version INTEGER NOT NULL DEFAULT 1,
    deleted_at TEXT,
    CHECK (fecha_hora_fin > fecha_hora_inicio),
    FOREIGN KEY (cliente_id) REFERENCES clientes (id) ON DELETE RESTRICT,
    FOREIGN KEY (usuario_creador_id) REFERENCES usuarios (id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_reservaciones_rango 
ON reservaciones (fecha_reserva, fecha_hora_inicio, fecha_hora_fin, estado_reserva);

CREATE INDEX IF NOT EXISTS idx_reservaciones_cliente 
ON reservaciones (cliente_id);

CREATE INDEX IF NOT EXISTS idx_reservaciones_delta_sync 
ON reservaciones (updated_at, deleted_at);

-- ----------------------------------------------------------------------------
-- 6. Tabla: detalle_reservacion
-- Asignación de una o varias mesas por reservación (relación N a M)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS detalle_reservacion (
    id TEXT PRIMARY KEY,
    reservacion_id TEXT NOT NULL,
    mesa_id TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    version INTEGER NOT NULL DEFAULT 1,
    UNIQUE (reservacion_id, mesa_id),
    FOREIGN KEY (reservacion_id) REFERENCES reservaciones (id) ON DELETE CASCADE,
    FOREIGN KEY (mesa_id) REFERENCES mesas (id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_detalle_mesa_reserva 
ON detalle_reservacion (mesa_id, reservacion_id);

-- ----------------------------------------------------------------------------
-- 7. Tabla: horarios
-- Turnos y franjas horarias de operación semanal (1=Lunes ... 7=Domingo)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS horarios (
    id TEXT PRIMARY KEY,
    dia_semana INTEGER NOT NULL CHECK (dia_semana BETWEEN 1 AND 7),
    turno TEXT NOT NULL,
    hora_apertura TEXT NOT NULL,              -- Formato: 'HH:MM:SS'
    hora_cierre TEXT NOT NULL,                -- Formato: 'HH:MM:SS'
    intervalo_reserva_min INTEGER NOT NULL DEFAULT 30 CHECK (intervalo_reserva_min > 0),
    duracion_estandar_min INTEGER NOT NULL DEFAULT 90 CHECK (duracion_estandar_min > 0),
    activo INTEGER NOT NULL DEFAULT 1 CHECK (activo IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    version INTEGER NOT NULL DEFAULT 1,
    CHECK (hora_cierre > hora_apertura)
);

CREATE INDEX IF NOT EXISTS idx_horarios_dia_turno 
ON horarios (dia_semana, activo);

CREATE INDEX IF NOT EXISTS idx_horarios_delta_sync 
ON horarios (updated_at);

-- ----------------------------------------------------------------------------
-- 8. Tabla: cierres
-- Días festivos, vacaciones y bloqueos específicos por mantenimiento
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cierres (
    id TEXT PRIMARY KEY,
    fecha_inicio TEXT NOT NULL,               -- Formato: 'YYYY-MM-DD'
    fecha_fin TEXT NOT NULL,                  -- Formato: 'YYYY-MM-DD'
    hora_inicio TEXT,                         -- Opcional para bloqueos parciales: 'HH:MM:SS'
    hora_fin TEXT,
    tipo_cierre TEXT NOT NULL CHECK (tipo_cierre IN ('TOTAL_RESTAURANTE', 'ZONA', 'MESA_ESPECIFICA')),
    zona TEXT,
    mesa_id TEXT,
    motivo TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    version INTEGER NOT NULL DEFAULT 1,
    CHECK (fecha_fin >= fecha_inicio),
    FOREIGN KEY (mesa_id) REFERENCES mesas (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_cierres_fechas 
ON cierres (fecha_inicio, fecha_fin, tipo_cierre);

CREATE INDEX IF NOT EXISTS idx_cierres_delta_sync 
ON cierres (updated_at);

-- ----------------------------------------------------------------------------
-- 9. Tabla: configuracion
-- Parámetros operativos del restaurante
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS configuracion (
    clave TEXT PRIMARY KEY,
    valor TEXT NOT NULL,
    tipo_dato TEXT NOT NULL CHECK (tipo_dato IN ('STRING', 'INTEGER', 'BOOLEAN', 'JSON')),
    descripcion TEXT NOT NULL,
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    version INTEGER NOT NULL DEFAULT 1
);

-- ----------------------------------------------------------------------------
-- 10. Tabla: historial_reservaciones
-- Bitácora inmutable de auditoría
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS historial_reservaciones (
    id TEXT PRIMARY KEY,
    reservacion_id TEXT NOT NULL,
    usuario_id TEXT,
    accion TEXT NOT NULL,
    estado_anterior TEXT,
    estado_nuevo TEXT NOT NULL,
    motivo TEXT,
    fecha_evento TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    FOREIGN KEY (reservacion_id) REFERENCES reservaciones (id) ON DELETE CASCADE,
    FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_historial_reserva 
ON historial_reservaciones (reservacion_id, fecha_evento);

-- ----------------------------------------------------------------------------
-- 11. Tabla: codigos_acceso
-- Tokens para consulta y cancelación web sin cuenta de usuario
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS codigos_acceso (
    id TEXT PRIMARY KEY,
    reservacion_id TEXT NOT NULL,
    token_hash TEXT NOT NULL,
    expiracion TEXT NOT NULL,
    utilizado INTEGER NOT NULL DEFAULT 0 CHECK (utilizado IN (0, 1)),
    intentos_fallidos INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    FOREIGN KEY (reservacion_id) REFERENCES reservaciones (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_codigos_reserva 
ON codigos_acceso (reservacion_id);

-- ----------------------------------------------------------------------------
-- 12. Tabla: notificaciones
-- Cola de avisos y recordatorios
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notificaciones (
    id TEXT PRIMARY KEY,
    reservacion_id TEXT,
    canal TEXT NOT NULL CHECK (canal IN ('EMAIL', 'WHATSAPP', 'SISTEMA_LOCAL')),
    destinatario TEXT NOT NULL,
    tipo TEXT NOT NULL,
    contenido TEXT NOT NULL,
    estado_envio TEXT NOT NULL DEFAULT 'PENDIENTE' CHECK (estado_envio IN ('PENDIENTE', 'ENVIADO', 'FALLIDO')),
    fecha_programada TEXT NOT NULL,
    fecha_envio TEXT,
    error_mensaje TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    version INTEGER NOT NULL DEFAULT 1,
    FOREIGN KEY (reservacion_id) REFERENCES reservaciones (id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_notificaciones_pendientes 
ON notificaciones (estado_envio, fecha_programada);

-- ----------------------------------------------------------------------------
-- 13. Tabla: sync_outbox (Técnica)
-- Cola de mutaciones locales generadas offline para enviar al backend
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sync_outbox (
    id TEXT PRIMARY KEY,
    operation_id TEXT NOT NULL UNIQUE,       -- UUID idempotente
    terminal_id TEXT NOT NULL,                -- Identificador del equipo de escritorio
    entity_name TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    action TEXT NOT NULL CHECK (action IN ('CREATE', 'UPDATE', 'DELETE')),
    payload TEXT NOT NULL CHECK (json_valid(payload)),
    entity_version INTEGER NOT NULL DEFAULT 1,
    status TEXT NOT NULL DEFAULT 'PENDIENTE' CHECK (status IN ('PENDIENTE', 'EN_PROCESO', 'COMPLETADO', 'CONFLICTO', 'FALLIDO')),
    retry_count INTEGER NOT NULL DEFAULT 0,
    error_code TEXT,
    last_error TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    processed_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_outbox_pendientes 
ON sync_outbox (status, created_at);

-- ----------------------------------------------------------------------------
-- 14. Tabla: sync_cursor (Técnica)
-- Puntero de sincronización con el servidor central
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sync_cursor (
    id TEXT PRIMARY KEY,
    terminal_id TEXT NOT NULL,
    last_sync_timestamp TEXT NOT NULL,
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- ----------------------------------------------------------------------------
-- 15. Tabla: sync_conflictos (Técnica)
-- Registro de colisiones para resolución asistida en la interfaz
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sync_conflictos (
    id TEXT PRIMARY KEY,
    operation_id TEXT NOT NULL,
    entity_name TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    codigo_reserva TEXT,
    client_payload TEXT NOT NULL,
    server_payload TEXT NOT NULL,
    tipo_conflicto TEXT NOT NULL CHECK (
        tipo_conflicto IN ('MESA_SUPERPUESTA', 'VERSION_CONCURRENTE', 'CLIENTE_DESACTUALIZADO', 'OTRO')
    ),
    descripcion_problema TEXT NOT NULL,
    sugerencia_accion TEXT,
    estado_resolucion TEXT NOT NULL DEFAULT 'PENDIENTE' CHECK (
        estado_resolucion IN ('PENDIENTE', 'SERVIDOR_GANA', 'CLIENTE_GANA', 'RESOLUCION_MANUAL')
    ),
    resuelto_por TEXT,
    resolucion_notas TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    resolved_at TEXT,
    FOREIGN KEY (operation_id) REFERENCES sync_outbox (operation_id) ON DELETE CASCADE,
    FOREIGN KEY (resuelto_por) REFERENCES usuarios (id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_conflictos_estado 
ON sync_conflictos (estado_resolucion);
