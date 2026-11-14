\set ON_ERROR_STOP on
-- ============================================================================
-- ReserveSync — Batería de Pruebas Automatizadas de Integridad (PostgreSQL)
-- Ejecutar con: psql -U postgres -d reservesync_test_db -f test_postgresql_integrity.sql
-- ============================================================================

\echo '======================================================================'
\echo 'RESERVESYNC — PRUEBAS DE INTEGRIDAD Y REGLAS DE NEGOCIO (POSTGRESQL)'
\echo '======================================================================'

-- 1. Verificación de conteo base
SELECT count(*) AS total_reservaciones_comunes FROM reservaciones;

-- 2. Prueba de Idempotencia de semillas
\echo '\n[PRUEBA 1] Verificando Idempotencia del script seed...'
\i database/seed/postgresql_seed.sql
\echo '  -> OK: Seed ejecutado nuevamente sin errores por claves duplicadas.'

-- 3. Prueba: Intentar asignar una mesa eliminada lógicamente
\echo '\n[PRUEBA 2] Intentando asignar una mesa eliminada lógicamente...'
DO $$
DECLARE
    v_mesa_del UUID := '20000000-0000-0000-0000-000000000099'::uuid;
    v_reserva UUID := '60000000-0000-0000-0000-000000000001'::uuid;
BEGIN
    INSERT INTO mesas (id, numero_mesa, zona, capacidad_minima, capacidad_maxima, estado_operativo, deleted_at)
    VALUES (v_mesa_del, 'M-DEL', 'SALA_PRINCIPAL', 2, 4, 'ACTIVA', CURRENT_TIMESTAMP)
    ON CONFLICT (id) DO UPDATE SET deleted_at = CURRENT_TIMESTAMP;

    BEGIN
        INSERT INTO detalle_reservacion (id, reservacion_id, mesa_id)
        VALUES (gen_random_uuid(), v_reserva, v_mesa_del);

        RAISE EXCEPTION 'FALLO: Se permitió asignar una mesa eliminada.';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE '  -> OK: Rechazado por trigger fn_validar_detalle_reservacion: %', SQLERRM;
    END;
END $$;

-- 4. Prueba: Intentar asignar una reservación cancelada
\echo '\n[PRUEBA 3] Intentando asignar una mesa a una reservación cancelada...'
DO $$
DECLARE
    v_reserva_canc UUID := '60000000-0000-0000-0000-000000000099'::uuid;
    v_mesa UUID := '20000000-0000-0000-0000-000000000001'::uuid;
BEGIN
    INSERT INTO reservaciones (
        id, codigo_reserva, cliente_id, canal_origen, fecha_reserva,
        fecha_hora_inicio, fecha_hora_fin, cantidad_personas, estado_reserva, estado_sync
    ) VALUES (
        v_reserva_canc, 'RS-TEST-CANC', '50000000-0000-0000-0000-000000000001'::uuid,
        'DESKTOP_LOCAL', '2026-11-17', '2026-11-17T20:00:00Z', '2026-11-17T21:30:00Z',
        2, 'CANCELADA', 'SYNCED'
    ) ON CONFLICT (id) DO UPDATE SET estado_reserva = 'CANCELADA';

    BEGIN
        INSERT INTO detalle_reservacion (id, reservacion_id, mesa_id)
        VALUES (gen_random_uuid(), v_reserva_canc, v_mesa);

        RAISE EXCEPTION 'FALLO: Se permitió asignar mesa a una reservación cancelada.';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE '  -> OK: Rechazado por trigger fn_validar_detalle_reservacion: %', SQLERRM;
    END;
END $$;

-- 5. Prueba: Modificar una asignación para provocar solapamiento
\echo '\n[PRUEBA 4] Intentando modificar una asignación para producir solapamiento...'
DO $$
DECLARE
    v_reserva_solap UUID := '60000000-0000-0000-0000-000000000088'::uuid;
    v_detalle_id UUID := '70000000-0000-0000-0000-000000000088'::uuid;
    v_mesa_m01 UUID := '20000000-0000-0000-0000-000000000001'::uuid;
    v_mesa_m02 UUID := '20000000-0000-0000-0000-000000000002'::uuid;
