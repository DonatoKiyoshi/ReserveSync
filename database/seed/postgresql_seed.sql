-- ============================================================================
-- ReserveSync — Datos Iniciales y de Prueba Comunes (PostgreSQL)
-- Base de Datos Central del Servidor Backend Spring Boot
-- Contexto: Restaurante en México (Zona Horaria: America/Mexico_City, UTC-6)
-- Convención: Los timestamps se almacenan en UTC con tipo TIMESTAMPTZ.
-- Idempotencia: Todas las inserciones utilizan ON CONFLICT DO NOTHING.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Roles
-- ----------------------------------------------------------------------------
INSERT INTO roles (id, nombre, descripcion, created_at) VALUES
('00000000-0000-0000-0000-000000000001', 'ADMIN', 'Administrador general con acceso total a configuraciones y reportes', '2026-11-11T14:00:00Z'),
('00000000-0000-0000-0000-000000000002', 'RECEPCIONISTA', 'Personal de sala y recepción encargado de la gestión de mesas y reservas', '2026-11-11T14:00:00Z'),
('00000000-0000-0000-0000-000000000003', 'MESERO', 'Personal de atención en salón con vista operativa de asignación', '2026-11-11T14:00:00Z')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 2. Usuarios
-- Hashes BCrypt reales verificados mediante biblioteca de hashing (cost 10):
-- admin@reservesync.mx        (Admin1234!)     -> $2b$10$qUN/zA6Z7TDUv75lbnkmY.zqWrZ56NEeNgOmEX8E35.LXX/m.F/OW
-- recepcion@reservesync.mx    (Recepcion1234!) -> $2b$10$3M15RzmPPtNAXJtD9EItu.WtY92F.p92nJkq7MYavIk0e6RS0v7XG
-- jorge.mesero@reservesync.mx (Mesero1234!)    -> $2b$10$wVozfNv4XqL8nh3w0Yt5tuclWFPBptlSwlsOT0R.svHbZVri4urYW
-- ----------------------------------------------------------------------------
INSERT INTO usuarios (id, rol_id, nombre, email, password_hash, activo, created_at, updated_at, version) VALUES
('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Carlos Mendoza Navarrete', 'admin@reservesync.mx', '$2b$10$qUN/zA6Z7TDUv75lbnkmY.zqWrZ56NEeNgOmEX8E35.LXX/m.F/OW', TRUE, '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'Laura García Morales', 'recepcion@reservesync.mx', '$2b$10$3M15RzmPPtNAXJtD9EItu.WtY92F.p92nJkq7MYavIk0e6RS0v7XG', TRUE, '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000003', 'Jorge Valenzuela Iturbe', 'jorge.mesero@reservesync.mx', '$2b$10$wVozfNv4XqL8nh3w0Yt5tuclWFPBptlSwlsOT0R.svHbZVri4urYW', TRUE, '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1)
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 3. Mesas
-- Sala Principal (M-01 a M-06), Terraza (T-01 a T-04), Bar (B-01 y B-02)
-- ----------------------------------------------------------------------------
INSERT INTO mesas (id, numero_mesa, zona, capacidad_minima, capacidad_maxima, estado_operativo, created_at, updated_at, version) VALUES
-- Sala Principal
('20000000-0000-0000-0000-000000000001', 'M-01', 'SALA_PRINCIPAL', 1, 2, 'ACTIVA', '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
('20000000-0000-0000-0000-000000000002', 'M-02', 'SALA_PRINCIPAL', 2, 4, 'ACTIVA', '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
('20000000-0000-0000-0000-000000000003', 'M-03', 'SALA_PRINCIPAL', 2, 4, 'ACTIVA', '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
('20000000-0000-0000-0000-000000000004', 'M-04', 'SALA_PRINCIPAL', 2, 4, 'ACTIVA', '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
('20000000-0000-0000-0000-000000000005', 'M-05', 'SALA_PRINCIPAL', 4, 6, 'ACTIVA', '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
('20000000-0000-0000-0000-000000000006', 'M-06', 'SALA_PRINCIPAL', 6, 8, 'ACTIVA', '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
-- Terraza
('20000000-0000-0000-0000-000000000007', 'T-01', 'TERRAZA', 2, 4, 'ACTIVA', '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
('20000000-0000-0000-0000-000000000008', 'T-02', 'TERRAZA', 2, 4, 'ACTIVA', '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
('20000000-0000-0000-0000-000000000009', 'T-03', 'TERRAZA', 4, 6, 'ACTIVA', '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
('20000000-0000-0000-0000-000000000010', 'T-04', 'TERRAZA', 6, 8, 'ACTIVA', '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
-- Bar
('20000000-0000-0000-0000-000000000011', 'B-01', 'BAR', 1, 2, 'ACTIVA', '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
('20000000-0000-0000-0000-000000000012', 'B-02', 'BAR', 1, 2, 'ACTIVA', '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1)
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 4. Horarios de Operación (Hora Local México CDMX)
-- Turno Comida (13:00 - 17:30) y Turno Cena (19:30 - 23:30)
-- ----------------------------------------------------------------------------
INSERT INTO horarios (id, dia_semana, turno, hora_apertura, hora_cierre, intervalo_reserva_min, duracion_estandar_min, activo, created_at, updated_at, version) VALUES
-- Lunes a Domingo: Comida
('30000000-0000-0000-0000-000000000001', 1, 'COMIDA', '13:00:00', '17:30:00', 30, 90, TRUE, '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
('30000000-0000-0000-0000-000000000002', 2, 'COMIDA', '13:00:00', '17:30:00', 30, 90, TRUE, '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
('30000000-0000-0000-0000-000000000003', 3, 'COMIDA', '13:00:00', '17:30:00', 30, 90, TRUE, '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
('30000000-0000-0000-0000-000000000004', 4, 'COMIDA', '13:00:00', '17:30:00', 30, 90, TRUE, '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
('30000000-0000-0000-0000-000000000005', 5, 'COMIDA', '13:00:00', '17:30:00', 30, 90, TRUE, '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
('30000000-0000-0000-0000-000000000006', 6, 'COMIDA', '13:00:00', '17:30:00', 30, 90, TRUE, '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
('30000000-0000-0000-0000-000000000007', 7, 'COMIDA', '13:00:00', '17:30:00', 30, 90, TRUE, '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
-- Lunes a Domingo: Cena
('30000000-0000-0000-0000-000000000008', 1, 'CENA', '19:30:00', '23:30:00', 30, 90, TRUE, '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
('30000000-0000-0000-0000-000000000009', 2, 'CENA', '19:30:00', '23:30:00', 30, 90, TRUE, '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
('30000000-0000-0000-0000-000000000010', 3, 'CENA', '19:30:00', '23:30:00', 30, 90, TRUE, '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
('30000000-0000-0000-0000-000000000011', 4, 'CENA', '19:30:00', '23:30:00', 30, 90, TRUE, '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
('30000000-0000-0000-0000-000000000012', 5, 'CENA', '19:30:00', '23:30:00', 30, 90, TRUE, '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
('30000000-0000-0000-0000-000000000013', 6, 'CENA', '19:30:00', '23:30:00', 30, 90, TRUE, '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
('30000000-0000-0000-0000-000000000014', 7, 'CENA', '19:30:00', '23:30:00', 30, 90, TRUE, '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1)
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 5. Cierres Programados (Intervalos Absolutos UTC Normalizados)
-- Cierre 1: Feriado Nacional de Año Nuevo (Día completo 2027-01-01 CDMX -> 2027-01-01T06:00:00Z a 2027-01-02T06:00:00Z)
-- Cierre 2: Mantenimiento domo Terraza (Día completo 2026-11-20 CDMX -> 2026-11-20T06:00:00Z a 2026-11-21T06:00:00Z)
-- Cierre 3: Cierre parcial mesa B-02 (2026-11-18 14:00-18:00 CDMX -> 2026-11-18T20:00:00Z a 2026-11-19T00:00:00Z)
-- ----------------------------------------------------------------------------
INSERT INTO cierres (id, fecha_hora_inicio, fecha_hora_fin, tipo_cierre, zona, mesa_id, motivo, created_at, updated_at, version) VALUES
('40000000-0000-0000-0000-000000000001', '2027-01-01T06:00:00Z', '2027-01-02T06:00:00Z', 'TOTAL_RESTAURANTE', NULL, NULL, 'Feriado Nacional de Año Nuevo', '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
('40000000-0000-0000-0000-000000000002', '2026-11-20T06:00:00Z', '2026-11-21T06:00:00Z', 'ZONA', 'TERRAZA', NULL, 'Mantenimiento del domo y toldo de terraza', '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
('40000000-0000-0000-0000-000000000003', '2026-11-18T20:00:00Z', '2026-11-19T00:00:00Z', 'MESA_ESPECIFICA', NULL, '20000000-0000-0000-0000-000000000012', 'Mantenimiento preventivo de barra y cableado en mesa B-02', '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1)
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 6. Configuración General
-- ----------------------------------------------------------------------------
INSERT INTO configuracion (clave, valor, tipo_dato, descripcion, updated_at, version) VALUES
('RESTAURANTE_NOMBRE', 'Restaurante y Cantina La Tradición', 'STRING', 'Nombre comercial del establecimiento en México', '2026-11-11T14:00:00Z', 1),
('ZONA_HORARIA_SISTEMA', 'America/Mexico_City', 'STRING', 'Zona horaria oficial del restaurante (UTC-6 estándar)', '2026-11-11T14:00:00Z', 1),
('RESERVA_ANTICIPACION_DIAS_MAX', '30', 'INTEGER', 'Máximo de días hacia el futuro para reservar', '2026-11-11T14:00:00Z', 1),
('TOLERANCIA_NO_SHOW_MIN', '15', 'INTEGER', 'Minutos de espera antes de marcar la reserva como no-asistió', '2026-11-11T14:00:00Z', 1),
('DURACION_RESERVA_DEFECTO_MIN', '90', 'INTEGER', 'Tiempo promedio de servicio asignado por reserva', '2026-11-11T14:00:00Z', 1),
('CANCELACION_ANTICIPACION_HORAS', '2', 'INTEGER', 'Horas mínimas previas requeridas para cancelación en línea', '2026-11-11T14:00:00Z', 1)
ON CONFLICT (clave) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 7. Clientes (Ficticios de México)
-- ----------------------------------------------------------------------------
INSERT INTO clientes (id, nombre, telefono, email, notas_preferencias, created_at, updated_at, version) VALUES
('50000000-0000-0000-0000-000000000001', 'Alejandro Navarro Ríos', '+525511223344', 'anavarro@gmail.com', 'Alérgico al marisco. Prefiere mesa tranquila junto a la ventana.', '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
('50000000-0000-0000-0000-000000000002', 'Sofía Morales Cárdenas', '+525522334455', 'sofia.morales@outlook.com', 'Cliente habitual de fines de semana. Gusta de la terraza.', '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
('50000000-0000-0000-0000-000000000003', 'Roberto Gómez Zavala', '+528133445566', 'rgomez@empresa.com.mx', 'Almuerzos de negocios. Requiere factura y discreción.', '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1),
('50000000-0000-0000-0000-000000000004', 'María Fernández Ochoa', '+523344556677', 'maria.fdez@gmail.com', 'Celebración familiar de cumpleaños. Requiere silla infantil.', '2026-11-11T14:00:00Z', '2026-11-11T14:00:00Z', 1)
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 8. Reservaciones Comunes Confirmadas y Sincronizadas
-- R1: Confirmada en Sala Principal (M-01) para 2 personas (14:00 CDMX = 20:00 UTC)
-- R2: Confirmada combinando 2 mesas (M-03 y M-04) para 8 personas (14:30 CDMX = 20:30 UTC)
-- R3: Web Pública en Terraza (T-01) para 3 personas (20:00 CDMX = 02:00 UTC del 16/11)
-- NOTA: R4 se gestiona de forma aislada en sqlite_offline_seed.sql
-- ----------------------------------------------------------------------------
INSERT INTO reservaciones (
    id, codigo_reserva, cliente_id, usuario_creador_id, canal_origen,
    fecha_reserva, fecha_hora_inicio, fecha_hora_fin, cantidad_personas,
    notas_cliente, notas_internas, estado_reserva, estado_sync, created_at, updated_at, version
) VALUES
('60000000-0000-0000-0000-000000000001', 'RS-202611-A01', '50000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', 'TELEFONO',
 '2026-11-15', '2026-11-15T20:00:00Z', '2026-11-15T21:30:00Z', 2,
 'Aniversario de bodas', 'Preparar copa de cortesía', 'CONFIRMADA', 'SYNCED', '2026-11-11T14:30:00Z', '2026-11-11T14:30:00Z', 1),

('60000000-0000-0000-0000-000000000002', 'RS-202611-B02', '50000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000001', 'DESKTOP_LOCAL',
 '2026-11-15', '2026-11-15T20:30:00Z', '2026-11-15T22:30:00Z', 8,
 'Cumpleaños, traerán pastel propio', 'Unir mesas M-03 y M-04 en el centro', 'CONFIRMADA', 'SYNCED', '2026-11-11T14:45:00Z', '2026-11-11T14:45:00Z', 1),

('60000000-0000-0000-0000-000000000003', 'RS-202611-C03', '50000000-0000-0000-0000-000000000002', NULL, 'WEB_PUBLICA',
 '2026-11-15', '2026-11-16T02:00:00Z', '2026-11-16T03:30:00Z', 3,
 'Mesa en terraza con calentador exterior', 'Verificar encendido de calentador', 'CONFIRMADA', 'SYNCED', '2026-11-11T15:00:00Z', '2026-11-11T15:00:00Z', 1)
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 9. Detalle de Reservaciones (Asignación de Mesas)
-- ----------------------------------------------------------------------------
INSERT INTO detalle_reservacion (id, reservacion_id, mesa_id, created_at, version) VALUES
-- R1 asignada a M-01
('70000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', '2026-11-11T14:30:00Z', 1),
-- R2 asignada a M-03 y M-04 (mesas unidas para 8 personas)
('70000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000003', '2026-11-11T14:45:00Z', 1),
('70000000-0000-0000-0000-000000000003', '60000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000004', '2026-11-11T14:45:00Z', 1),
-- R3 asignada a T-01
('70000000-0000-0000-0000-000000000004', '60000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000007', '2026-11-11T15:00:00Z', 1)
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 10. Historial de Reservaciones (Auditoría)
-- ----------------------------------------------------------------------------
INSERT INTO historial_reservaciones (id, reservacion_id, usuario_id, accion, estado_anterior, estado_nuevo, motivo, fecha_evento) VALUES
('80000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', 'CREACION', NULL, 'CONFIRMADA', 'Reserva telefónica capturada por recepción', '2026-11-11T14:30:00Z'),
('80000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'CREACION', NULL, 'CONFIRMADA', 'Reserva grupal registrada por gerencia', '2026-11-11T14:45:00Z'),
('80000000-0000-0000-0000-000000000003', '60000000-0000-0000-0000-000000000003', NULL, 'CREACION', NULL, 'CONFIRMADA', 'Reserva realizada exitosamente desde la web pública', '2026-11-11T15:00:00Z')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 11. Códigos de Acceso (Autogestión Web)
-- Token plano: '7X9K2P'
-- Hash SHA-256 verificado: 1d609e534225c334ddf8ad4f9f1abe6274dfd8792958e2c8cf97267d9098deef
-- ----------------------------------------------------------------------------
INSERT INTO codigos_acceso (id, reservacion_id, token_hash, expiracion, utilizado, intentos_fallidos, created_at) VALUES
('90000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000003', '1d609e534225c334ddf8ad4f9f1abe6274dfd8792958e2c8cf97267d9098deef', '2026-11-16T06:00:00Z', FALSE, 0, '2026-11-11T15:00:00Z')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 12. Notificaciones
-- ----------------------------------------------------------------------------
INSERT INTO notificaciones (id, reservacion_id, canal, destinatario, tipo, contenido, estado_envio, fecha_programada, fecha_envio, created_at, version) VALUES
('a0000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001', 'EMAIL', 'anavarro@gmail.com', 'CONFIRMACION_RESERVA', 'Su reserva para 2 comensales el 15/11 a las 14:00 (CDMX) ha sido confirmada.', 'ENVIADO', '2026-11-11T14:30:00Z', '2026-11-11T14:30:05Z', '2026-11-11T14:30:00Z', 1),
('a0000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000003', 'EMAIL', 'sofia.morales@outlook.com', 'CONFIRMACION_RESERVA', 'Su reserva para 3 comensales en Terraza ha sido confirmada. Código de gestión: RS-202611-C03 (PIN: 7X9K2P)', 'ENVIADO', '2026-11-11T15:00:00Z', '2026-11-11T15:00:04Z', '2026-11-11T15:00:00Z', 1),
('a0000000-0000-0000-0000-000000000003', '60000000-0000-0000-0000-000000000002', 'EMAIL', 'maria.fdez@gmail.com', 'RECORDATORIO_ASISTENCIA', 'Le recordamos su reserva para 8 comensales hoy a las 14:30 (CDMX).', 'PENDIENTE', '2026-11-15T18:30:00Z', NULL, '2026-11-11T14:45:00Z', 1)
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 13. Sincronización: sync_cursor (Punteros centrales: PULL y PUSH para estación local)
-- ----------------------------------------------------------------------------
INSERT INTO sync_cursor (id, terminal_id, direccion, last_sync_timestamp, last_sync_id, last_sync_sequence, updated_at) VALUES
('e0000000-0000-0000-0000-000000000001', 'TERMINAL_CAJA_01', 'PULL', '2026-11-11T14:00:00Z', NULL, 0, '2026-11-11T14:00:00Z'),
('e0000000-0000-0000-0000-000000000002', 'TERMINAL_CAJA_01', 'PUSH', '2026-11-11T14:00:00Z', NULL, 0, '2026-11-11T14:00:00Z')
ON CONFLICT (id) DO NOTHING;

COMMIT;
