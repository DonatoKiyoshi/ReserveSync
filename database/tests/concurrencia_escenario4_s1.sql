-- Escenario 4 - Sesión 1: Desactivación administrativa de mesa M-06
\set ON_ERROR_STOP on
\set VERBOSITY verbose
BEGIN;

UPDATE mesas
SET estado_operativo = 'MANTENIMIENTO'
WHERE id = '20000000-0000-0000-0000-000000000006'::uuid; -- M-06

\echo '[E4-S1] Mesa M-06 pasada a MANTENIMIENTO. Esperando 2 segundos...'
SELECT pg_sleep(2);

COMMIT;
\echo '[E4-S1] Desactivacion confirmada exitosamente.'
