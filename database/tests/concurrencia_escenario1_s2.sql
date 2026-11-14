-- Escenario 1 - Sesión 2: Intento concurrente de reservar la misma mesa M-02
\set ON_ERROR_STOP on
\set VERBOSITY verbose
\echo '[E1-S2] Pausa inicial de 0.3s para asegurar que Sesion 1 inicio...'
SELECT pg_sleep(0.3);

BEGIN;

INSERT INTO reservaciones (
    id, codigo_reserva, cliente_id, canal_origen, fecha_reserva,
    fecha_hora_inicio, fecha_hora_fin, cantidad_personas, estado_reserva, estado_sync
) VALUES (
    '60000000-0000-0000-0000-000000000102'::uuid, 'RS-CONC-E1-S2',
    '50000000-0000-0000-0000-000000000002'::uuid, 'DESKTOP_LOCAL', '2026-11-25',
    '2026-11-25T20:00:00Z', '2026-11-25T21:30:00Z', 2, 'CONFIRMADA', 'SYNCED'
);

-- Intento de inserción: debe entrar en espera por FOR UPDATE de S1 y luego abortar
INSERT INTO detalle_reservacion (id, reservacion_id, mesa_id)
VALUES (
    '70000000-0000-0000-0000-000000000102'::uuid,
    '60000000-0000-0000-0000-000000000102'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid -- M-02
);

COMMIT;
