-- Escenario 2 - Sesión 2: Intento concurrente de reservar M-04 y M-03 (solicitadas en orden inverso)
\set ON_ERROR_STOP on
\set VERBOSITY verbose
\echo '[E2-S2] Pausa de 0.3s...'
SELECT pg_sleep(0.3);

BEGIN;

-- La aplicación solicita M-04 y M-03 pero aplica ORDER BY id ASC, evitando el interbloqueo (deadlock)
SELECT id FROM mesas
WHERE id IN (
    '20000000-0000-0000-0000-000000000004'::uuid, -- M-04
    '20000000-0000-0000-0000-000000000003'::uuid  -- M-03
)
ORDER BY id ASC
FOR UPDATE;

INSERT INTO reservaciones (
    id, codigo_reserva, cliente_id, canal_origen, fecha_reserva,
    fecha_hora_inicio, fecha_hora_fin, cantidad_personas, estado_reserva, estado_sync
) VALUES (
    '60000000-0000-0000-0000-000000000202'::uuid, 'RS-CONC-E2-S2',
    '50000000-0000-0000-0000-000000000002'::uuid, 'DESKTOP_LOCAL', '2026-11-26',
    '2026-11-26T20:00:00Z', '2026-11-26T22:00:00Z', 8, 'CONFIRMADA', 'SYNCED'
);

-- Intento de inserción: debe ser rechazado por solapamiento al liberarse S1
INSERT INTO detalle_reservacion (id, reservacion_id, mesa_id) VALUES
('70000000-0000-0000-0000-000000000203'::uuid, '60000000-0000-0000-0000-000000000202'::uuid, '20000000-0000-0000-0000-000000000003'::uuid);

COMMIT;