BEGIN
    INSERT INTO reservaciones (
        id, codigo_reserva, cliente_id, canal_origen, fecha_reserva,
        fecha_hora_inicio, fecha_hora_fin, cantidad_personas, estado_reserva, estado_sync
    ) VALUES (
        v_reserva_solap, 'RS-TEST-SOLAP', '50000000-0000-0000-0000-000000000001'::uuid,
        'DESKTOP_LOCAL', '2026-11-15', '2026-11-15T20:00:00Z', '2026-11-15T21:30:00Z',
        2, 'CONFIRMADA', 'SYNCED'
    ) ON CONFLICT (id) DO NOTHING;

    INSERT INTO detalle_reservacion (id, reservacion_id, mesa_id)
    VALUES (v_detalle_id, v_reserva_solap, v_mesa_m02)
    ON CONFLICT (id) DO NOTHING;

    BEGIN
        UPDATE detalle_reservacion
        SET mesa_id = v_mesa_m01
        WHERE id = v_detalle_id;

        RAISE EXCEPTION 'FALLO: Se permitió reasignar la mesa generando solapamiento con R1.';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE '  -> OK: Rechazado por trigger fn_validar_detalle_reservacion: %', SQLERRM;
    END;
END $$;

-- 6. Prueba: Intentar crear un cierre que afecte una reservación activa existente
\echo '\n[PRUEBA 5] Intentando crear un cierre que afecte una reservación activa...'
DO $$
BEGIN
    BEGIN
        INSERT INTO cierres (id, fecha_hora_inicio, fecha_hora_fin, tipo_cierre, zona, mesa_id, motivo)
        VALUES (
            '40000000-0000-0000-0000-000000000099'::uuid,
            '2026-11-15T19:00:00Z', '2026-11-15T23:00:00Z',
            'TOTAL_RESTAURANTE', NULL, NULL, 'Cierre sanitario de emergencia'
        );

        RAISE EXCEPTION 'FALLO: Se permitió registrar un cierre afectando a la reservación R1.';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE '  -> OK: Rechazado por trigger fn_proteger_cierre: %', SQLERRM;
    END;
END $$;

-- 7. Prueba: Asignar reservación dentro de un cierre parcial en UTC
\echo '\n[PRUEBA 6] Intentando asignar una reservación dentro del cierre de mesa B-02...'
DO $$
DECLARE
    v_reserva_cierre UUID := '60000000-0000-0000-0000-000000000077'::uuid;
    v_mesa_b02 UUID := '20000000-0000-0000-0000-000000000012'::uuid;
BEGIN
    INSERT INTO reservaciones (
        id, codigo_reserva, cliente_id, canal_origen, fecha_reserva,
        fecha_hora_inicio, fecha_hora_fin, cantidad_personas, estado_reserva, estado_sync
    ) VALUES (
        v_reserva_cierre, 'RS-TEST-CIERRE', '50000000-0000-0000-0000-000000000001'::uuid,
        'DESKTOP_LOCAL', '2026-11-18', '2026-11-18T21:00:00Z', '2026-11-18T22:30:00Z',
        2, 'CONFIRMADA', 'SYNCED'
    ) ON CONFLICT (id) DO NOTHING;

    BEGIN
        INSERT INTO detalle_reservacion (id, reservacion_id, mesa_id)
        VALUES (gen_random_uuid(), v_reserva_cierre, v_mesa_b02);

        RAISE EXCEPTION 'FALLO: Se permitió asignar mesa dentro del cierre parcial.';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE '  -> OK: Rechazado por trigger fn_validar_detalle_reservacion: %', SQLERRM;
    END;
END $$;

-- 8. Prueba: Intentar poner una mesa en mantenimiento cuando tiene reservaciones futuras
\echo '\n[PRUEBA 7] Intentando poner mesa M-01 en mantenimiento teniendo reservaciones futuras...'
DO $$
DECLARE
    v_mesa_m01 UUID := '20000000-0000-0000-0000-000000000001'::uuid;
BEGIN
    BEGIN
        UPDATE mesas
        SET estado_operativo = 'MANTENIMIENTO'
        WHERE id = v_mesa_m01;

        RAISE EXCEPTION 'FALLO: Se permitió desactivar una mesa con reservaciones futuras.';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE '  -> OK: Rechazado por trigger fn_proteger_mesa_update: %', SQLERRM;
    END;
END $$;

-- 9. Prueba: Intentar reactivar reservación cuya mesa pasó a mantenimiento
\echo '\n[PRUEBA 8] Intentando reactivar reservación cuya mesa pasó a mantenimiento...'
DO $$
DECLARE
    v_mesa_t8 UUID := '20000000-0000-0000-0000-000000000050'::uuid;
    v_res_t8 UUID := '60000000-0000-0000-0000-000000000050'::uuid;
