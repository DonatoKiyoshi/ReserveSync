-- ============================================================================
-- ReserveSync — Esquema de Base de Datos Central (PostgreSQL)
-- Servidor Backend Spring Boot (Gestión Central y Conexión Web)
-- ============================================================================

-- Habilitar extensión para generación de identificadores UUID
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ----------------------------------------------------------------------------
-- 1. Tabla: roles
-- Catálogo de perfiles de acceso
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ----------------------------------------------------------------------------
-- 2. Tabla: usuarios
-- Empleados del restaurante con acceso al sistema
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS usuarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rol_id UUID NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    email VARCHAR(120) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version INTEGER NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_usuarios_rol FOREIGN KEY (rol_id) REFERENCES roles (id) ON DELETE RESTRICT
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
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre VARCHAR(120) NOT NULL,
    telefono VARCHAR(25) NOT NULL,
    email VARCHAR(120),
    notas_preferencias TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version INTEGER NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ
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
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    numero_mesa VARCHAR(20) NOT NULL,
    zona VARCHAR(50) NOT NULL,
    capacidad_minima INTEGER NOT NULL CHECK (capacidad_minima >= 1),
    capacidad_maxima INTEGER NOT NULL CHECK (capacidad_maxima >= capacidad_minima),
    estado_operativo VARCHAR(25) NOT NULL DEFAULT 'ACTIVA' CHECK (estado_operativo IN ('ACTIVA', 'MANTENIMIENTO', 'INACTIVA')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version INTEGER NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ
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
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo_reserva VARCHAR(20) NOT NULL UNIQUE,
    cliente_id UUID NOT NULL,
    usuario_creador_id UUID,
    canal_origen VARCHAR(25) NOT NULL CHECK (canal_origen IN ('WEB_PUBLICA', 'DESKTOP_LOCAL', 'TELEFONO')),
    fecha_reserva DATE NOT NULL,
    fecha_hora_inicio TIMESTAMPTZ NOT NULL,
    fecha_hora_fin TIMESTAMPTZ NOT NULL,
    cantidad_personas INTEGER NOT NULL CHECK (cantidad_personas >= 1),
    notas_cliente TEXT,
    notas_internas TEXT,
    estado_reserva VARCHAR(25) NOT NULL CHECK (
        estado_reserva IN ('PENDIENTE', 'CONFIRMADA', 'SENTADA', 'COMPLETADA', 'CANCELADA', 'NO_ASISTIO', 'RECHAZADA')
    ),
    estado_sync VARCHAR(25) NOT NULL CHECK (
        estado_sync IN ('SYNCED', 'PENDIENTE_SYNC', 'CONFLICTO')
    ),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version INTEGER NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT chk_reserva_tiempo CHECK (fecha_hora_fin > fecha_hora_inicio),
    CONSTRAINT fk_reservaciones_cliente FOREIGN KEY (cliente_id) REFERENCES clientes (id) ON DELETE RESTRICT,
    CONSTRAINT fk_reservaciones_usuario FOREIGN KEY (usuario_creador_id) REFERENCES usuarios (id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_reservaciones_rango 
ON reservaciones (fecha_reserva, fecha_hora_inicio, fecha_hora_fin, estado_reserva);

CREATE INDEX IF NOT EXISTS idx_reservaciones_cliente 
ON reservaciones (cliente_id);

CREATE INDEX IF NOT EXISTS idx_reservaciones_delta_sync 
ON reservaciones (updated_at, deleted_at);

-- ----------------------------------------------------------------------------
-- 6. Tabla: detalle_reservacion
-- Asignación de mesas por reservación (relación N a M)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS detalle_reservacion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reservacion_id UUID NOT NULL,
    mesa_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT uq_detalle_reserva_mesa UNIQUE (reservacion_id, mesa_id),
    CONSTRAINT fk_detalle_reservacion FOREIGN KEY (reservacion_id) REFERENCES reservaciones (id) ON DELETE CASCADE,
    CONSTRAINT fk_detalle_mesa FOREIGN KEY (mesa_id) REFERENCES mesas (id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_detalle_mesa_reserva 
ON detalle_reservacion (mesa_id, reservacion_id);

-- ----------------------------------------------------------------------------
-- 7. Tabla: horarios
-- Turnos y franjas horarias de operación semanal (1=Lunes ... 7=Domingo)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS horarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dia_semana INTEGER NOT NULL CHECK (dia_semana BETWEEN 1 AND 7),
    turno VARCHAR(30) NOT NULL,
    hora_apertura TIME NOT NULL,
    hora_cierre TIME NOT NULL,
    intervalo_reserva_min INTEGER NOT NULL DEFAULT 30 CHECK (intervalo_reserva_min > 0),
    duracion_estandar_min INTEGER NOT NULL DEFAULT 90 CHECK (duracion_estandar_min > 0),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT chk_horario_cierre CHECK (hora_cierre > hora_apertura)
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
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    hora_inicio TIME,
    hora_fin TIME,
    tipo_cierre VARCHAR(30) NOT NULL CHECK (tipo_cierre IN ('TOTAL_RESTAURANTE', 'ZONA', 'MESA_ESPECIFICA')),
    zona VARCHAR(50),
    mesa_id UUID,
    motivo VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT chk_cierres_fechas CHECK (fecha_fin >= fecha_inicio),
    CONSTRAINT fk_cierres_mesa FOREIGN KEY (mesa_id) REFERENCES mesas (id) ON DELETE CASCADE
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
    clave VARCHAR(60) PRIMARY KEY,
    valor TEXT NOT NULL,
    tipo_dato VARCHAR(20) NOT NULL CHECK (tipo_dato IN ('STRING', 'INTEGER', 'BOOLEAN', 'JSON')),
    descripcion VARCHAR(255) NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version INTEGER NOT NULL DEFAULT 1
);

-- ----------------------------------------------------------------------------
-- 10. Tabla: historial_reservaciones
-- Bitácora inmutable de auditoría
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS historial_reservaciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reservacion_id UUID NOT NULL,
    usuario_id UUID,
    accion VARCHAR(40) NOT NULL,
    estado_anterior VARCHAR(25),
    estado_nuevo VARCHAR(25) NOT NULL,
    motivo TEXT,
    fecha_evento TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_historial_reserva FOREIGN KEY (reservacion_id) REFERENCES reservaciones (id) ON DELETE CASCADE,
    CONSTRAINT fk_historial_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_historial_reserva 
ON historial_reservaciones (reservacion_id, fecha_evento);

-- ----------------------------------------------------------------------------
-- 11. Tabla: codigos_acceso
-- Tokens para consulta y cancelación web sin cuenta de usuario
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS codigos_acceso (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reservacion_id UUID NOT NULL,
    token_hash VARCHAR(255) NOT NULL,
    expiracion TIMESTAMPTZ NOT NULL,
    utilizado BOOLEAN NOT NULL DEFAULT FALSE,
    intentos_fallidos INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_codigos_reserva FOREIGN KEY (reservacion_id) REFERENCES reservaciones (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_codigos_reserva 
ON codigos_acceso (reservacion_id);

-- ----------------------------------------------------------------------------
-- 12. Tabla: notificaciones
-- Cola de avisos y recordatorios
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notificaciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reservacion_id UUID,
    canal VARCHAR(20) NOT NULL CHECK (canal IN ('EMAIL', 'WHATSAPP', 'SISTEMA_LOCAL')),
    destinatario VARCHAR(120) NOT NULL,
    tipo VARCHAR(40) NOT NULL,
    contenido TEXT NOT NULL,
    estado_envio VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE' CHECK (estado_envio IN ('PENDIENTE', 'ENVIADO', 'FALLIDO')),
    fecha_programada TIMESTAMPTZ NOT NULL,
    fecha_envio TIMESTAMPTZ,
    error_mensaje TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT fk_notificaciones_reserva FOREIGN KEY (reservacion_id) REFERENCES reservaciones (id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_notificaciones_pendientes 
ON notificaciones (estado_envio, fecha_programada);

-- ----------------------------------------------------------------------------
-- 13. Tabla: sync_outbox (Técnica)
-- Bitácora de transacciones idempotentes procesadas desde los clientes
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sync_outbox (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    operation_id UUID NOT NULL UNIQUE,       -- Clave global de idempotencia
    terminal_id VARCHAR(60) NOT NULL,
    entity_name VARCHAR(50) NOT NULL,
    entity_id UUID NOT NULL,
    action VARCHAR(20) NOT NULL CHECK (action IN ('CREATE', 'UPDATE', 'DELETE')),
    payload JSONB NOT NULL,
    entity_version INTEGER NOT NULL DEFAULT 1,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE' CHECK (status IN ('PENDIENTE', 'EN_PROCESO', 'COMPLETADO', 'CONFLICTO', 'FALLIDO')),
    retry_count INTEGER NOT NULL DEFAULT 0,
    error_code VARCHAR(50),
    last_error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_outbox_pendientes 
ON sync_outbox (status, created_at);

-- ----------------------------------------------------------------------------
-- 14. Tabla: sync_cursor (Técnica)
-- Punteros de sincronización por estación o terminal
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sync_cursor (
    id VARCHAR(50) PRIMARY KEY,
    terminal_id VARCHAR(60) NOT NULL,
    last_sync_timestamp TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ----------------------------------------------------------------------------
-- 15. Tabla: sync_conflictos (Técnica)
-- Registro de colisiones para auditoría y resolución central
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sync_conflictos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    operation_id UUID NOT NULL,
    entity_name VARCHAR(50) NOT NULL,
    entity_id UUID NOT NULL,
    codigo_reserva VARCHAR(20),
    client_payload JSONB NOT NULL,
    server_payload JSONB NOT NULL,
    tipo_conflicto VARCHAR(40) NOT NULL CHECK (
        tipo_conflicto IN ('MESA_SUPERPUESTA', 'VERSION_CONCURRENTE', 'CLIENTE_DESACTUALIZADO', 'OTRO')
    ),
    descripcion_problema TEXT NOT NULL,
    sugerencia_accion TEXT,
    estado_resolucion VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE' CHECK (
        estado_resolucion IN ('PENDIENTE', 'SERVIDOR_GANA', 'CLIENTE_GANA', 'RESOLUCION_MANUAL')
    ),
    resuelto_por UUID,
    resolucion_notas TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMPTZ,
    CONSTRAINT fk_conflictos_outbox FOREIGN KEY (operation_id) REFERENCES sync_outbox (operation_id) ON DELETE CASCADE,
    CONSTRAINT fk_conflictos_usuario FOREIGN KEY (resuelto_por) REFERENCES usuarios (id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_conflictos_estado 
ON sync_conflictos (estado_resolucion);
