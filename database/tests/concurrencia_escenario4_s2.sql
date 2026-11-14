-- Escenario 4 - Sesión 2: Intento concurrente de reservar la mesa M-06 en proceso de desactivación
\set ON_ERROR_STOP on
\set VERBOSITY verbose
\echo '[E4-S2] Pausa de 0.3s...'
SELECT pg_sleep(0.3);

BEGIN;

INSERT INTO reservaciones (
    id, codigo_reserva, cliente_id, canal_origen, fecha_reserva,
    fecha_hora_inicio, fecha_hora_fin, cantidad_personas, estado_reserva, estado_sync
) VALUES (
    '60000000-0000-0000-0000-000000000402'::uuid, 'RS-CONC-E4-S2',
    '50000000-0000-0000-0000-000000000001'::uuid, 'WEB_PUBLICA', '2026-11-28',
    '2026-11-28T20:00:00Z', '2026-11-28T21:30:00Z', 6, 'CONFIRMADA', 'SYNCED'
);

-- Intento de asignar mesa M-06: bloquea en FOR UPDATE de S1 y luego aborta porque estado != ACTIVA
INSERT INTO detalle_reservacion (id, reservacion_id, mesa_id) VALUES (
    '70000000-0000-0000-0000-000000000402'::uuid,
    '60000000-0000-0000-0000-000000000402'::uuid,
    '20000000-0000-0000-0000-000000000006'::uuid -- M-06
);

COMMIT;
