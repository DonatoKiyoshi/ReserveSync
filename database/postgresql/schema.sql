-- ============================================================================
-- ReserveSync — Esquema de Base de Datos Central (PostgreSQL)
-- Servidor Backend Spring Boot (Gestión Central y Conexión Web)
-- ============================================================================

-- Extensión pgcrypto para generación de UUIDs nativos
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

BEGIN;

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
-- Timestamps nativos con huso horario UTC (TIMESTAMPTZ)
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
-- Bloqueos continuos expresados en intervalos absolutos UTC (TIMESTAMPTZ)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cierres (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fecha_hora_inicio TIMESTAMPTZ NOT NULL,
    fecha_hora_fin TIMESTAMPTZ NOT NULL,
    tipo_cierre VARCHAR(30) NOT NULL CHECK (tipo_cierre IN ('TOTAL_RESTAURANTE', 'ZONA', 'MESA_ESPECIFICA')),
    zona VARCHAR(50),
    mesa_id UUID,
    motivo VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT chk_cierres_intervalo CHECK (fecha_hora_fin > fecha_hora_inicio),
    CONSTRAINT chk_cierres_tipo_alcance CHECK (
        (tipo_cierre = 'TOTAL_RESTAURANTE' AND zona IS NULL AND mesa_id IS NULL)
        OR (tipo_cierre = 'ZONA' AND zona IS NOT NULL AND mesa_id IS NULL)
        OR (tipo_cierre = 'MESA_ESPECIFICA' AND mesa_id IS NOT NULL AND zona IS NULL)
    ),
    CONSTRAINT fk_cierres_mesa FOREIGN KEY (mesa_id) REFERENCES mesas (id) ON DELETE CASCADE
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
    clave VARCHAR(60) PRIMARY KEY,
    valor TEXT NOT NULL,
    tipo_dato VARCHAR(20) NOT NULL CHECK (tipo_dato IN ('STRING', 'INTEGER', 'BOOLEAN', 'JSON')),
    descripcion VARCHAR(255) NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version INTEGER NOT NULL DEFAULT 1
);

