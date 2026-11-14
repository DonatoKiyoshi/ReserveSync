-- Escenario 1 - Sesión 1: Reserva de mesa M-02 con retención de bloqueo pesimista
\set ON_ERROR_STOP on
\set VERBOSITY verbose
BEGIN;

INSERT INTO reservaciones (
    id, codigo_reserva, cliente_id, canal_origen, fecha_reserva,
    fecha_hora_inicio, fecha_hora_fin, cantidad_personas, estado_reserva, estado_sync
) VALUES (
    '60000000-0000-0000-0000-000000000101'::uuid, 'RS-CONC-E1-S1',
    '50000000-0000-0000-0000-000000000001'::uuid, 'WEB_PUBLICA', '2026-11-25',
    '2026-11-25T20:00:00Z', '2026-11-25T21:30:00Z', 2, 'CONFIRMADA', 'SYNCED'
);

INSERT INTO detalle_reservacion (id, reservacion_id, mesa_id)
VALUES (
    '70000000-0000-0000-0000-000000000101'::uuid,
    '60000000-0000-0000-0000-000000000101'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid -- M-02
);

\echo '[E1-S1] Bloqueo adquirido sobre M-02. Esperando 2 segundos...'
SELECT pg_sleep(2);

COMMIT;
\echo '[E1-S1] Transaccion confirmada exitosamente.'
