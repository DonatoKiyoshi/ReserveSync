-- ============================================================================
-- ReserveSync — Datos Semilla Exclusivos de Modo Offline (SQLite)
-- Escenario: Reservación R4 generada localmente en la terminal de escritorio
-- mientras se encuentra sin conexión al servidor central.
-- Esta reservación NO debe existir en PostgreSQL hasta que se sincronice.
-- Convención: Timestamps en UTC normalizado fijo 'YYYY-MM-DDTHH:MM:SS.SSSZ'.
-- Idempotencia: Todas las inserciones utilizan ON CONFLICT DO NOTHING.
-- ============================================================================

PRAGMA foreign_keys = ON;

BEGIN TRANSACTION;

-- ----------------------------------------------------------------------------
-- 1. Reservación R4 (Creada sin conexión)
-- R4: Pendiente en Bar (B-01) para 2 personas (20:30 CDMX = 02:30 UTC del 16/11)
-- ----------------------------------------------------------------------------
INSERT INTO reservaciones (
    id, codigo_reserva, cliente_id, usuario_creador_id, canal_origen,
    fecha_reserva, fecha_hora_inicio, fecha_hora_fin, cantidad_personas,
    notas_cliente, notas_internas, estado_reserva, estado_sync, created_at, updated_at, version
) VALUES
('60000000-0000-0000-0000-000000000004', 'RS-202611-D04', '50000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000002', 'DESKTOP_LOCAL',
 '2026-11-15', '2026-11-16T02:30:00.000Z', '2026-11-16T04:00:00.000Z', 2,
 'Cena rápida en zona de bar', 'Registrada sin conexión a Internet', 'PENDIENTE', 'PENDIENTE_SYNC', '2026-11-11T15:15:00.000Z', '2026-11-11T15:15:00.000Z', 1)
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 2. Detalle de Asignación de Mesa (B-01)
-- ----------------------------------------------------------------------------
INSERT INTO detalle_reservacion (id, reservacion_id, mesa_id, created_at, version) VALUES
('70000000-0000-0000-0000-000000000005', '60000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000011', '2026-11-11T15:15:00.000Z', 1)
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 3. Historial de Auditoría Local
-- ----------------------------------------------------------------------------
INSERT INTO historial_reservaciones (id, reservacion_id, usuario_id, accion, estado_anterior, estado_nuevo, motivo, fecha_evento) VALUES
('80000000-0000-0000-0000-000000000004', '60000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000002', 'CREACION', NULL, 'PENDIENTE', 'Reserva capturada localmente sin conexión a Internet', '2026-11-11T15:15:00.000Z')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 4. Cola de Salida Local (sync_outbox)
-- Operación pendiente de envío hacia el backend Spring Boot
-- ----------------------------------------------------------------------------
INSERT INTO sync_outbox (
    id, operation_id, terminal_id, entity_name, entity_id, action,
    payload, entity_version, status, retry_count, created_at
) VALUES
('b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'TERMINAL_CAJA_01', 'reservaciones', '60000000-0000-0000-0000-000000000004', 'CREATE',
 '{"id":"60000000-0000-0000-0000-000000000004","codigo_reserva":"RS-202611-D04","cliente_id":"50000000-0000-0000-0000-000000000003","fecha_reserva":"2026-11-15","fecha_hora_inicio":"2026-11-16T02:30:00.000Z","fecha_hora_fin":"2026-11-16T04:00:00.000Z","cantidad_personas":2,"mesas":["20000000-0000-0000-0000-000000000011"]}',
 1, 'PENDIENTE', 0, '2026-11-11T15:15:00.000Z')
ON CONFLICT (id) DO NOTHING;

COMMIT;
