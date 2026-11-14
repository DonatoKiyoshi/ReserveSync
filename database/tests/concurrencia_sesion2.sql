-- ============================================================================
-- ReserveSync — Prueba de Concurrencia (Conexión 2)
-- Compite de forma simultánea por la misma mesa M-02
-- ============================================================================

\echo '[SESION 2] Esperando 0.5s para asegurar que Sesion 1 adquirio el bloqueo inicial...'
SELECT pg_sleep(0.5);

\echo '[SESION 2] Intentando reservar de forma simultanea la misma mesa M-02...'
BEGIN;

INSERT INTO reservaciones (
    id, codigo_reserva, cliente_id, canal_origen, fecha_reserva,
    fecha_hora_inicio, fecha_hora_fin, cantidad_personas, estado_reserva, estado_sync
) VALUES (
    '60000000-0000-0000-0000-000000000102'::uuid, 'RS-CONC-S2',
    '50000000-0000-0000-0000-000000000002'::uuid, 'DESKTOP_LOCAL', '2026-11-19',
    '2026-11-19T20:00:00Z', '2026-11-19T21:30:00Z', 2, 'CONFIRMADA', 'SYNCED'
);

-- Intento de insercion sobre la misma mesa M-02.
-- Debe entrar en espera pasiva por el FOR UPDATE de la Sesion 1.
-- Al hacer COMMIT Sesion 1, el trigger despierta, detecta el solapamiento y aborta con error.
INSERT INTO detalle_reservacion (id, reservacion_id, mesa_id)
VALUES (
    '70000000-0000-0000-0000-000000000102'::uuid,
    '60000000-0000-0000-0000-000000000102'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid -- Mesa M-02
);

COMMIT;