-- ----------------------------------------------------------------------------
-- 10. Tabla: historial_reservaciones
-- Bitácora inmutable de auditoría (ON DELETE RESTRICT para preservar integridad)
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
    CONSTRAINT fk_historial_reserva FOREIGN KEY (reservacion_id) REFERENCES reservaciones (id) ON DELETE RESTRICT,
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
-- Punteros de sincronización por estación y dirección (PUSH / PULL)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sync_cursor (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    terminal_id VARCHAR(60) NOT NULL,
    direccion VARCHAR(10) NOT NULL CHECK (direccion IN ('PUSH', 'PULL')),
    last_sync_timestamp TIMESTAMPTZ NOT NULL,
    last_sync_id UUID,
    last_sync_sequence BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_sync_cursor_terminal_direccion UNIQUE (terminal_id, direccion)
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

-- ----------------------------------------------------------------------------
-- TRIGGERS DE INTEGRIDAD, DISPONIBILIDAD Y CONCURRENCIA (PostgreSQL)
-- ----------------------------------------------------------------------------

-- Función y Trigger 1: Validación al asignar o cambiar mesa (INSERT/UPDATE en detalle_reservacion)
-- Serialización mediante bloqueo pesimista ordenado de la mesa afectada
CREATE OR REPLACE FUNCTION fn_validar_detalle_reservacion()
RETURNS TRIGGER AS $$
DECLARE
    v_inicio TIMESTAMPTZ;
    v_fin TIMESTAMPTZ;
    v_estado VARCHAR(25);
    v_deleted TIMESTAMPTZ;
    v_mesa_estado VARCHAR(25);
    v_mesa_deleted TIMESTAMPTZ;
    v_mesa_zona VARCHAR(50);
    v_conflicto_codigo VARCHAR(20);
    v_cierre_motivo VARCHAR(255);
BEGIN
    -- 1. Serializar acceso a la mesa para evitar condiciones de carrera (Race Conditions)
    SELECT estado_operativo, deleted_at, zona
    INTO v_mesa_estado, v_mesa_deleted, v_mesa_zona
    FROM mesas
    WHERE id = NEW.mesa_id
    FOR UPDATE;

    IF v_mesa_estado IS NULL THEN
        RAISE EXCEPTION 'Disponibilidad: La mesa especificada no existe' USING ERRCODE = 'check_violation';
    END IF;

    -- 2. Validar que la mesa esté ACTIVA y no esté eliminada lógicamente
    IF v_mesa_deleted IS NOT NULL OR v_mesa_estado != 'ACTIVA' THEN
        RAISE EXCEPTION 'Disponibilidad: La mesa % no está activa o se encuentra eliminada/en mantenimiento', NEW.mesa_id
            USING ERRCODE = 'check_violation';
    END IF;

    -- 3. Obtener ventana horaria y estado de la reservación
    SELECT fecha_hora_inicio, fecha_hora_fin, estado_reserva, deleted_at
    INTO v_inicio, v_fin, v_estado, v_deleted
    FROM reservaciones
    WHERE id = NEW.reservacion_id;

    IF v_estado IS NULL THEN
        RAISE EXCEPTION 'Integridad: La reservación especificada no existe' USING ERRCODE = 'check_violation';
    END IF;

    -- 4. Rechazar asignaciones a reservaciones inactivas, canceladas, rechazadas, completadas o eliminadas
    IF v_deleted IS NOT NULL OR v_estado NOT IN ('PENDIENTE', 'CONFIRMADA', 'SENTADA') THEN
        RAISE EXCEPTION 'Integridad: No se puede asignar mesas a una reservación inactiva, cancelada, rechazada, completada o eliminada (%)', v_estado
            USING ERRCODE = 'check_violation';
    END IF;

    -- 5. Validar cierres programados (total, por zona o por mesa específica) usando intervalos absolutos
    SELECT c.motivo INTO v_cierre_motivo
    FROM cierres c
    WHERE (v_inicio < c.fecha_hora_fin AND v_fin > c.fecha_hora_inicio)
      AND (
          c.tipo_cierre = 'TOTAL_RESTAURANTE'
          OR (c.tipo_cierre = 'ZONA' AND c.zona = v_mesa_zona)
          OR (c.tipo_cierre = 'MESA_ESPECIFICA' AND c.mesa_id = NEW.mesa_id)
      )
    LIMIT 1;

    IF v_cierre_motivo IS NOT NULL THEN
        RAISE EXCEPTION 'Disponibilidad: Existe un cierre programado ("%") que afecta a la mesa en esa fecha/hora', v_cierre_motivo
            USING ERRCODE = 'check_violation';
    END IF;

    -- 6. Validar solapamiento con otra reservación activa (PENDIENTE, CONFIRMADA, SENTADA)
    SELECT r.codigo_reserva INTO v_conflicto_codigo
    FROM detalle_reservacion dr
    JOIN reservaciones r ON dr.reservacion_id = r.id
    WHERE dr.mesa_id = NEW.mesa_id
      AND dr.id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid)
      AND dr.reservacion_id != NEW.reservacion_id
      AND r.deleted_at IS NULL
      AND r.estado_reserva IN ('PENDIENTE', 'CONFIRMADA', 'SENTADA')
      AND (v_inicio < r.fecha_hora_fin AND v_fin > r.fecha_hora_inicio)
    LIMIT 1;

    IF v_conflicto_codigo IS NOT NULL THEN
        RAISE EXCEPTION 'Conflicto: La mesa % ya se encuentra asignada a la reservación activa % en ese horario',
            NEW.mesa_id, v_conflicto_codigo
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_validar_detalle_reservacion
BEFORE INSERT OR UPDATE ON detalle_reservacion
FOR EACH ROW EXECUTE FUNCTION fn_validar_detalle_reservacion();

-- Función y Trigger 2: Validación al modificar horarios o reactivar una reservación (UPDATE en reservaciones)
-- Bloqueo determinista (ORDER BY id ASC) de todas las mesas involucradas para evitar deadlocks
CREATE OR REPLACE FUNCTION fn_validar_reserva_update()
RETURNS TRIGGER AS $$
DECLARE
    v_conflicto_mesa VARCHAR(20);
    v_cierre_motivo VARCHAR(255);
