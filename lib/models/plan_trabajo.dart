import 'dart:convert';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODEL: PlanTrabajo  ←→  hoja 4Cafe.PlanTrabajo
// ─────────────────────────────────────────────────────────────────────────────
class PlanTrabajo {
  final String id;           // idPlanTrabajo (UUID)
  String mes;
  String idTecEspExt;        // id del técnico/extensionista
  String nombreTecnico;      // nombre legible
  String nombreActividad;
  DateTime fechaCreacion;
  String idCoordinador;
  String nombreCoordinador;
  String estado;             // REGISTRADO | ENVIADO | APROBADO
  String? filePath;
  String usuario;            // DNI del usuario
  String? observaciones;
  List<Tarea> tareas;
  bool synced;

  PlanTrabajo({
    required this.id,
    required this.mes,
    required this.idTecEspExt,
    required this.nombreTecnico,
    required this.nombreActividad,
    required this.fechaCreacion,
    required this.idCoordinador,
    required this.nombreCoordinador,
    this.estado = 'REGISTRADO',
    this.filePath,
    required this.usuario,
    this.observaciones,
    this.tareas = const [],
    this.synced = false,
  });

  // ── SQLite ─────────────────────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
        'id': id,
        'mes': mes,
        'id_tec_esp_ext': idTecEspExt,
        'nombre_tecnico': nombreTecnico,
        'nombre_actividad': nombreActividad,
        'fecha_creacion': fechaCreacion.toIso8601String(),
        'id_coordinador': idCoordinador,
        'nombre_coordinador': nombreCoordinador,
        'estado': estado,
        'file_path': filePath,
        'usuario': usuario,
        'observaciones': observaciones,
        'synced': synced ? 1 : 0,
      };

  factory PlanTrabajo.fromMap(Map<String, dynamic> m) => PlanTrabajo(
        id: m['id'],
        mes: m['mes'],
        idTecEspExt: m['id_tec_esp_ext'] ?? '',
        nombreTecnico: m['nombre_tecnico'] ?? '',
        nombreActividad: m['nombre_actividad'] ?? '',
        fechaCreacion: DateTime.parse(m['fecha_creacion']),
        idCoordinador: m['id_coordinador'] ?? '',
        nombreCoordinador: m['nombre_coordinador'] ?? '',
        estado: m['estado'] ?? 'REGISTRADO',
        filePath: m['file_path'],
        usuario: m['usuario'] ?? '',
        observaciones: m['observaciones'],
        synced: (m['synced'] ?? 0) == 1,
      );

  // ── Firestore ──────────────────────────────────────────────────────────────
  Map<String, dynamic> toFirestore() => {
        'mes': mes,
        'idTecEspExt': idTecEspExt,
        'nombreTecnico': nombreTecnico,
        'nombreActividad': nombreActividad,
        'fechaCreacion': fechaCreacion.toIso8601String(),
        'idCoordinador': idCoordinador,
        'nombreCoordinador': nombreCoordinador,
        'estado': estado,
        'usuario': usuario,
        'observaciones': observaciones,
        'updatedAt': DateTime.now().toIso8601String(),
      };

  PlanTrabajo copyWith({
    String? estado,
    String? observaciones,
    bool clearObservaciones = false,
  }) =>
      PlanTrabajo(
        id: id,
        mes: mes,
        idTecEspExt: idTecEspExt,
        nombreTecnico: nombreTecnico,
        nombreActividad: nombreActividad,
        fechaCreacion: fechaCreacion,
        idCoordinador: idCoordinador,
        nombreCoordinador: nombreCoordinador,
        estado: estado ?? this.estado,
        filePath: filePath,
        usuario: usuario,
        observaciones: clearObservaciones
            ? null
            : (observaciones ?? this.observaciones),
        tareas: tareas,
        synced: synced,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// MODEL: Tarea  ←→  hoja 4Cafe.Tarea
// ─────────────────────────────────────────────────────────────────────────────
class Tarea {
  final String id;           // idTarea (8-char hex)
  String idPlanTrabajo;
  DateTime fecha;
  String horaInicio;         // "HH:mm"
  String horaFinal;
  String idPta;              // id de la tarea (idpta012, etc.)
  String provincia;
  String distrito;
  String comunidad;
  String? idSocio;           // legacy — mantenido para compatibilidad
  String detallePta;         // descripción libre
  String usuario;
  bool synced;
  /// JSON: [{"id":"id_so_000001","nombre":"BORDA SALAS MAGALI","dni":"43397461"}]
  String sociosJson;

  /// JSON: {"id_so_000001":"FAT-UUID-1234", ...}
  /// Indica qué socios programados ya tienen su FAT registrada.
  String sociosCompletadosJson;

  Tarea({
    required this.id,
    required this.idPlanTrabajo,
    required this.fecha,
    required this.horaInicio,
    required this.horaFinal,
    required this.idPta,
    required this.provincia,
    required this.distrito,
    required this.comunidad,
    this.idSocio,
    required this.detallePta,
    required this.usuario,
    this.synced = false,
    this.sociosJson = '',
    this.sociosCompletadosJson = '',
  });

  /// Lista de socios seleccionados deserializada
  List<Map<String, String>> get sociosList {
    if (sociosJson.isEmpty) return [];
    try {
      final parsed = jsonDecode(sociosJson) as List;
      return parsed
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Mapa {idSocio: idFat} de socios ya completados (con FAT registrada).
  Map<String, String> get sociosCompletadosMap {
    if (sociosCompletadosJson.isEmpty) return {};
    try {
      final parsed = jsonDecode(sociosCompletadosJson) as Map;
      return parsed.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return {};
    }
  }

  /// ¿El socio (por id) ya tiene FAT registrada en esta tarea?
  bool socioCompletado(String idSocio) =>
      sociosCompletadosMap.containsKey(idSocio);

  /// Cantidad de socios completados / total programados.
  int get totalSocios => sociosList.length;
  int get completados => sociosCompletadosMap.length;
  bool get tareaCompleta => totalSocios > 0 && completados >= totalSocios;
  double get progreso =>
      totalSocios == 0 ? 0 : completados / totalSocios;

  /// Nombres de socios para mostrar en UI (todos, separados por coma)
  String get sociosResumen {
    final lista = sociosList;
    if (lista.isEmpty) return '';
    return lista.map((s) => s['nombre'] ?? '').where((n) => n.isNotEmpty).join(', ');
  }

  String get fechaFormateada => DateFormat('dd/MM/yyyy').format(fecha);

  Map<String, dynamic> toMap() => {
        'id': id,
        'id_plan_trabajo': idPlanTrabajo,
        'fecha': fecha.toIso8601String(),
        'hora_inicio': horaInicio,
        'hora_final': horaFinal,
        'id_pta': idPta,
        'provincia': provincia,
        'distrito': distrito,
        'comunidad': comunidad,
        'id_socio': idSocio,
        'detalle_pta': detallePta,
        'usuario': usuario,
        'synced': synced ? 1 : 0,
        'socios': sociosJson,
        'socios_completados': sociosCompletadosJson,
      };

  factory Tarea.fromMap(Map<String, dynamic> m) => Tarea(
        id: m['id'],
        idPlanTrabajo: m['id_plan_trabajo'],
        fecha: DateTime.parse(m['fecha']),
        horaInicio: m['hora_inicio'],
        horaFinal: m['hora_final'],
        idPta: m['id_pta'] ?? '',
        provincia: m['provincia'] ?? '',
        distrito: m['distrito'] ?? '',
        comunidad: m['comunidad'] ?? '',
        idSocio: m['id_socio'],
        detallePta: m['detalle_pta'] ?? '',
        usuario: m['usuario'] ?? '',
        synced: (m['synced'] ?? 0) == 1,
        sociosJson: (m['socios'] as String?) ?? '',
        sociosCompletadosJson: (m['socios_completados'] as String?) ?? '',
      );

  /// Serialización hacia Firestore (array dentro del plan)
  Map<String, dynamic> toFirestoreMap() => {
        'id':         id,
        'fecha':      fecha.toIso8601String(),
        'horaInicio': horaInicio,
        'horaFinal':  horaFinal,
        'idPta':      idPta,
        'provincia':  provincia,
        'distrito':   distrito,
        'comunidad':  comunidad,
        'detallePta': detallePta,
        'usuario':    usuario,
        'socios': sociosJson.isEmpty
            ? <dynamic>[]
            : (jsonDecode(sociosJson) as List),
        'sociosCompletados': sociosCompletadosMap,
      };
}
