-- Escenario 3 - Sesión 1: Creación de cierre programado en zona Terraza
\set ON_ERROR_STOP on
\set VERBOSITY verbose
BEGIN;

INSERT INTO cierres (
    id, fecha_hora_inicio, fecha_hora_fin, tipo_cierre, zona, mesa_id, motivo
) VALUES (
    '40000000-0000-0000-0000-000000000301'::uuid,
    '2026-11-27T18:00:00Z', '2026-11-27T23:59:00Z',
    'ZONA', 'TERRAZA', NULL, 'Mantenimiento preventivo de cancelería'
);

\echo '[E3-S1] Cierre creado y mesas de TERRAZA bloqueadas. Esperando 2 segundos...'
SELECT pg_sleep(2);

COMMIT;
\echo '[E3-S1] Cierre confirmado exitosamente.'