BEGIN
    -- Si la reservación pasa a un estado inactivo o eliminada, no bloquea disponibilidad
    IF NEW.estado_reserva NOT IN ('PENDIENTE', 'CONFIRMADA', 'SENTADA') OR NEW.deleted_at IS NOT NULL THEN
        RETURN NEW;
    END IF;

    IF (OLD.fecha_hora_inicio != NEW.fecha_hora_inicio
        OR OLD.fecha_hora_fin != NEW.fecha_hora_fin
        OR OLD.fecha_reserva != NEW.fecha_reserva
        OR OLD.estado_reserva != NEW.estado_reserva
        OR (OLD.deleted_at IS NOT NULL AND NEW.deleted_at IS NULL)) THEN

        -- 1 y 2. Bloquear todas las mesas asignadas a la reservación en orden ascendente por UUID
        PERFORM 1 FROM mesas
        WHERE id IN (SELECT mesa_id FROM detalle_reservacion WHERE reservacion_id = NEW.id)
        ORDER BY id ASC
        FOR UPDATE;

        -- 3 y 4. Una vez adquiridos los bloqueos, comprobar que TODAS las mesas existan, estén activas y no eliminadas
        SELECT COALESCE(m.numero_mesa, dr.mesa_id::text) INTO v_conflicto_mesa
        FROM detalle_reservacion dr
        LEFT JOIN mesas m ON dr.mesa_id = m.id
        WHERE dr.reservacion_id = NEW.id
          AND (m.id IS NULL OR m.estado_operativo != 'ACTIVA' OR m.deleted_at IS NOT NULL)
        LIMIT 1;

        IF v_conflicto_mesa IS NOT NULL THEN
            RAISE EXCEPTION 'Disponibilidad: No se puede reactivar o actualizar la reservación porque una de sus mesas asignadas (%) no está activa o fue eliminada',
                v_conflicto_mesa
                USING ERRCODE = 'check_violation';
        END IF;

        -- C. Validar solapamiento en cualquiera de sus mesas
        SELECT m.numero_mesa INTO v_conflicto_mesa
        FROM detalle_reservacion dr1
        JOIN mesas m ON dr1.mesa_id = m.id
        JOIN detalle_reservacion dr2 ON dr1.mesa_id = dr2.mesa_id AND dr2.reservacion_id != NEW.id
        JOIN reservaciones r2 ON dr2.reservacion_id = r2.id
        WHERE dr1.reservacion_id = NEW.id
          AND r2.deleted_at IS NULL
          AND r2.estado_reserva IN ('PENDIENTE', 'CONFIRMADA', 'SENTADA')
          AND (NEW.fecha_hora_inicio < r2.fecha_hora_fin AND NEW.fecha_hora_fin > r2.fecha_hora_inicio)
        LIMIT 1;

        IF v_conflicto_mesa IS NOT NULL THEN
            RAISE EXCEPTION 'Conflicto: La mesa % ya se encuentra ocupada en el nuevo rango seleccionado o al reactivar la reserva',
                v_conflicto_mesa
                USING ERRCODE = 'check_violation';
        END IF;

        -- D. Validar cierres en el nuevo horario (total, de zona o de mesa)
        SELECT c.motivo INTO v_cierre_motivo
        FROM cierres c
        WHERE (NEW.fecha_hora_inicio < c.fecha_hora_fin AND NEW.fecha_hora_fin > c.fecha_hora_inicio)
          AND (
              c.tipo_cierre = 'TOTAL_RESTAURANTE'
              OR EXISTS (
                  SELECT 1 FROM detalle_reservacion dr
                  JOIN mesas m ON dr.mesa_id = m.id
                  WHERE dr.reservacion_id = NEW.id
                    AND (
                        (c.tipo_cierre = 'ZONA' AND c.zona = m.zona)
                        OR (c.tipo_cierre = 'MESA_ESPECIFICA' AND c.mesa_id = m.id)
                    )
              )
          )
        LIMIT 1;

        IF v_cierre_motivo IS NOT NULL THEN
            RAISE EXCEPTION 'Disponibilidad: El nuevo horario coincide con un cierre programado ("%")', v_cierre_motivo
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_validar_reserva_update
BEFORE UPDATE OF fecha_hora_inicio, fecha_hora_fin, fecha_reserva, estado_reserva, deleted_at ON reservaciones
FOR EACH ROW EXECUTE FUNCTION fn_validar_reserva_update();

