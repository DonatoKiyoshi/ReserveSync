-- Escenario 2 - Sesión 1: Reserva de mesas M-03 y M-04 con bloqueo ordenado determinista
\set ON_ERROR_STOP on
\set VERBOSITY verbose
BEGIN;

-- Bloqueo pesimista ordenado por id (regla arquitectónica para reservas grupales)
SELECT id FROM mesas
WHERE id IN (
    '20000000-0000-0000-0000-000000000003'::uuid, -- M-03
    '20000000-0000-0000-0000-000000000004'::uuid  -- M-04
)
ORDER BY id ASC
FOR UPDATE;

INSERT INTO reservaciones (
    id, codigo_reserva, cliente_id, canal_origen, fecha_reserva,
    fecha_hora_inicio, fecha_hora_fin, cantidad_personas, estado_reserva, estado_sync
) VALUES (
    '60000000-0000-0000-0000-000000000201'::uuid, 'RS-CONC-E2-S1',
    '50000000-0000-0000-0000-000000000001'::uuid, 'WEB_PUBLICA', '2026-11-26',
    '2026-11-26T20:00:00Z', '2026-11-26T22:00:00Z', 8, 'CONFIRMADA', 'SYNCED'
);

INSERT INTO detalle_reservacion (id, reservacion_id, mesa_id) VALUES
('70000000-0000-0000-0000-000000000201'::uuid, '60000000-0000-0000-0000-000000000201'::uuid, '20000000-0000-0000-0000-000000000003'::uuid),
('70000000-0000-0000-0000-000000000202'::uuid, '60000000-0000-0000-0000-000000000201'::uuid, '20000000-0000-0000-0000-000000000004'::uuid);

\echo '[E2-S1] Bloqueo ordenado adquirido para M-03 y M-04. Esperando 2 segundos...'
SELECT pg_sleep(2);

COMMIT;
\echo '[E2-S1] Transaccion grupal confirmada exitosamente.'
