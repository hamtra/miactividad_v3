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

  PlanTrabajo copyWith({String? estado, String? observaciones}) => PlanTrabajo(
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
        observaciones: observaciones ?? this.observaciones,
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
  String? idSocio;
  String detallePta;         // descripción libre
  String usuario;
  bool synced;

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
  });

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
      );
}