BEGIN
    -- Limpieza previa para garantizar idempotencia y estado limpio en re-ejecuciones
    DELETE FROM detalle_reservacion WHERE reservacion_id = v_res_t8;
    DELETE FROM reservaciones WHERE id = v_res_t8;

    -- 1. Asegurar que la mesa de prueba esté activa
    INSERT INTO mesas (id, numero_mesa, zona, capacidad_minima, capacidad_maxima, estado_operativo)
    VALUES (v_mesa_t8, 'M-T8', 'SALA_PRINCIPAL', 2, 4, 'ACTIVA')
    ON CONFLICT (id) DO UPDATE SET estado_operativo = 'ACTIVA', deleted_at = NULL;

    -- 2. Crear una reservación en estado CONFIRMADA
    INSERT INTO reservaciones (id, codigo_reserva, cliente_id, canal_origen, fecha_reserva, fecha_hora_inicio, fecha_hora_fin, cantidad_personas, estado_reserva, estado_sync)
    VALUES (v_res_t8, 'RS-TEST-PG-T8', '50000000-0000-0000-0000-000000000001'::uuid, 'DESKTOP_LOCAL', '2026-11-22', '2026-11-22T20:00:00Z', '2026-11-22T21:30:00Z', 2, 'CONFIRMADA', 'SYNCED');

    -- 3. Asignar la mesa a esa reservación mientras la mesa está activa
    INSERT INTO detalle_reservacion (id, reservacion_id, mesa_id)
    VALUES (gen_random_uuid(), v_res_t8, v_mesa_t8);

    -- 4. Cambiar la reservación a CANCELADA, conservando su detalle de asignación
    UPDATE reservaciones
    SET estado_reserva = 'CANCELADA'
    WHERE id = v_res_t8;

    -- 5. Cambiar la mesa a MANTENIMIENTO
    UPDATE mesas
    SET estado_operativo = 'MANTENIMIENTO'
    WHERE id = v_mesa_t8;

    -- 6. Intentar cambiar la reservación de CANCELADA a CONFIRMADA
    -- 7. Verificar que el trigger rechace la reactivación por disponibilidad de la mesa
    -- 8. Capturar el rechazo esperado dentro de un bloque EXCEPTION
    BEGIN
        UPDATE reservaciones
        SET estado_reserva = 'CONFIRMADA'
        WHERE id = v_res_t8;

        RAISE EXCEPTION 'FALLO: Se permitió reactivar una reservación con mesa inactiva/en mantenimiento.';
    EXCEPTION
        WHEN check_violation THEN
            -- Verificar que el error capturado sea realmente el rechazo esperado por mesa inactiva o en mantenimiento
            IF SQLERRM LIKE '%no está activa o fue eliminada%' OR SQLERRM LIKE '%mantenimiento%' THEN
                RAISE NOTICE '  -> OK: Rechazado por trigger fn_validar_reserva_update: %', SQLERRM;
            ELSE
                RAISE EXCEPTION 'FALLO: Se capturó check_violation pero no corresponde al motivo esperado: %', SQLERRM;
            END IF;
    END;

    -- Limpieza posterior para dejar la base en estado consistente
    DELETE FROM detalle_reservacion WHERE reservacion_id = v_res_t8;
    DELETE FROM reservaciones WHERE id = v_res_t8;
    DELETE FROM mesas WHERE id = v_mesa_t8;
END $$;

-- 10. Prueba: Restricción estricta de alcance en cierres (MESA_ESPECIFICA con zona no nula)
\echo '\n[PRUEBA 9] Intentando registrar cierre MESA_ESPECIFICA especificando zona...'
DO $$
BEGIN
    BEGIN
        INSERT INTO cierres (id, fecha_hora_inicio, fecha_hora_fin, tipo_cierre, zona, mesa_id, motivo)
        VALUES (
            '40000000-0000-0000-0000-000000000060'::uuid,
            '2026-12-01T20:00:00Z', '2026-12-01T23:00:00Z',
            'MESA_ESPECIFICA', 'BAR', '20000000-0000-0000-0000-000000000011'::uuid,
            'Mantenimiento no válido con zona'
        );

        RAISE EXCEPTION 'FALLO: Se permitió registrar cierre MESA_ESPECIFICA con zona no nula.';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE '  -> OK: Rechazado por restricción chk_cierres_tipo_alcance: %', SQLERRM;
    END;
END $$;

\echo '\n======================================================================'
\echo 'TODAS LAS PRUEBAS DE INTEGRIDAD EN POSTGRESQL FINALIZADAS'
\echo '======================================================================'
