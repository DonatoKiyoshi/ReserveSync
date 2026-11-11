-- ============================================================================
-- ReserveSync — Datos Iniciales y de Prueba (SQLite)
-- Base de Datos Local de la Aplicación de Escritorio
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ----------------------------------------------------------------------------
-- 1. Roles
-- ----------------------------------------------------------------------------
INSERT INTO roles (id, nombre, descripcion, created_at) VALUES
('00000000-0000-0000-0000-000000000001', 'ADMIN', 'Administrador general con acceso total a configuraciones y reportes', '2026-11-11T08:00:00Z'),
('00000000-0000-0000-0000-000000000002', 'RECEPCIONISTA', 'Personal de sala y recepción encargado de la gestión de mesas y reservas', '2026-11-11T08:00:00Z'),
('00000000-0000-0000-0000-000000000003', 'MESERO', 'Personal de atención en salón con vista operativa de asignación', '2026-11-11T08:00:00Z');

-- ----------------------------------------------------------------------------
-- 2. Usuarios
-- Contraseñas de prueba encriptadas con BCrypt:
-- admin@reservesync.local        -> Admin1234!
-- recepcion@reservesync.local    -> Recepcion1234!
-- jorge.mesero@reservesync.local -> Mesero1234!
-- ----------------------------------------------------------------------------
INSERT INTO usuarios (id, rol_id, nombre, email, password_hash, activo, created_at, updated_at, version) VALUES
('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Carlos Mendoza', 'admin@reservesync.local', '$2a$12$e8yM2dJ3E4K5L6M7N8O9P.q1w2e3r4t5y6u7i8o9p0a1s2d3f4g5h', 1, '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'Laura García', 'recepcion@reservesync.local', '$2a$12$f9zN3eK4F5L6M7N8O9P0Q.r2w3e4r5t6y7u8i9o0p1a2s3d4f5g6h', 1, '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000003', 'Jorge Valenzuela', 'jorge.mesero@reservesync.local', '$2a$12$g0aO4fL5G6M7N8O9P0Q1R.s3w4e5r6t7y8u9i0p1a2s3d4f5g6h7i', 1, '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1);

