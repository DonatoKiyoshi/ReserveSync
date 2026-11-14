-- Escenario 3 - Sesión 2: Intento concurrente de reservar en zona afectada por cierre
\set ON_ERROR_STOP on
\set VERBOSITY verbose
\echo '[E3-S2] Pausa de 0.3s...'
SELECT pg_sleep(0.3);

BEGIN;

INSERT INTO reservaciones (
    id, codigo_reserva, cliente_id, canal_origen, fecha_reserva,
    fecha_hora_inicio, fecha_hora_fin, cantidad_personas, estado_reserva, estado_sync
) VALUES (
    '60000000-0000-0000-0000-000000000302'::uuid, 'RS-CONC-E3-S2',
    '50000000-0000-0000-0000-000000000001'::uuid, 'WEB_PUBLICA', '2026-11-27',
    '2026-11-27T19:00:00Z', '2026-11-27T20:30:00Z', 2, 'CONFIRMADA', 'SYNCED'
);

-- Intento de asignar mesa T-02 en TERRAZA: debe ser retenido por el lock del cierre y luego abortar
INSERT INTO detalle_reservacion (id, reservacion_id, mesa_id) VALUES (
    '70000000-0000-0000-0000-000000000302'::uuid,
    '60000000-0000-0000-0000-000000000302'::uuid,
    '20000000-0000-0000-0000-000000000008'::uuid -- T-02
);

COMMIT;
