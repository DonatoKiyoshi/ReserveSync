-- ============================================================================
-- ReserveSync — Esquema de Base de Datos Local (SQLite)
-- Aplicación de escritorio JavaFX (Operación Offline-First)
-- ============================================================================

PRAGMA foreign_keys = ON;

BEGIN TRANSACTION;

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
-- Formato estricto UTC de longitud fija: YYYY-MM-DDTHH:MM:SS.SSSZ (24 caracteres)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reservaciones (
    id TEXT PRIMARY KEY,
    codigo_reserva TEXT NOT NULL UNIQUE,
    cliente_id TEXT NOT NULL,
    usuario_creador_id TEXT,
    canal_origen TEXT NOT NULL CHECK (canal_origen IN ('WEB_PUBLICA', 'DESKTOP_LOCAL', 'TELEFONO')),
    fecha_reserva TEXT NOT NULL,              -- Formato local: 'YYYY-MM-DD'
    fecha_hora_inicio TEXT NOT NULL,          -- Formato UTC estricto: 'YYYY-MM-DDTHH:MM:SS.SSSZ'
    fecha_hora_fin TEXT NOT NULL,             -- Formato UTC estricto: 'YYYY-MM-DDTHH:MM:SS.SSSZ'
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
    CONSTRAINT chk_reserva_tiempo CHECK (fecha_hora_fin > fecha_hora_inicio),
    CONSTRAINT chk_reserva_ts_inicio CHECK (
        length(fecha_hora_inicio) = 24
        AND fecha_hora_inicio GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9].[0-9][0-9][0-9]Z'
        AND datetime(fecha_hora_inicio) IS NOT NULL
        AND strftime('%Y-%m-%dT%H:%M:%S', fecha_hora_inicio) = substr(fecha_hora_inicio, 1, 19)
    ),
    CONSTRAINT chk_reserva_ts_fin CHECK (
        length(fecha_hora_fin) = 24
        AND fecha_hora_fin GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9].[0-9][0-9][0-9]Z'
        AND datetime(fecha_hora_fin) IS NOT NULL
        AND strftime('%Y-%m-%dT%H:%M:%S', fecha_hora_fin) = substr(fecha_hora_fin, 1, 19)
    ),
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
-- Bloqueos continuos expresados en intervalos absolutos UTC
-- Formato estricto UTC de longitud fija: YYYY-MM-DDTHH:MM:SS.SSSZ (24 caracteres)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cierres (
    id TEXT PRIMARY KEY,
    fecha_hora_inicio TEXT NOT NULL,          -- Formato UTC estricto: 'YYYY-MM-DDTHH:MM:SS.SSSZ'
    fecha_hora_fin TEXT NOT NULL,             -- Formato UTC estricto: 'YYYY-MM-DDTHH:MM:SS.SSSZ'
    tipo_cierre TEXT NOT NULL CHECK (tipo_cierre IN ('TOTAL_RESTAURANTE', 'ZONA', 'MESA_ESPECIFICA')),
    zona TEXT,
    mesa_id TEXT,
    motivo TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT chk_cierres_intervalo CHECK (fecha_hora_fin > fecha_hora_inicio),
    CONSTRAINT chk_cierres_tipo_alcance CHECK (
        (tipo_cierre = 'TOTAL_RESTAURANTE' AND zona IS NULL AND mesa_id IS NULL)
        OR (tipo_cierre = 'ZONA' AND zona IS NOT NULL AND mesa_id IS NULL)
        OR (tipo_cierre = 'MESA_ESPECIFICA' AND mesa_id IS NOT NULL AND zona IS NULL)
    ),
    CONSTRAINT chk_cierres_ts_inicio CHECK (
        length(fecha_hora_inicio) = 24
        AND fecha_hora_inicio GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9].[0-9][0-9][0-9]Z'
        AND datetime(fecha_hora_inicio) IS NOT NULL
        AND strftime('%Y-%m-%dT%H:%M:%S', fecha_hora_inicio) = substr(fecha_hora_inicio, 1, 19)
    ),
    CONSTRAINT chk_cierres_ts_fin CHECK (
        length(fecha_hora_fin) = 24
        AND fecha_hora_fin GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9].[0-9][0-9][0-9]Z'
        AND datetime(fecha_hora_fin) IS NOT NULL
        AND strftime('%Y-%m-%dT%H:%M:%S', fecha_hora_fin) = substr(fecha_hora_fin, 1, 19)
    ),
    FOREIGN KEY (mesa_id) REFERENCES mesas (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_cierres_rango_tipo
ON cierres (fecha_hora_inicio, fecha_hora_fin, tipo_cierre);

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
-- Bitácora inmutable de auditoría (ON DELETE RESTRICT para preservar integridad)
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
    FOREIGN KEY (reservacion_id) REFERENCES reservaciones (id) ON DELETE RESTRICT,
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
-- Punteros de sincronización por terminal y dirección (PUSH / PULL)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sync_cursor (
    id TEXT PRIMARY KEY,
    terminal_id TEXT NOT NULL,
    direccion TEXT NOT NULL CHECK (direccion IN ('PUSH', 'PULL')),
    last_sync_timestamp TEXT NOT NULL,
    last_sync_id TEXT,
    last_sync_sequence INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    UNIQUE (terminal_id, direccion)
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

-- ----------------------------------------------------------------------------
-- TRIGGERS DE INTEGRIDAD Y DISPONIBILIDAD (SQLite)
-- ----------------------------------------------------------------------------

-- 1. Validación al ASIGNAR una mesa (INSERT en detalle_reservacion)
CREATE TRIGGER IF NOT EXISTS trg_validar_detalle_insert
BEFORE INSERT ON detalle_reservacion
BEGIN
    -- A. Rechazar mesas no existentes, inactivas o eliminadas lógicamente
    SELECT RAISE(ABORT, 'Disponibilidad: La mesa asignada no existe, está eliminada o no se encuentra activa')
    WHERE NOT EXISTS (
        SELECT 1 FROM mesas
        WHERE id = NEW.mesa_id
          AND estado_operativo = 'ACTIVA'
          AND deleted_at IS NULL
    );

    -- B. Rechazar reservaciones canceladas, rechazadas, completadas o eliminadas lógicamente
    SELECT RAISE(ABORT, 'Integridad: No se puede asignar mesas a una reservación cancelada, rechazada, completada o eliminada')
    WHERE NOT EXISTS (
        SELECT 1 FROM reservaciones
        WHERE id = NEW.reservacion_id
          AND deleted_at IS NULL
          AND estado_reserva IN ('PENDIENTE', 'CONFIRMADA', 'SENTADA')
    );

    -- C. Validar que no exista un cierre que coincida con el intervalo absoluto UTC de la reservación
    SELECT RAISE(ABORT, 'Disponibilidad: El restaurante, zona o mesa cuenta con un cierre o bloqueo programado en ese horario')
    WHERE EXISTS (
        SELECT 1
        FROM cierres c
        JOIN reservaciones r ON r.id = NEW.reservacion_id
        JOIN mesas m ON m.id = NEW.mesa_id
        WHERE (r.fecha_hora_inicio < c.fecha_hora_fin AND r.fecha_hora_fin > c.fecha_hora_inicio)
          AND (
              c.tipo_cierre = 'TOTAL_RESTAURANTE'
              OR (c.tipo_cierre = 'ZONA' AND c.zona = m.zona)
              OR (c.tipo_cierre = 'MESA_ESPECIFICA' AND c.mesa_id = NEW.mesa_id)
          )
    );

    -- D. Validar solapamiento con otra reservación activa (PENDIENTE, CONFIRMADA, SENTADA) en esa misma mesa
    SELECT RAISE(ABORT, 'Conflicto: La mesa ya se encuentra asignada a otra reservación activa en ese horario')
    WHERE EXISTS (
        SELECT 1
        FROM detalle_reservacion dr
        JOIN reservaciones r_existente ON dr.reservacion_id = r_existente.id
        JOIN reservaciones r_nueva ON r_nueva.id = NEW.reservacion_id
        WHERE dr.mesa_id = NEW.mesa_id
          AND dr.reservacion_id != NEW.reservacion_id
          AND r_existente.deleted_at IS NULL
          AND r_existente.estado_reserva IN ('PENDIENTE', 'CONFIRMADA', 'SENTADA')
          AND (r_nueva.fecha_hora_inicio < r_existente.fecha_hora_fin
               AND r_nueva.fecha_hora_fin > r_existente.fecha_hora_inicio)
    );
END;

-- 2. Validación al MODIFICAR una asignación (UPDATE en detalle_reservacion)
CREATE TRIGGER IF NOT EXISTS trg_validar_detalle_update
BEFORE UPDATE OF mesa_id, reservacion_id ON detalle_reservacion
BEGIN
    -- A. Rechazar mesas no existentes, inactivas o eliminadas lógicamente
    SELECT RAISE(ABORT, 'Disponibilidad: La mesa reasignada no existe, está eliminada o no se encuentra activa')
    WHERE NOT EXISTS (
        SELECT 1 FROM mesas
        WHERE id = NEW.mesa_id
          AND estado_operativo = 'ACTIVA'
          AND deleted_at IS NULL
    );

    -- B. Rechazar reservaciones canceladas, rechazadas, completadas o eliminadas lógicamente
    SELECT RAISE(ABORT, 'Integridad: No se puede reasignar mesas a una reservación cancelada, rechazada, completada o eliminada')
    WHERE NOT EXISTS (
        SELECT 1 FROM reservaciones
        WHERE id = NEW.reservacion_id
          AND deleted_at IS NULL
          AND estado_reserva IN ('PENDIENTE', 'CONFIRMADA', 'SENTADA')
    );

    -- C. Validar cierres para la nueva mesa o zona
    SELECT RAISE(ABORT, 'Disponibilidad: La mesa o zona reasignada tiene un cierre programado en ese horario')
    WHERE EXISTS (
        SELECT 1
        FROM cierres c
        JOIN reservaciones r ON r.id = NEW.reservacion_id
        JOIN mesas m ON m.id = NEW.mesa_id
        WHERE (r.fecha_hora_inicio < c.fecha_hora_fin AND r.fecha_hora_fin > c.fecha_hora_inicio)
          AND (
              c.tipo_cierre = 'TOTAL_RESTAURANTE'
              OR (c.tipo_cierre = 'ZONA' AND c.zona = m.zona)
              OR (c.tipo_cierre = 'MESA_ESPECIFICA' AND c.mesa_id = NEW.mesa_id)
          )
    );

    -- D. Validar solapamiento con la nueva mesa
    SELECT RAISE(ABORT, 'Conflicto: La nueva mesa asignada ya tiene otra reservación activa en ese horario')
    WHERE EXISTS (
        SELECT 1
        FROM detalle_reservacion dr
        JOIN reservaciones r_existente ON dr.reservacion_id = r_existente.id
        JOIN reservaciones r_nueva ON r_nueva.id = NEW.reservacion_id
        WHERE dr.mesa_id = NEW.mesa_id
          AND dr.id != NEW.id
          AND dr.reservacion_id != NEW.reservacion_id
          AND r_existente.deleted_at IS NULL
          AND r_existente.estado_reserva IN ('PENDIENTE', 'CONFIRMADA', 'SENTADA')
          AND (r_nueva.fecha_hora_inicio < r_existente.fecha_hora_fin
               AND r_nueva.fecha_hora_fin > r_existente.fecha_hora_inicio)
    );
END;

-- 3. Validación al MODIFICAR HORARIOS O REACTIVAR una reservación (UPDATE en reservaciones)
CREATE TRIGGER IF NOT EXISTS trg_validar_reserva_update
BEFORE UPDATE OF fecha_hora_inicio, fecha_hora_fin, fecha_reserva, estado_reserva, deleted_at ON reservaciones
BEGIN
    -- A. Validar que TODAS las mesas asignadas existan, estén activas y no eliminadas
    -- Se activa cuando la reservación pasa a o se mantiene en un estado activo que ocupa mesa
    SELECT RAISE(ABORT, 'Disponibilidad: No se puede activar o mantener activa la reservación porque una o más de sus mesas asignadas no están activas o han sido eliminadas')
    WHERE NEW.deleted_at IS NULL
      AND NEW.estado_reserva IN ('PENDIENTE', 'CONFIRMADA', 'SENTADA')
      AND (
          (OLD.estado_reserva NOT IN ('PENDIENTE', 'CONFIRMADA', 'SENTADA') AND NEW.estado_reserva IN ('PENDIENTE', 'CONFIRMADA', 'SENTADA'))
          OR (OLD.deleted_at IS NOT NULL AND NEW.deleted_at IS NULL)
          OR (OLD.fecha_hora_inicio != NEW.fecha_hora_inicio OR OLD.fecha_hora_fin != NEW.fecha_hora_fin)
      )
      AND EXISTS (
          SELECT 1
          FROM detalle_reservacion dr
          LEFT JOIN mesas m ON dr.mesa_id = m.id
          WHERE dr.reservacion_id = NEW.id
            AND (m.id IS NULL OR m.estado_operativo != 'ACTIVA' OR m.deleted_at IS NOT NULL)
      );

    -- B. Validar solapamiento de cualquiera de sus mesas asignadas con otras reservas activas
    SELECT RAISE(ABORT, 'Conflicto: La mesa asignada ya tiene otra reservación activa en el nuevo horario o al reactivar la reserva')
    WHERE NEW.deleted_at IS NULL
      AND NEW.estado_reserva IN ('PENDIENTE', 'CONFIRMADA', 'SENTADA')
      AND EXISTS (
          SELECT 1
          FROM detalle_reservacion dr1
          JOIN detalle_reservacion dr2 ON dr1.mesa_id = dr2.mesa_id AND dr1.reservacion_id != dr2.reservacion_id
          JOIN reservaciones r_otra ON dr2.reservacion_id = r_otra.id
          WHERE dr1.reservacion_id = NEW.id
            AND r_otra.deleted_at IS NULL
            AND r_otra.estado_reserva IN ('PENDIENTE', 'CONFIRMADA', 'SENTADA')
            AND (NEW.fecha_hora_inicio < r_otra.fecha_hora_fin
                 AND NEW.fecha_hora_fin > r_otra.fecha_hora_inicio)
      );

    -- C. Validar cierres en el nuevo horario para sus mesas asignadas o cierre total
    SELECT RAISE(ABORT, 'Disponibilidad: El nuevo horario coincide con un cierre del restaurante, zona o mesa')
    WHERE NEW.deleted_at IS NULL
      AND NEW.estado_reserva IN ('PENDIENTE', 'CONFIRMADA', 'SENTADA')
      AND (
          EXISTS (
              SELECT 1 FROM cierres c
              WHERE c.tipo_cierre = 'TOTAL_RESTAURANTE'
                AND (NEW.fecha_hora_inicio < c.fecha_hora_fin AND NEW.fecha_hora_fin > c.fecha_hora_inicio)
          )
          OR EXISTS (
              SELECT 1
              FROM detalle_reservacion dr
              JOIN mesas m ON dr.mesa_id = m.id
              JOIN cierres c ON (
                  (c.tipo_cierre = 'ZONA' AND c.zona = m.zona)
                  OR (c.tipo_cierre = 'MESA_ESPECIFICA' AND c.mesa_id = m.id)
              )
              WHERE dr.reservacion_id = NEW.id
                AND (NEW.fecha_hora_inicio < c.fecha_hora_fin AND NEW.fecha_hora_fin > c.fecha_hora_inicio)
          )
      );
END;

-- 4. Protección frente a cambios en MESAS (UPDATE de estado operativo o borrado lógico)
CREATE TRIGGER IF NOT EXISTS trg_proteger_mesa_update
BEFORE UPDATE OF estado_operativo, deleted_at ON mesas
BEGIN
    SELECT RAISE(ABORT, 'Integridad: No se puede desactivar o eliminar una mesa que tiene reservaciones activas futuras asociadas')
    WHERE (NEW.estado_operativo != 'ACTIVA' OR NEW.deleted_at IS NOT NULL)
      AND EXISTS (
          SELECT 1
          FROM detalle_reservacion dr
          JOIN reservaciones r ON dr.reservacion_id = r.id
          WHERE dr.mesa_id = NEW.id
            AND r.deleted_at IS NULL
            AND r.estado_reserva IN ('PENDIENTE', 'CONFIRMADA', 'SENTADA')
            AND r.fecha_hora_fin > strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
      );
END;

-- 5. Protección frente a inserción o modificación de CIERRES con reservas activas
CREATE TRIGGER IF NOT EXISTS trg_proteger_cierre_insert
BEFORE INSERT ON cierres
BEGIN
    SELECT RAISE(ABORT, 'Disponibilidad: No se puede registrar el cierre porque entra en conflicto con reservaciones activas existentes')
    WHERE EXISTS (
        SELECT 1
        FROM reservaciones r
        WHERE r.deleted_at IS NULL
          AND r.estado_reserva IN ('PENDIENTE', 'CONFIRMADA', 'SENTADA')
          AND (r.fecha_hora_inicio < NEW.fecha_hora_fin AND r.fecha_hora_fin > NEW.fecha_hora_inicio)
          AND (
              NEW.tipo_cierre = 'TOTAL_RESTAURANTE'
              OR EXISTS (
                  SELECT 1
                  FROM detalle_reservacion dr
                  JOIN mesas m ON dr.mesa_id = m.id
                  WHERE dr.reservacion_id = r.id
                    AND (
                        (NEW.tipo_cierre = 'ZONA' AND NEW.zona = m.zona)
                        OR (NEW.tipo_cierre = 'MESA_ESPECIFICA' AND NEW.mesa_id = m.id)
                    )
              )
          )
    );
END;

CREATE TRIGGER IF NOT EXISTS trg_proteger_cierre_update
BEFORE UPDATE OF fecha_hora_inicio, fecha_hora_fin, tipo_cierre, zona, mesa_id ON cierres
BEGIN
    SELECT RAISE(ABORT, 'Disponibilidad: No se puede modificar el cierre porque entra en conflicto con reservaciones activas existentes')
    WHERE EXISTS (
        SELECT 1
        FROM reservaciones r
        WHERE r.deleted_at IS NULL
          AND r.estado_reserva IN ('PENDIENTE', 'CONFIRMADA', 'SENTADA')
          AND (r.fecha_hora_inicio < NEW.fecha_hora_fin AND r.fecha_hora_fin > NEW.fecha_hora_inicio)
          AND (
              NEW.tipo_cierre = 'TOTAL_RESTAURANTE'
              OR EXISTS (
                  SELECT 1
                  FROM detalle_reservacion dr
                  JOIN mesas m ON dr.mesa_id = m.id
                  WHERE dr.reservacion_id = r.id
                    AND (
                        (NEW.tipo_cierre = 'ZONA' AND NEW.zona = m.zona)
                        OR (NEW.tipo_cierre = 'MESA_ESPECIFICA' AND NEW.mesa_id = m.id)
                    )
              )
          )
    );
END;

COMMIT;