-- ----------------------------------------------------------------------------
-- 3. Mesas
-- Sala Principal (M-01 a M-06), Terraza (T-01 a T-04), Bar (B-01 y B-02)
-- ----------------------------------------------------------------------------
INSERT INTO mesas (id, numero_mesa, zona, capacidad_minima, capacidad_maxima, estado_operativo, created_at, updated_at, version) VALUES
-- Sala Principal
('20000000-0000-0000-0000-000000000001', 'M-01', 'SALA_PRINCIPAL', 1, 2, 'ACTIVA', '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
('20000000-0000-0000-0000-000000000002', 'M-02', 'SALA_PRINCIPAL', 2, 4, 'ACTIVA', '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
('20000000-0000-0000-0000-000000000003', 'M-03', 'SALA_PRINCIPAL', 2, 4, 'ACTIVA', '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
('20000000-0000-0000-0000-000000000004', 'M-04', 'SALA_PRINCIPAL', 2, 4, 'ACTIVA', '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
('20000000-0000-0000-0000-000000000005', 'M-05', 'SALA_PRINCIPAL', 4, 6, 'ACTIVA', '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
('20000000-0000-0000-0000-000000000006', 'M-06', 'SALA_PRINCIPAL', 6, 8, 'ACTIVA', '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
-- Terraza
('20000000-0000-0000-0000-000000000007', 'T-01', 'TERRAZA', 2, 4, 'ACTIVA', '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
('20000000-0000-0000-0000-000000000008', 'T-02', 'TERRAZA', 2, 4, 'ACTIVA', '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
('20000000-0000-0000-0000-000000000009', 'T-03', 'TERRAZA', 4, 6, 'ACTIVA', '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
('20000000-0000-0000-0000-000000000010', 'T-04', 'TERRAZA', 6, 8, 'ACTIVA', '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
-- Bar
('20000000-0000-0000-0000-000000000011', 'B-01', 'BAR', 1, 2, 'ACTIVA', '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
('20000000-0000-0000-0000-000000000012', 'B-02', 'BAR', 1, 2, 'ACTIVA', '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1);

-- ----------------------------------------------------------------------------
-- 4. Horarios de Operación
-- Turno Almuerzo (13:00 - 17:00) y Turno Cena (20:00 - 23:30) para toda la semana
-- ----------------------------------------------------------------------------
INSERT INTO horarios (id, dia_semana, turno, hora_apertura, hora_cierre, intervalo_reserva_min, duracion_estandar_min, activo, created_at, updated_at, version) VALUES
-- Lunes a Domingo: Almuerzo
('30000000-0000-0000-0000-000000000001', 1, 'ALMUERZO', '13:00:00', '17:00:00', 30, 90, 1, '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
('30000000-0000-0000-0000-000000000002', 2, 'ALMUERZO', '13:00:00', '17:00:00', 30, 90, 1, '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
('30000000-0000-0000-0000-000000000003', 3, 'ALMUERZO', '13:00:00', '17:00:00', 30, 90, 1, '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
('30000000-0000-0000-0000-000000000004', 4, 'ALMUERZO', '13:00:00', '17:00:00', 30, 90, 1, '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
('30000000-0000-0000-0000-000000000005', 5, 'ALMUERZO', '13:00:00', '17:00:00', 30, 90, 1, '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
('30000000-0000-0000-0000-000000000006', 6, 'ALMUERZO', '13:00:00', '17:00:00', 30, 90, 1, '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
('30000000-0000-0000-0000-000000000007', 7, 'ALMUERZO', '13:00:00', '17:00:00', 30, 90, 1, '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
-- Lunes a Domingo: Cena
('30000000-0000-0000-0000-000000000008', 1, 'CENA', '20:00:00', '23:30:00', 30, 90, 1, '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
('30000000-0000-0000-0000-000000000009', 2, 'CENA', '20:00:00', '23:30:00', 30, 90, 1, '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
('30000000-0000-0000-0000-000000000010', 3, 'CENA', '20:00:00', '23:30:00', 30, 90, 1, '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
('30000000-0000-0000-0000-000000000011', 4, 'CENA', '20:00:00', '23:30:00', 30, 90, 1, '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
('30000000-0000-0000-0000-000000000012', 5, 'CENA', '20:00:00', '23:30:00', 30, 90, 1, '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
('30000000-0000-0000-0000-000000000013', 6, 'CENA', '20:00:00', '23:30:00', 30, 90, 1, '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
('30000000-0000-0000-0000-000000000014', 7, 'CENA', '20:00:00', '23:30:00', 30, 90, 1, '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1);

-- ----------------------------------------------------------------------------
-- 5. Cierres Programados y Mantenimientos
-- ----------------------------------------------------------------------------
INSERT INTO cierres (id, fecha_inicio, fecha_fin, hora_inicio, hora_fin, tipo_cierre, zona, mesa_id, motivo, created_at, updated_at, version) VALUES
('40000000-0000-0000-0000-000000000001', '2027-01-01', '2027-01-01', NULL, NULL, 'TOTAL_RESTAURANTE', NULL, NULL, 'Festivo Nacional de Año Nuevo', '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
('40000000-0000-0000-0000-000000000002', '2026-11-20', '2026-11-20', '08:00:00', '18:00:00', 'ZONA', 'TERRAZA', NULL, 'Mantenimiento preventivo e impermeabilización del toldo', '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1);

-- ----------------------------------------------------------------------------
-- 6. Configuración General
-- ----------------------------------------------------------------------------
INSERT INTO configuracion (clave, valor, tipo_dato, descripcion, updated_at, version) VALUES
('RESTAURANTE_NOMBRE', 'Mesón Tradicional ReserveSync', 'STRING', 'Nombre comercial del establecimiento', '2026-11-11T08:00:00Z', 1),
('RESERVA_ANTICIPACION_DIAS_MAX', '30', 'INTEGER', 'Máximo de días hacia el futuro para reservar', '2026-11-11T08:00:00Z', 1),
('TOLERANCIA_NO_SHOW_MIN', '15', 'INTEGER', 'Minutos de espera antes de marcar la reserva como no-asistió', '2026-11-11T08:00:00Z', 1),
('DURACION_RESERVA_DEFECTO_MIN', '90', 'INTEGER', 'Tiempo promedio de servicio asignado por reserva', '2026-11-11T08:00:00Z', 1),
('CANCELACION_ANTICIPACION_HORAS', '2', 'INTEGER', 'Horas mínimas previas requeridas para cancelación en línea', '2026-11-11T08:00:00Z', 1),
('NOTIFICACIONES_EMAIL_HABILITADAS', 'true', 'BOOLEAN', 'Indicador de envío automático de correos a clientes', '2026-11-11T08:00:00Z', 1);

-- ----------------------------------------------------------------------------
-- 7. Clientes
-- ----------------------------------------------------------------------------
INSERT INTO clientes (id, nombre, telefono, email, notas_preferencias, created_at, updated_at, version) VALUES
('50000000-0000-0000-0000-000000000001', 'Alejandro Navarro', '+34600112233', 'anavarro@gmail.com', 'Alérgico al marisco. Prefiere mesa tranquila junto a la ventana.', '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
('50000000-0000-0000-0000-000000000002', 'Sofía Morales', '+34611223344', 'sofia.morales@outlook.com', 'Cliente habitual de fines de semana. Gusta de la terraza.', '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
('50000000-0000-0000-0000-000000000003', 'Roberto Gómez', '+34622334455', 'rgomez@empresa.es', 'Almuerzos de negocios. Requiere factura y discreción.', '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1),
('50000000-0000-0000-0000-000000000004', 'María Fernández', '+34633445566', 'maria.fdez@gmail.com', 'Celebración familiar de cumpleaños. Requiere silla infantil.', '2026-11-11T08:00:00Z', '2026-11-11T08:00:00Z', 1);

-- ----------------------------------------------------------------------------
-- 8. Reservaciones
-- R1: Confirmada en Sala Principal (M-01) para 2 comensales
-- R2: Confirmada en Sala Principal combinando 2 mesas (M-03 y M-04) para 8 comensales
-- R3: Creada desde la Web Pública en Terraza (T-01) para 3 comensales
-- R4: Creada en escritorio Offline en Bar (B-01) con estado PENDIENTE_SYNC
-- ----------------------------------------------------------------------------
INSERT INTO reservaciones (
    id, codigo_reserva, cliente_id, usuario_creador_id, canal_origen,
    fecha_reserva, fecha_hora_inicio, fecha_hora_fin, cantidad_personas,
    notas_cliente, notas_internas, estado_reserva, estado_sync, created_at, updated_at, version
) VALUES
('60000000-0000-0000-0000-000000000001', 'RS-202611-A01', '50000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', 'TELEFONO',
 '2026-11-15', '2026-11-15T14:00:00Z', '2026-11-15T15:30:00Z', 2,
 'Aniversario de bodas', 'Preparar copa de cortesía', 'CONFIRMADA', 'SYNCED', '2026-11-11T08:30:00Z', '2026-11-11T08:30:00Z', 1),

('60000000-0000-0000-0000-000000000002', 'RS-202611-B02', '50000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000001', 'DESKTOP_LOCAL',
 '2026-11-15', '2026-11-15T14:30:00Z', '2026-11-15T16:30:00Z', 8,
 'Cumpleaños, traerán tarta propia', 'Unir mesas M-03 y M-04 en el centro', 'CONFIRMADA', 'SYNCED', '2026-11-11T08:45:00Z', '2026-11-11T08:45:00Z', 1),

('60000000-0000-0000-0000-000000000003', 'RS-202611-C03', '50000000-0000-0000-0000-000000000002', NULL, 'WEB_PUBLICA',
 '2026-11-15', '2026-11-15T21:00:00Z', '2026-11-15T22:30:00Z', 3,
 'Mesa en terraza si el clima lo permite', 'Comprobar estufa exterior', 'CONFIRMADA', 'SYNCED', '2026-11-11T09:00:00Z', '2026-11-11T09:00:00Z', 1),

('60000000-0000-0000-0000-000000000004', 'RS-202611-D04', '50000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000002', 'DESKTOP_LOCAL',
 '2026-11-15', '2026-11-15T21:30:00Z', '2026-11-15T23:00:00Z', 2,
 'Picoteo rápido en zona bar', 'Registrada sin conexión a Internet', 'PENDIENTE', 'PENDIENTE_SYNC', '2026-11-11T09:15:00Z', '2026-11-11T09:15:00Z', 1);

-- ----------------------------------------------------------------------------
-- 9. Detalle de Reservaciones (Asignación de Mesas)
-- ----------------------------------------------------------------------------
INSERT INTO detalle_reservacion (id, reservacion_id, mesa_id, created_at, version) VALUES
-- R1 asignada a M-01
('70000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', '2026-11-11T08:30:00Z', 1),
-- R2 asignada a M-03 y M-04 (mesas unidas para 8 personas)
('70000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000003', '2026-11-11T08:45:00Z', 1),
('70000000-0000-0000-0000-000000000003', '60000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000004', '2026-11-11T08:45:00Z', 1),
-- R3 asignada a T-01
('70000000-0000-0000-0000-000000000004', '60000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000007', '2026-11-11T09:00:00Z', 1),
-- R4 asignada a B-01 (pendiente de confirmación)
('70000000-0000-0000-0000-000000000005', '60000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000011', '2026-11-11T09:15:00Z', 1);

-- ----------------------------------------------------------------------------
-- 10. Historial de Reservaciones (Auditoría)
-- ----------------------------------------------------------------------------
INSERT INTO historial_reservaciones (id, reservacion_id, usuario_id, accion, estado_anterior, estado_nuevo, motivo, fecha_evento) VALUES
('80000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', 'CREACION', NULL, 'CONFIRMADA', 'Reserva telefónica capturada por recepción', '2026-11-11T08:30:00Z'),
('80000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'CREACION', NULL, 'CONFIRMADA', 'Reserva grupal registrada por gerencia', '2026-11-11T08:45:00Z'),
('80000000-0000-0000-0000-000000000003', '60000000-0000-0000-0000-000000000003', NULL, 'CREACION', NULL, 'CONFIRMADA', 'Reserva realizada exitosamente desde la web pública', '2026-11-11T09:00:00Z'),
('80000000-0000-0000-0000-000000000004', '60000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000002', 'CREACION', NULL, 'PENDIENTE', 'Reserva capturada localmente sin conexión a Internet', '2026-11-11T09:15:00Z');

-- ----------------------------------------------------------------------------
-- 11. Códigos de Acceso (Autogestión Web)
-- Token de 6 caracteres con hash SHA-256 para consulta sin usuario
-- ----------------------------------------------------------------------------
INSERT INTO codigos_acceso (id, reservacion_id, token_hash, expiracion, utilizado, intentos_fallidos, created_at) VALUES
('90000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000003', 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', '2026-11-15T23:59:59Z', 0, 0, '2026-11-11T09:00:00Z');

-- ----------------------------------------------------------------------------
-- 12. Notificaciones
-- ----------------------------------------------------------------------------
INSERT INTO notificaciones (id, reservacion_id, canal, destinatario, tipo, contenido, estado_envio, fecha_programada, fecha_envio, created_at, version) VALUES
('a0000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001', 'EMAIL', 'anavarro@gmail.com', 'CONFIRMACION_RESERVA', 'Su reserva para 2 comensales el 15/11 a las 14:00 ha sido confirmada.', 'ENVIADO', '2026-11-11T08:30:00Z', '2026-11-11T08:30:05Z', '2026-11-11T08:30:00Z', 1),
('a0000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000003', 'EMAIL', 'sofia.morales@outlook.com', 'CONFIRMACION_RESERVA', 'Su reserva para 3 comensales en Terraza ha sido confirmada. Código de gestión: RS-202611-C03', 'ENVIADO', '2026-11-11T09:00:00Z', '2026-11-11T09:00:04Z', '2026-11-11T09:00:00Z', 1),
('a0000000-0000-0000-0000-000000000003', '60000000-0000-0000-0000-000000000002', 'EMAIL', 'maria.fdez@gmail.com', 'RECORDATORIO_ASISTENCIA', 'Le recordamos su reserva para 8 comensales hoy a las 14:30.', 'PENDIENTE', '2026-11-15T12:30:00Z', NULL, '2026-11-11T08:45:00Z', 1);

-- ----------------------------------------------------------------------------
-- 13. Sincronización: sync_outbox (Operación pendiente generada en modo offline)
-- Representa la creación de la reserva R4 guardada localmente
-- ----------------------------------------------------------------------------
INSERT INTO sync_outbox (
    id, operation_id, terminal_id, entity_name, entity_id, action,
    payload, entity_version, status, retry_count, created_at
) VALUES
('b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'DESKTOP_TERMINAL_01', 'reservaciones', '60000000-0000-0000-0000-000000000004', 'CREATE',
 '{"id":"60000000-0000-0000-0000-000000000004","codigo_reserva":"RS-202611-D04","cliente_id":"50000000-0000-0000-0000-000000000003","fecha_reserva":"2026-11-15","fecha_hora_inicio":"2026-11-15T21:30:00Z","fecha_hora_fin":"2026-11-15T23:00:00Z","cantidad_personas":2,"mesas":["20000000-0000-0000-0000-000000000011"]}',
 1, 'PENDIENTE', 0, '2026-11-11T09:15:00Z');

-- ----------------------------------------------------------------------------
-- 14. Sincronización: sync_cursor (Puntero de la estación local)
-- ----------------------------------------------------------------------------
INSERT INTO sync_cursor (id, terminal_id, last_sync_timestamp, updated_at) VALUES
('DESKTOP_MAIN_SYNC', 'DESKTOP_TERMINAL_01', '2026-11-11T09:00:00Z', '2026-11-11T09:00:00Z');
