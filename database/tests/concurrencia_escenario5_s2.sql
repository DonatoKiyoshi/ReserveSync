-- ============================================================================
-- ReserveSync — Pruebas de Concurrencia PostgreSQL (Escenario 5 - Sesión 2)
-- Intento concurrente de pasar la mesa M-05 a MANTENIMIENTO mientras la
-- Sesión 1 la bloquea para reactivar una reservación activa.
-- ============================================================================

\set ON_ERROR_STOP on
\set VERBOSITY verbose

-- Identificador unívoco de sesión para coordinación
SET application_name = 'reservesync_e5_s2';

-- Sincronización determinista de alta precisión:
-- Espera activa en PostgreSQL verificando en pg_locks y pg_stat_activity que:
-- 1. La tabla objetivo sea exactamente public.mesas.
-- 2. El modo de bloqueo sea exactamente RowShareLock (adquirido por SELECT ... FOR UPDATE).
-- 3. El bloqueo esté concedido (granted = TRUE).
-- 4. El backend pertenezca unívocamente a Sesión 1 (application_name = 'reservesync_e5_s1').
-- 5. Si vence el plazo de espera, arroja SQLSTATE P0001 (raise_exception), NUNCA 23514.
DO $$
DECLARE
    v_bloqueo_adquirido BOOLEAN := FALSE;
    v_intentos INT := 0;
BEGIN
    WHILE NOT v_bloqueo_adquirido AND v_intentos < 100 LOOP
        SELECT EXISTS (
            SELECT 1
            FROM pg_locks l
            JOIN pg_class c ON l.relation = c.oid
            JOIN pg_namespace n ON c.relnamespace = n.oid
            JOIN pg_stat_activity a ON l.pid = a.pid
            WHERE n.nspname = 'public'
              AND c.relname = 'mesas'
              AND l.mode = 'RowShareLock'
              AND l.granted = TRUE
              AND a.application_name = 'reservesync_e5_s1'
              AND a.pid != pg_backend_pid()
        ) INTO v_bloqueo_adquirido;

        IF NOT v_bloqueo_adquirido THEN
            PERFORM pg_sleep(0.05);
            v_intentos := v_intentos + 1;
        END IF;
    END LOOP;

    IF NOT v_bloqueo_adquirido THEN
        -- Se utiliza explícitamente el código P0001 para que jamás coincida con 23514 (check_violation)
        RAISE EXCEPTION 'Timeout de sincronizacion: Sesion 1 (reservesync_e5_s1) no adquirio RowShareLock en public.mesas a tiempo (% intentos)', v_intentos
            USING ERRCODE = 'P0001';
    END IF;

    RAISE NOTICE 'Sincronizacion confirmada: Bloqueo RowShareLock de Sesion 1 detectado en public.mesas tras % intento(s).', v_intentos;
END $$;

-- ----------------------------------------------------------------------------
-- SESIÓN 2: Intento concurrente de desactivar mesa M-05
-- ----------------------------------------------------------------------------
BEGIN;

\echo '[E5-S2] Intentando cambiar la mesa M-05 a MANTENIMIENTO...'
-- Debe bloquearse en espera de la transacción de Sesión 1.
-- Al confirmar Sesión 1, trg_proteger_mesa_update debe rechazar esta operación
-- arrojando SQLSTATE 23514 (check_violation) con el mensaje de fn_proteger_mesa_update.
UPDATE mesas
SET estado_operativo = 'MANTENIMIENTO'
WHERE id = '20000000-0000-0000-0000-000000000005'::uuid; -- M-05

COMMIT;
