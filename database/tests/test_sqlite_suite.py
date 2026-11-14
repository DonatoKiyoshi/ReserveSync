#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Batería de Pruebas Automatizadas de Integridad Transaccional, Reglas de Negocio
y Normalización de Timestamps UTC.
Motor: SQLite 3
ReserveSync — Sistema de Reservaciones Offline-First
"""

import sqlite3
import os
import sys

DB_PATH = "reservesync_test_suite.db"

if os.path.exists(DB_PATH):
    os.remove(DB_PATH)

conn = sqlite3.connect(DB_PATH)
conn.isolation_level = None  # Autocommit para control explícito de transacciones
cursor = conn.cursor()

def run_script(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        script = f.read()
    cursor.executescript(script)

print("=" * 75)
print("RESERVESYNC — BATERIA DE 14 PRUEBAS OBLIGATORIAS EN SQLITE")
print("=" * 75)

try:
    # PRUEBA 1: Crear el esquema
    print("\n[PRUEBA 1] Creando el esquema DDL...")
    run_script("database/sqlite/schema.sql")
    print("  -> OK: Tablas, indices y triggers creados exitosamente.")

    # PRUEBA 2: Insertar datos comunes
    print("\n[PRUEBA 2] Insertando datos semilla comunes (sqlite_seed.sql)...")
    run_script("database/seed/sqlite_seed.sql")
    cursor.execute("SELECT count(*) FROM reservaciones;")
    count_r = cursor.fetchone()[0]
    print(f"  -> OK: {count_r} reservaciones comunes registradas (R1, R2, R3).")

    # PRUEBA 3: Insertar datos exclusivos offline
    print("\n[PRUEBA 3] Insertando datos exclusivos offline (sqlite_offline_seed.sql)...")
    run_script("database/seed/sqlite_offline_seed.sql")
    cursor.execute("SELECT count(*) FROM reservaciones WHERE estado_sync = 'PENDIENTE_SYNC';")
    count_offline = cursor.fetchone()[0]
    cursor.execute("SELECT count(*) FROM sync_outbox WHERE status = 'PENDIENTE';")
    count_outbox = cursor.fetchone()[0]
    print(f"  -> OK: Reservacion offline R4 cargada ({count_offline} pendiente sync, {count_outbox} en cola outbox).")

    # PRUEBA 4: Ejecutar el seed nuevamente (Idempotencia)
    print("\n[PRUEBA 4] Re-ejecutando seeds para comprobar idempotencia contra duplicados...")
    run_script("database/seed/sqlite_seed.sql")
    run_script("database/seed/sqlite_offline_seed.sql")
    print("  -> OK: Scripts re-ejecutados con exito sin errores de clave primaria o unica.")

    # PRUEBA 5: Validar claves foraneas
    print("\n[PRUEBA 5] Verificando integridad referencial (PRAGMA foreign_key_check)...")
    cursor.execute("PRAGMA foreign_key_check;")
    fk_violations = cursor.fetchall()
    if len(fk_violations) == 0:
        print("  -> OK: 0 violaciones referenciales detectadas.")
    else:
        print(f"  -> ERROR: Violaciones FK encontradas: {fk_violations}")
        sys.exit(1)

    # PRUEBA 6: Intentar asignar una mesa eliminada lógicamente
    print("\n[PRUEBA 6] Intentando asignar una mesa eliminada lógicamente...")
    cursor.execute("""
    INSERT INTO mesas (id, numero_mesa, zona, capacidad_minima, capacidad_maxima, estado_operativo, deleted_at)
    VALUES ('20000000-0000-0000-0000-000000000099', 'M-DEL', 'SALA_PRINCIPAL', 2, 4, 'ACTIVA', '2026-11-12T00:00:00.000Z');
    """)
    try:
        cursor.execute("""
        INSERT INTO detalle_reservacion (id, reservacion_id, mesa_id)
        VALUES ('70000000-0000-0000-0000-000000000099', '60000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000099');
        """)
        print("  -> FALLO: Se permitio asignar una mesa con borrado logico.")
        sys.exit(1)
    except sqlite3.IntegrityError as e:
        print(f"  -> OK: Rechazado por trigger ({e}).")

    # PRUEBA 7: Intentar asignar una reservación cancelada
    print("\n[PRUEBA 7] Intentando asignar mesa a una reservación cancelada...")
    cursor.execute("""
    INSERT INTO reservaciones (id, codigo_reserva, cliente_id, canal_origen, fecha_reserva, fecha_hora_inicio, fecha_hora_fin, cantidad_personas, estado_reserva, estado_sync)
    VALUES ('60000000-0000-0000-0000-000000000099', 'RS-TEST-CANC', '50000000-0000-0000-0000-000000000001', 'DESKTOP_LOCAL', '2026-11-17', '2026-11-17T20:00:00.000Z', '2026-11-17T21:30:00.000Z', 2, 'CANCELADA', 'SYNCED');
    """)
    try:
        cursor.execute("""
        INSERT INTO detalle_reservacion (id, reservacion_id, mesa_id)
        VALUES ('70000000-0000-0000-0000-000000000098', '60000000-0000-0000-0000-000000000099', '20000000-0000-0000-0000-000000000001');
        """)
        print("  -> FALLO: Se permitio asignar mesa a una reservacion cancelada.")
        sys.exit(1)
    except sqlite3.IntegrityError as e:
        print(f"  -> OK: Rechazado por trigger ({e}).")

    # PRUEBA 8: Intentar modificar una asignación para producir solapamiento
    print("\n[PRUEBA 8] Intentando modificar una asignación para producir solapamiento de mesas...")
    cursor.execute("""
    INSERT INTO reservaciones (id, codigo_reserva, cliente_id, canal_origen, fecha_reserva, fecha_hora_inicio, fecha_hora_fin, cantidad_personas, estado_reserva, estado_sync)
    VALUES ('60000000-0000-0000-0000-000000000088', 'RS-TEST-SOLAP', '50000000-0000-0000-0000-000000000001', 'DESKTOP_LOCAL', '2026-11-15', '2026-11-15T20:00:00.000Z', '2026-11-15T21:30:00.000Z', 2, 'CONFIRMADA', 'SYNCED');
    """)
    cursor.execute("""
    INSERT INTO detalle_reservacion (id, reservacion_id, mesa_id)
    VALUES ('70000000-0000-0000-0000-000000000088', '60000000-0000-0000-0000-000000000088', '20000000-0000-0000-0000-000000000002');
    """)
    try:
        cursor.execute("""
        UPDATE detalle_reservacion
        SET mesa_id = '20000000-0000-0000-0000-000000000001'
        WHERE id = '70000000-0000-0000-0000-000000000088';
        """)
        print("  -> FALLO: Se permitio provocar solapamiento de horario en mesa M-01.")
        sys.exit(1)
    except sqlite3.IntegrityError as e:
        print(f"  -> OK: Rechazado por trigger ({e}).")

    # PRUEBA 9: Intentar crear un cierre que afecte una reservación existente
    print("\n[PRUEBA 9] Intentando crear un cierre que afecte una reservación activa existente...")
    try:
        cursor.execute("""
        INSERT INTO cierres (id, fecha_hora_inicio, fecha_hora_fin, tipo_cierre, zona, mesa_id, motivo)
        VALUES ('40000000-0000-0000-0000-000000000099', '2026-11-15T19:00:00.000Z', '2026-11-15T23:00:00.000Z', 'TOTAL_RESTAURANTE', NULL, NULL, 'Cierre imprevisto por sanitizacion');
        """)
        print("  -> FALLO: Se permitio registrar un cierre sobre reservaciones activas.")
        sys.exit(1)
    except sqlite3.IntegrityError as e:
        print(f"  -> OK: Rechazado por trigger ({e}).")

    # PRUEBA 10: Intentar asignar una reservación dentro de un cierre parcial cuya hora se haya definido localmente
    print("\n[PRUEBA 10] Intentando asignar una reservación dentro de un cierre parcial (Mesa B-02 con cierre en UTC)...")
    cursor.execute("""
    INSERT INTO reservaciones (id, codigo_reserva, cliente_id, canal_origen, fecha_reserva, fecha_hora_inicio, fecha_hora_fin, cantidad_personas, estado_reserva, estado_sync)
    VALUES ('60000000-0000-0000-0000-000000000077', 'RS-TEST-CIERRE', '50000000-0000-0000-0000-000000000001', 'DESKTOP_LOCAL', '2026-11-18', '2026-11-18T21:00:00.000Z', '2026-11-18T22:30:00.000Z', 2, 'CONFIRMADA', 'SYNCED');
    """)
    try:
        cursor.execute("""
        INSERT INTO detalle_reservacion (id, reservacion_id, mesa_id)
        VALUES ('70000000-0000-0000-0000-000000000077', '60000000-0000-0000-0000-000000000077', '20000000-0000-0000-0000-000000000012');
        """)
        print("  -> FALLO: Se permitio asignar mesa dentro de un cierre parcial en UTC.")
        sys.exit(1)
    except sqlite3.IntegrityError as e:
        print(f"  -> OK: Rechazado por trigger ({e}).")

    # PRUEBA 11: Intentar poner una mesa en mantenimiento cuando tiene reservaciones futuras
    print("\n[PRUEBA 11] Intentando poner una mesa en mantenimiento cuando tiene reservaciones futuras...")
    try:
        cursor.execute("""
        UPDATE mesas
        SET estado_operativo = 'MANTENIMIENTO'
        WHERE id = '20000000-0000-0000-0000-000000000001';
        """)
        print("  -> FALLO: Se permitio desactivar una mesa con reservaciones futuras.")
        sys.exit(1)
    except sqlite3.IntegrityError as e:
        print(f"  -> OK: Rechazado por trigger ({e}).")

    # PRUEBA 12: Reactivación de reservación con mesa en mantenimiento
    print("\n[PRUEBA 12] Intentando reactivar una reservación cuya mesa pasó a mantenimiento...")
    # 1. Crear mesa activa exclusiva para esta prueba
    cursor.execute("""
    INSERT INTO mesas (id, numero_mesa, zona, capacidad_minima, capacidad_maxima, estado_operativo)
    VALUES ('20000000-0000-0000-0000-000000000050', 'M-T12', 'SALA_PRINCIPAL', 2, 4, 'ACTIVA');
    """)
    # 2. Crear reservación y asignarla a la mesa
    cursor.execute("""
    INSERT INTO reservaciones (id, codigo_reserva, cliente_id, canal_origen, fecha_reserva, fecha_hora_inicio, fecha_hora_fin, cantidad_personas, estado_reserva, estado_sync)
    VALUES ('60000000-0000-0000-0000-000000000050', 'RS-TEST-T12', '50000000-0000-0000-0000-000000000001', 'DESKTOP_LOCAL', '2026-11-22', '2026-11-22T20:00:00.000Z', '2026-11-22T21:30:00.000Z', 2, 'CONFIRMADA', 'SYNCED');
    """)
    cursor.execute("""
    INSERT INTO detalle_reservacion (id, reservacion_id, mesa_id)
    VALUES ('70000000-0000-0000-0000-000000000050', '60000000-0000-0000-0000-000000000050', '20000000-0000-0000-0000-000000000050');
    """)
    # 3. Cancelar la reservación
    cursor.execute("UPDATE reservaciones SET estado_reserva = 'CANCELADA' WHERE id = '60000000-0000-0000-0000-000000000050';")
    # 4. Desactivar la mesa (ahora permitido porque la reservación está cancelada)
    cursor.execute("UPDATE mesas SET estado_operativo = 'MANTENIMIENTO' WHERE id = '20000000-0000-0000-0000-000000000050';")
    # 5. Intentar reactivar la reservación (debe fallar)
    try:
        cursor.execute("UPDATE reservaciones SET estado_reserva = 'CONFIRMADA' WHERE id = '60000000-0000-0000-0000-000000000050';")
        print("  -> FALLO: Se permitió reactivar una reservación con mesa en mantenimiento.")
        sys.exit(1)
    except sqlite3.IntegrityError as e:
        print(f"  -> OK: Rechazado por trigger trg_validar_reserva_update ({e}).")

    # PRUEBA 13: Normalización estricta de timestamps (rechazo de offset horario)
    print("\n[PRUEBA 13] Intentando insertar timestamps con desplazamiento horario (-06:00)...")
    try:
        cursor.execute("""
        INSERT INTO reservaciones (id, codigo_reserva, cliente_id, canal_origen, fecha_reserva, fecha_hora_inicio, fecha_hora_fin, cantidad_personas, estado_reserva, estado_sync)
        VALUES ('60000000-0000-0000-0000-000000000060', 'RS-TEST-OFFSET', '50000000-0000-0000-0000-000000000001', 'DESKTOP_LOCAL', '2026-11-23', '2026-11-23T14:00:00-06:00', '2026-11-23T15:30:00-06:00', 2, 'CONFIRMADA', 'SYNCED');
        """)
        print("  -> FALLO: Se permitió insertar timestamp con desplazamiento horario en vez de formato UTC Z.")
        sys.exit(1)
    except sqlite3.IntegrityError as e:
        print(f"  -> OK: Rechazado por restricción CHECK chk_reserva_ts_inicio ({e}).")

    # PRUEBA 14: Restricción estricta de alcance de cierres (MESA_ESPECIFICA con zona y mesa_id)
    print("\n[PRUEBA 14] Intentando registrar cierre MESA_ESPECIFICA especificando zona y mesa simultáneamente...")
    try:
        cursor.execute("""
        INSERT INTO cierres (id, fecha_hora_inicio, fecha_hora_fin, tipo_cierre, zona, mesa_id, motivo)
        VALUES ('40000000-0000-0000-0000-000000000060', '2026-12-01T20:00:00.000Z', '2026-12-01T23:00:00.000Z', 'MESA_ESPECIFICA', 'BAR', '20000000-0000-0000-0000-000000000011', 'Mantenimiento');
        """)
        print("  -> FALLO: Se permitió registrar cierre MESA_ESPECIFICA con zona no nula.")
        sys.exit(1)
    except sqlite3.IntegrityError as e:
        print(f"  -> OK: Rechazado por restricción CHECK chk_cierres_tipo_alcance ({e}).")

    conn.close()
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)

    print("\n" + "=" * 75)
    print("RESULTADO FINAL: LAS 14 PRUEBAS OBLIGATORIAS PASARON CON EXITO (100% OK)")
    print("=" * 75)
    sys.exit(0)

except Exception as ex:
    print(f"\n[ERROR CRITICO EN EJECUCION DE BATERIA]: {ex}")
    conn.close()
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
    sys.exit(1)
