import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/plan_trabajo.dart';
import '../models/fat.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATABASE HELPER — SQLite local (offline-first)
// Base de datos principal para funcionamiento SIN internet.
// Firebase Firestore se usa como capa de sincronización cuando hay conexión.
// ─────────────────────────────────────────────────────────────────────────────

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  factory DbHelper() => _instance;
  DbHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    // En web, getDatabasesPath() devuelve null → usamos el nombre directamente
    // (sqflite_common_ffi_web usa un sistema de archivos virtual / IndexedDB).
    final String path;
    if (kIsWeb) {
      path = 'miactividad_2026.db';
    } else {
      path = join(await getDatabasesPath(), 'miactividad_2026.db');
    }
    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // ── PLAN DE TRABAJO ──────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE plan_trabajo (
        id               TEXT PRIMARY KEY,
        mes              TEXT NOT NULL,
        id_tec_esp_ext   TEXT,
        nombre_tecnico   TEXT,
        nombre_actividad TEXT,
        fecha_creacion   TEXT NOT NULL,
        id_coordinador   TEXT,
        nombre_coordinador TEXT,
        estado           TEXT DEFAULT 'REGISTRADO',
        file_path        TEXT,
        usuario          TEXT,
        observaciones    TEXT,
        synced           INTEGER DEFAULT 0,
        created_at       TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // ── TAREA (pertenece a PlanTrabajo) ──────────────────────────────────────
    // socios_completados: JSON con {idSocio: idFat} indicando qué socios
    // del plan ya tienen una FAT registrada.
    await db.execute('''
      CREATE TABLE tarea (
        id                  TEXT PRIMARY KEY,
        id_plan_trabajo     TEXT NOT NULL,
        fecha               TEXT NOT NULL,
        hora_inicio         TEXT,
        hora_final          TEXT,
        id_pta              TEXT,
        provincia           TEXT,
        distrito            TEXT,
        comunidad           TEXT,
        id_socio            TEXT,
        detalle_pta         TEXT,
        usuario             TEXT,
        synced              INTEGER DEFAULT 0,
        socios              TEXT DEFAULT '',
        socios_completados  TEXT DEFAULT '',
        FOREIGN KEY (id_plan_trabajo) REFERENCES plan_trabajo(id) ON DELETE CASCADE
      )
    ''');

    // ── FAT (Ficha de Asistencia Técnica) ────────────────────────────────────
    // id_tarea + id_socio_plan: vínculo opcional al plan de trabajo, para
    // cerrar el ciclo y marcar la visita como completada en el plan.
    await db.execute('''
      CREATE TABLE fat (
        id                       TEXT PRIMARY KEY,
        nro_fat                  TEXT,
        numeracion               TEXT DEFAULT '1',
        fecha_creacion           TEXT NOT NULL,
        fecha_asistencia         TEXT NOT NULL,
        modalidad                TEXT,
        etapa_crianza            TEXT,
        id_pta                   TEXT,
        detalle_pta              TEXT,
        id_tema                  TEXT,
        provincia                TEXT,
        distrito                 TEXT,
        comunidad                TEXT,
        ubicacion                TEXT,
        hora_inicio              TEXT,
        hora_final               TEXT,
        clima                    TEXT,
        incidencia               TEXT,
        id_tec_esp_ext           TEXT,
        nombre_tecnico           TEXT,
        id_cargo                 TEXT,
        cargo                    TEXT,
        organizacion_productores TEXT DEFAULT 'SIN ORGANIZACIÓN',
        id_socio                 TEXT,
        nro_socios_participantes INTEGER DEFAULT 0,
        actividades_realizadas   TEXT,
        resultados               TEXT,
        acuerdos_compromisos     TEXT,
        recomendaciones          TEXT,
        proxima_visita           TEXT,
        proxima_visita_tema      TEXT,
        observaciones            TEXT,
        firma_socio              TEXT,
        fotografia1              TEXT,
        foto1_descripcion        TEXT,
        fotografia2              TEXT,
        foto2_descripcion        TEXT,
        fotografia3              TEXT,
        foto3_descripcion        TEXT,
        estado                   TEXT DEFAULT 'REGISTRADO',
        estado_observaciones     TEXT,
        usuario                  TEXT,
        mes                      TEXT,
        id_tarea                 TEXT,
        id_socio_plan            TEXT,
        synced                   INTEGER DEFAULT 0,
        created_at               TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // ── SOCIOS PARTICIPANTES (pertenece a FAT) ───────────────────────────────
    await db.execute('''
      CREATE TABLE socios_participantes (
        id               TEXT PRIMARY KEY,
        id_fat           TEXT NOT NULL,
        id_socio         TEXT,
        dni              TEXT,
        nombre_completo  TEXT,
        id_tema          TEXT,
        tema             TEXT,
        mes              TEXT,
        usuario          TEXT,
        FOREIGN KEY (id_fat) REFERENCES fat(id) ON DELETE CASCADE
      )
    ''');

    await _createIndexes(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE fat ADD COLUMN synced INTEGER DEFAULT 0');
      } catch (_) {}
    }
    if (oldVersion < 3) {
      // Agrega columna socios a tarea (JSON lista de socios seleccionados)
      try {
        await db.execute("ALTER TABLE tarea ADD COLUMN socios TEXT DEFAULT ''");
      } catch (_) {}
    }
    if (oldVersion < 4) {
      // Vínculo FAT ↔ Tarea/Socio del plan + tracking de socios completados
      try {
        await db.execute("ALTER TABLE tarea ADD COLUMN socios_completados TEXT DEFAULT ''");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE fat ADD COLUMN id_tarea TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE fat ADD COLUMN id_socio_plan TEXT");
      } catch (_) {}
    }
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tarea_plan ON tarea(id_plan_trabajo)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_fat_usuario ON fat(usuario)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_fat_estado ON fat(estado)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_fat_mes ON fat(mes)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_socios_fat ON socios_participantes(id_fat)');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PLAN DE TRABAJO
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> insertPlan(PlanTrabajo plan) async {
    final db = await database;
    return db.insert('plan_trabajo', plan.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updatePlan(PlanTrabajo plan) async {
    final db = await database;
    return db.update('plan_trabajo', plan.toMap(),
        where: 'id = ?', whereArgs: [plan.id]);
  }

  Future<int> deletePlan(String id) async {
    final db = await database;
    // Cascade borrará las tareas asociadas
    return db.delete('plan_trabajo', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<PlanTrabajo>> getPlanes({String? usuario, String? mes}) async {
    final db = await database;
    String where = '1=1';
    final args = <dynamic>[];
    if (usuario != null) { where += ' AND usuario = ?'; args.add(usuario); }
    if (mes != null)     { where += ' AND mes = ?';     args.add(mes); }
    final rows = await db.query('plan_trabajo',
        where: where, whereArgs: args, orderBy: 'fecha_creacion DESC');
    final planes = rows.map((r) => PlanTrabajo.fromMap(r)).toList();
    // Cargar tareas de cada plan
    for (final plan in planes) {
      plan.tareas = await getTareasDePlan(plan.id);
    }
    return planes;
  }

  Future<PlanTrabajo?> getPlanById(String id) async {
    final db = await database;
    final rows = await db.query('plan_trabajo', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final plan = PlanTrabajo.fromMap(rows.first);
    plan.tareas = await getTareasDePlan(id);
    return plan;
  }

  Future<List<PlanTrabajo>> getPlanesNoSynced() async {
    final db = await database;
    final rows = await db.query('plan_trabajo',
        where: 'synced = 0', orderBy: 'created_at ASC');
    return rows.map((r) => PlanTrabajo.fromMap(r)).toList();
  }

  Future<void> markPlanSynced(String id) async {
    final db = await database;
    await db.update('plan_trabajo', {'synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAREA
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> insertTarea(Tarea tarea) async {
    final db = await database;
    return db.insert('tarea', tarea.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateTarea(Tarea tarea) async {
    final db = await database;
    return db.update('tarea', tarea.toMap(),
        where: 'id = ?', whereArgs: [tarea.id]);
  }

  Future<int> deleteTarea(String id) async {
    final db = await database;
    return db.delete('tarea', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Tarea>> getTareasDePlan(String idPlan) async {
    final db = await database;
    final rows = await db.query('tarea',
        where: 'id_plan_trabajo = ?',
        whereArgs: [idPlan],
        orderBy: 'fecha ASC');
    return rows.map((r) => Tarea.fromMap(r)).toList();
  }

  /// Tareas del usuario en una fecha específica (vista "Mi día").
  /// La comparación se hace por fecha-día (ignora hora).
  Future<List<Tarea>> getTareasDelDia(String usuario, DateTime fecha) async {
    final db = await database;
    final inicio = DateTime(fecha.year, fecha.month, fecha.day).toIso8601String();
    final fin = DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59).toIso8601String();
    final rows = await db.query(
      'tarea',
      where: 'usuario = ? AND fecha >= ? AND fecha <= ?',
      whereArgs: [usuario, inicio, fin],
      orderBy: 'hora_inicio ASC',
    );
    return rows.map((r) => Tarea.fromMap(r)).toList();
  }

  /// Tareas del usuario en un rango (semana, mes, etc.)
  Future<List<Tarea>> getTareasEnRango(
      String usuario, DateTime desde, DateTime hasta) async {
    final db = await database;
    final rows = await db.query(
      'tarea',
      where: 'usuario = ? AND fecha >= ? AND fecha <= ?',
      whereArgs: [
        usuario,
        DateTime(desde.year, desde.month, desde.day).toIso8601String(),
        DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59).toIso8601String(),
      ],
      orderBy: 'fecha ASC, hora_inicio ASC',
    );
    return rows.map((r) => Tarea.fromMap(r)).toList();
  }

  /// Marca un socio como completado en una tarea (al guardar la FAT vinculada).
  /// Guarda en socios_completados un JSON {idSocio: idFat, ...}.
  Future<void> marcarSocioCompletado({
    required String idTarea,
    required String idSocio,
    required String idFat,
  }) async {
    final db = await database;
    final rows = await db.query('tarea',
        where: 'id = ?', whereArgs: [idTarea], limit: 1);
    if (rows.isEmpty) return;
    final tarea = Tarea.fromMap(rows.first);
    final mapa = Map<String, String>.from(tarea.sociosCompletadosMap);
    mapa[idSocio] = idFat;
    tarea.sociosCompletadosJson = _encodeMap(mapa);
    tarea.synced = false;
    await updateTarea(tarea);
  }

  /// Quita la marca de completado (al eliminar la FAT vinculada).
  Future<void> desmarcarSocioCompletado({
    required String idTarea,
    required String idSocio,
  }) async {
    final db = await database;
    final rows = await db.query('tarea',
        where: 'id = ?', whereArgs: [idTarea], limit: 1);
    if (rows.isEmpty) return;
    final tarea = Tarea.fromMap(rows.first);
    final mapa = Map<String, String>.from(tarea.sociosCompletadosMap);
    mapa.remove(idSocio);
    tarea.sociosCompletadosJson = _encodeMap(mapa);
    tarea.synced = false;
    await updateTarea(tarea);
  }

  String _encodeMap(Map<String, String> m) {
    if (m.isEmpty) return '';
    return jsonEncode(m);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FAT
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> insertFat(Fat fat) async {
    final db = await database;
    return db.insert('fat', fat.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateFat(Fat fat) async {
    final db = await database;
    return db.update('fat', fat.toMap(),
        where: 'id = ?', whereArgs: [fat.id]);
  }

  Future<int> updateFatEstado(String id, String estado,
      {String? observaciones}) async {
    final db = await database;
    final data = <String, dynamic>{'estado': estado, 'synced': 0};
    if (observaciones != null) data['estado_observaciones'] = observaciones;
    return db.update('fat', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteFat(String id) async {
    final db = await database;
    return db.delete('fat', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Fat>> getFats({
    String? usuario,
    String? mes,
    String? estado,
    int? limit,
  }) async {
    final db = await database;
    String where = '1=1';
    final args = <dynamic>[];
    if (usuario != null) { where += ' AND usuario = ?'; args.add(usuario); }
    if (mes != null)     { where += ' AND mes = ?';     args.add(mes); }
    if (estado != null)  { where += ' AND estado = ?';  args.add(estado); }
    final rows = await db.query(
      'fat',
      where: where,
      whereArgs: args,
      orderBy: 'fecha_creacion DESC',
      limit: limit,
    );
    return rows.map((r) => Fat.fromMap(r)).toList();
  }

  Future<Fat?> getFatById(String id) async {
    final db = await database;
    final rows = await db.query('fat', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Fat.fromMap(rows.first);
  }

  Future<List<Fat>> getFatsNoSynced() async {
    final db = await database;
    final rows = await db.query('fat',
        where: 'synced = 0', orderBy: 'created_at ASC');
    return rows.map((r) => Fat.fromMap(r)).toList();
  }

  Future<void> markFatSynced(String id) async {
    final db = await database;
    await db.update('fat', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SOCIOS PARTICIPANTES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> insertSocio(SocioParticipante socio) async {
    final db = await database;
    return db.insert('socios_participantes', socio.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> deleteSociosDeFat(String idFat) async {
    final db = await database;
    return db.delete('socios_participantes',
        where: 'id_fat = ?', whereArgs: [idFat]);
  }

  Future<List<SocioParticipante>> getSociosDeFat(String idFat) async {
    final db = await database;
    final rows = await db.query('socios_participantes',
        where: 'id_fat = ?', whereArgs: [idFat]);
    return rows.map((r) => SocioParticipante.fromMap(r)).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADÍSTICAS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, int>> getFatCountByEstado(String usuario) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT estado, COUNT(*) as cnt
      FROM fat
      WHERE usuario = ?
      GROUP BY estado
    ''', [usuario]);
    final result = <String, int>{};
    for (final r in rows) {
      result[r['estado'] as String] = r['cnt'] as int;
    }
    return result;
  }

  Future<int> countFatsMes(String usuario, String mes) async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM fat WHERE usuario = ? AND mes = ?',
        [usuario, mes]);
    return rows.first['cnt'] as int;
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _db = null;
  }
}
