-- ============================================================================
-- ReserveSync — Prueba de Concurrencia (Conexión 1)
-- ============================================================================

\echo '[SESION 1] Iniciando transaccion de reserva para mesa M-02...'
BEGIN;

-- 1. Insertar cabecera de reservacion S1
INSERT INTO reservaciones (
    id, codigo_reserva, cliente_id, canal_origen, fecha_reserva,
    fecha_hora_inicio, fecha_hora_fin, cantidad_personas, estado_reserva, estado_sync
) VALUES (
    '60000000-0000-0000-0000-000000000101'::uuid, 'RS-CONC-S1',
    '50000000-0000-0000-0000-000000000001'::uuid, 'WEB_PUBLICA', '2026-11-19',
    '2026-11-19T20:00:00Z', '2026-11-19T21:30:00Z', 2, 'CONFIRMADA', 'SYNCED'
);

-- 2. Asignar mesa M-02 (esto bloquea pesimistamente la fila de M-02 mediante FOR UPDATE)
INSERT INTO detalle_reservacion (id, reservacion_id, mesa_id)
VALUES (
    '70000000-0000-0000-0000-000000000101'::uuid,
    '60000000-0000-0000-0000-000000000101'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid -- Mesa M-02
);

\echo '[SESION 1] Bloqueo adquirido sobre M-02. Simulando procesamiento de pago (3 segundos)...'
SELECT pg_sleep(3);

\echo '[SESION 1] Confirmando transaccion (COMMIT)...'
COMMIT;
\echo '[SESION 1] Transaccion completada con exito.'
