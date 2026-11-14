-- ============================================================================
-- ReserveSync — Pruebas de Concurrencia PostgreSQL (Escenario 5 - Sesión 1)
-- Reactivación de reservación previamente cancelada vs intento concurrente
-- de pasar su mesa asignada (M-05) a MANTENIMIENTO.
-- ============================================================================

\set ON_ERROR_STOP on
\set VERBOSITY verbose

-- Identificador unívoco de sesión para detección precisa en pg_stat_activity / pg_locks
SET application_name = 'reservesync_e5_s1';

-- Preparación idempotente de seguridad (por si se ejecuta este script de forma individual)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM reservaciones WHERE id = '60000000-0000-0000-0000-000000000501'::uuid
    ) THEN
        -- 1. Crear la reservación inicialmente como CONFIRMADA
        INSERT INTO reservaciones (
            id, codigo_reserva, cliente_id, canal_origen, fecha_reserva,
            fecha_hora_inicio, fecha_hora_fin, cantidad_personas, estado_reserva, estado_sync
        ) VALUES (
            '60000000-0000-0000-0000-000000000501'::uuid, 'RS-CONC-E5-S1',
            '50000000-0000-0000-0000-000000000001'::uuid, 'DESKTOP_LOCAL', '2026-11-29',
            '2026-11-29T20:00:00Z', '2026-11-29T22:00:00Z', 4, 'CONFIRMADA', 'SYNCED'
        );

        -- 2. Asignarle la mesa M-05 (válida porque la reserva está CONFIRMADA)
        INSERT INTO detalle_reservacion (id, reservacion_id, mesa_id) VALUES (
            '70000000-0000-0000-0000-000000000501'::uuid,
            '60000000-0000-0000-0000-000000000501'::uuid,
            '20000000-0000-0000-0000-000000000005'::uuid -- M-05
        );

        -- 3. Cambiar la reservación a CANCELADA, manteniendo la asignación en detalle_reservacion
        UPDATE reservaciones
        SET estado_reserva = 'CANCELADA'
        WHERE id = '60000000-0000-0000-0000-000000000501'::uuid;
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- SESIÓN 1: Transacción de reactivación concurrente
-- ----------------------------------------------------------------------------
BEGIN;

\echo '[E5-S1] Reactivando reservacion RS-CONC-E5-S1 a CONFIRMADA...'
-- Al pasar de CANCELADA a CONFIRMADA, fn_validar_reserva_update adquiere RowShareLock sobre public.mesas
UPDATE reservaciones
SET estado_reserva = 'CONFIRMADA'
WHERE id = '60000000-0000-0000-0000-000000000501'::uuid;

\echo '[E5-S1] Bloqueo pesimista adquirido sobre mesa M-05. Manteniendo transaccion 2 segundos...'
SELECT pg_sleep(2);

COMMIT;
\echo '[E5-S1] Transaccion de reactivacion confirmada exitosamente.'