-- Función y Trigger 3: Proteger mesas frente a cambios administrativos de mantenimiento o borrado lógico
CREATE OR REPLACE FUNCTION fn_proteger_mesa_update()
RETURNS TRIGGER AS $$
DECLARE
    v_conflicto_reserva VARCHAR(20);
BEGIN
    IF (NEW.estado_operativo != 'ACTIVA' OR (OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL)) THEN
        SELECT r.codigo_reserva INTO v_conflicto_reserva
        FROM detalle_reservacion dr
        JOIN reservaciones r ON dr.reservacion_id = r.id
        WHERE dr.mesa_id = NEW.id
          AND r.deleted_at IS NULL
          AND r.estado_reserva IN ('PENDIENTE', 'CONFIRMADA', 'SENTADA')
          AND r.fecha_hora_fin > CURRENT_TIMESTAMP
        LIMIT 1;

        IF v_conflicto_reserva IS NOT NULL THEN
            RAISE EXCEPTION 'Integridad: No se puede desactivar o eliminar la mesa % porque tiene reservaciones activas futuras asociadas (código: %)',
                NEW.numero_mesa, v_conflicto_reserva
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_proteger_mesa_update
BEFORE UPDATE OF estado_operativo, deleted_at ON mesas
FOR EACH ROW EXECUTE FUNCTION fn_proteger_mesa_update();

-- Función y Trigger 4: Proteger frente a creación o modificación de cierres con reservas activas concurrentes
CREATE OR REPLACE FUNCTION fn_proteger_cierre()
RETURNS TRIGGER AS $$
DECLARE
    v_conflicto_codigo VARCHAR(20);
BEGIN
    -- Bloqueo pesimista de mesas afectadas en orden determinista
    IF NEW.tipo_cierre = 'MESA_ESPECIFICA' THEN
        PERFORM 1 FROM mesas WHERE id = NEW.mesa_id FOR UPDATE;
    ELSIF NEW.tipo_cierre = 'ZONA' THEN
        PERFORM 1 FROM mesas WHERE zona = NEW.zona ORDER BY id ASC FOR UPDATE;
    ELSIF NEW.tipo_cierre = 'TOTAL_RESTAURANTE' THEN
        PERFORM 1 FROM mesas ORDER BY id ASC FOR UPDATE;
    END IF;

    -- Comprobar si existen reservaciones activas que coincidan con el cierre
    SELECT r.codigo_reserva INTO v_conflicto_codigo
    FROM reservaciones r
    WHERE r.deleted_at IS NULL
      AND r.estado_reserva IN ('PENDIENTE', 'CONFIRMADA', 'SENTADA')
      AND (r.fecha_hora_inicio < NEW.fecha_hora_fin AND r.fecha_hora_fin > NEW.fecha_hora_inicio)
      AND (
          NEW.tipo_cierre = 'TOTAL_RESTAURANTE'
          OR EXISTS (
              SELECT 1 FROM detalle_reservacion dr
              JOIN mesas m ON dr.mesa_id = m.id
              WHERE dr.reservacion_id = r.id
                AND (
                    (NEW.tipo_cierre = 'ZONA' AND NEW.zona = m.zona)
                    OR (NEW.tipo_cierre = 'MESA_ESPECIFICA' AND NEW.mesa_id = m.id)
                )
          )
      )
    LIMIT 1;

    IF v_conflicto_codigo IS NOT NULL THEN
        RAISE EXCEPTION 'Disponibilidad: No se puede programar o modificar el cierre porque entra en conflicto con la reservación activa %',
            v_conflicto_codigo
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_proteger_cierre_insert_update
BEFORE INSERT OR UPDATE OF fecha_hora_inicio, fecha_hora_fin, tipo_cierre, zona, mesa_id ON cierres
FOR EACH ROW EXECUTE FUNCTION fn_proteger_cierre();

COMMIT;
