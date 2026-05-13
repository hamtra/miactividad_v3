import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODEL: Fat  ←→  hoja 4Cafe.Fat  (48 columnas en AppSheet)
// ─────────────────────────────────────────────────────────────────────────────
class Fat {
  final String id;           // idFat (UUID)
  String nroFat;             // ej: "42576438-118-1"
  String numeracion;
  DateTime fechaCreacion;
  DateTime fechaAsistencia;

  // Sección 1 – Identificación
  String modalidad;
  String etapaCrianza;
  String idPta;
  String detallePta;
  String idTema;

  // Sección 2 – Ubicación
  String provincia;
  String distrito;
  String comunidad;
  String? ubicacion;         // "lat, long" de GPS
  String horaInicio;
  String horaFinal;
  String clima;
  String incidencia;

  // Sección 3 – Responsable
  String idTecEspExt;
  String nombreTecnico;
  String idCargo;
  String cargo;
  String organizacionProductores;
  String idSocio;
  int nroSociosParticipantes;

  // Sección 4 – Desarrollo
  String actividadesRealizadas;
  String resultados;
  String acuerdosCompromisos;
  String recomendaciones;
  DateTime proximaVisita;
  String proximaVisitaTema;
  String observaciones;

  // Firma y fotos
  String? firmaSocio;        // ruta de imagen
  String? fotografia1;
  String foto1Descripcion;
  String? fotografia2;
  String foto2Descripcion;
  String? fotografia3;
  String foto3Descripcion;

  // Gestión
  String estado;             // REGISTRADO | ENVIADO | APROBADO | OBSERVADO
  String? estadoObservaciones;
  String usuario;
  String mes;
  bool synced;

  // ── Vínculo opcional con el Plan de Trabajo ────────────────────────────────
  String? idTarea;
  String? idSocioPlan;

  // ── Aprobación jerárquica ─────────────────────────────────────────────────
  // UID del superior inmediato del técnico que creó la FAT.
  // Se guarda al crear para que el superior pueda filtrar sus FATs pendientes.
  String idSuperior;

  Fat({
    required this.id,
    required this.nroFat,
    this.numeracion = '1',
    required this.fechaCreacion,
    required this.fechaAsistencia,
    required this.modalidad,
    required this.etapaCrianza,
    required this.idPta,
    this.detallePta = '',
    required this.idTema,
    required this.provincia,
    required this.distrito,
    required this.comunidad,
    this.ubicacion,
    required this.horaInicio,
    required this.horaFinal,
    required this.clima,
    required this.incidencia,
    required this.idTecEspExt,
    required this.nombreTecnico,
    required this.idCargo,
    required this.cargo,
    this.organizacionProductores = 'SIN ORGANIZACIÓN',
    required this.idSocio,
    this.nroSociosParticipantes = 0,
    this.actividadesRealizadas = '',
    this.resultados = '',
    this.acuerdosCompromisos = '',
    this.recomendaciones = '',
    required this.proximaVisita,
    this.proximaVisitaTema = '',
    this.observaciones = '',
    this.firmaSocio,
    this.fotografia1,
    this.foto1Descripcion = '',
    this.fotografia2,
    this.foto2Descripcion = '',
    this.fotografia3,
    this.foto3Descripcion = '',
    this.estado = 'REGISTRADO',
    this.estadoObservaciones,
    required this.usuario,
    required this.mes,
    this.synced = false,
    this.idTarea,
    this.idSocioPlan,
    this.idSuperior = '',
  });

  String get fechaFormateada =>
      DateFormat('dd/MM/yyyy').format(fechaAsistencia);

  // ── SQLite ─────────────────────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
        'id': id,
        'nro_fat': nroFat,
        'numeracion': numeracion,
        'fecha_creacion': fechaCreacion.toIso8601String(),
        'fecha_asistencia': fechaAsistencia.toIso8601String(),
        'modalidad': modalidad,
        'etapa_crianza': etapaCrianza,
        'id_pta': idPta,
        'detalle_pta': detallePta,
        'id_tema': idTema,
        'provincia': provincia,
        'distrito': distrito,
        'comunidad': comunidad,
        'ubicacion': ubicacion,
        'hora_inicio': horaInicio,
        'hora_final': horaFinal,
        'clima': clima,
        'incidencia': incidencia,
        'id_tec_esp_ext': idTecEspExt,
        'nombre_tecnico': nombreTecnico,
        'id_cargo': idCargo,
        'cargo': cargo,
        'organizacion_productores': organizacionProductores,
        'id_socio': idSocio,
        'nro_socios_participantes': nroSociosParticipantes,
        'actividades_realizadas': actividadesRealizadas,
        'resultados': resultados,
        'acuerdos_compromisos': acuerdosCompromisos,
        'recomendaciones': recomendaciones,
        'proxima_visita': proximaVisita.toIso8601String(),
        'proxima_visita_tema': proximaVisitaTema,
        'observaciones': observaciones,
        'firma_socio': firmaSocio,
        'fotografia1': fotografia1,
        'foto1_descripcion': foto1Descripcion,
        'fotografia2': fotografia2,
        'foto2_descripcion': foto2Descripcion,
        'fotografia3': fotografia3,
        'foto3_descripcion': foto3Descripcion,
        'estado': estado,
        'estado_observaciones': estadoObservaciones,
        'usuario': usuario,
        'mes': mes,
        'synced': synced ? 1 : 0,
        'id_tarea': idTarea,
        'id_socio_plan': idSocioPlan,
        'id_superior': idSuperior,
      };

  factory Fat.fromMap(Map<String, dynamic> m) => Fat(
        id: m['id'],
        nroFat: m['nro_fat'] ?? '',
        numeracion: m['numeracion'] ?? '1',
        fechaCreacion: DateTime.parse(m['fecha_creacion']),
        fechaAsistencia: DateTime.parse(m['fecha_asistencia']),
        modalidad: m['modalidad'] ?? 'b. Asistencia técnica',
        etapaCrianza: m['etapa_crianza'] ?? 'Producción',
        idPta: m['id_pta'] ?? '',
        detallePta: m['detalle_pta'] ?? '',
        idTema: m['id_tema'] ?? '',
        provincia: m['provincia'] ?? '',
        distrito: m['distrito'] ?? '',
        comunidad: m['comunidad'] ?? '',
        ubicacion: m['ubicacion'],
        horaInicio: m['hora_inicio'] ?? '08:00',
        horaFinal: m['hora_final'] ?? '12:00',
        clima: m['clima'] ?? 'Soleado',
        incidencia: m['incidencia'] ?? 'Sin Novedades (Todo conforme)',
        idTecEspExt: m['id_tec_esp_ext'] ?? '',
        nombreTecnico: m['nombre_tecnico'] ?? '',
        idCargo: m['id_cargo'] ?? '',
        cargo: m['cargo'] ?? '',
        organizacionProductores:
            m['organizacion_productores'] ?? 'SIN ORGANIZACIÓN',
        idSocio: m['id_socio'] ?? '',
        nroSociosParticipantes: m['nro_socios_participantes'] ?? 0,
        actividadesRealizadas: m['actividades_realizadas'] ?? '',
        resultados: m['resultados'] ?? '',
        acuerdosCompromisos: m['acuerdos_compromisos'] ?? '',
        recomendaciones: m['recomendaciones'] ?? '',
        proximaVisita: DateTime.parse(m['proxima_visita']),
        proximaVisitaTema: m['proxima_visita_tema'] ?? '',
        observaciones: m['observaciones'] ?? '',
        firmaSocio: m['firma_socio'],
        fotografia1: m['fotografia1'],
        foto1Descripcion: m['foto1_descripcion'] ?? '',
        fotografia2: m['fotografia2'],
        foto2Descripcion: m['foto2_descripcion'] ?? '',
        fotografia3: m['fotografia3'],
        foto3Descripcion: m['foto3_descripcion'] ?? '',
        estado: m['estado'] ?? 'REGISTRADO',
        estadoObservaciones: m['estado_observaciones'],
        usuario: m['usuario'] ?? '',
        mes: m['mes'] ?? '',
        synced: (m['synced'] ?? 0) == 1,
        idTarea: m['id_tarea'] as String?,
        idSocioPlan: m['id_socio_plan'] as String?,
        idSuperior: m['id_superior'] ?? '',
      );

  // ── Firestore ──────────────────────────────────────────────────────────────
  Map<String, dynamic> toFirestore() => {
        'nroFat': nroFat,
        'fechaAsistencia': fechaAsistencia.toIso8601String(),
        'modalidad': modalidad,
        'etapaCrianza': etapaCrianza,
        'idPta': idPta,
        'idTema': idTema,
        'provincia': provincia,
        'distrito': distrito,
        'comunidad': comunidad,
        'ubicacion': ubicacion,
        'horaInicio': horaInicio,
        'horaFinal': horaFinal,
        'clima': clima,
        'incidencia': incidencia,
        'nombreTecnico': nombreTecnico,
        'cargo': cargo,
        'organizacionProductores': organizacionProductores,
        'actividadesRealizadas': actividadesRealizadas,
        'resultados': resultados,
        'acuerdosCompromisos': acuerdosCompromisos,
        'recomendaciones': recomendaciones,
        'proximaVisita': proximaVisita.toIso8601String(),
        'foto1Descripcion': foto1Descripcion,
        'foto2Descripcion': foto2Descripcion,
        'foto3Descripcion': foto3Descripcion,
        if (fotografia1 != null && fotografia1!.isNotEmpty) 'fotografia1': fotografia1,
        if (fotografia2 != null && fotografia2!.isNotEmpty) 'fotografia2': fotografia2,
        if (fotografia3 != null && fotografia3!.isNotEmpty) 'fotografia3': fotografia3,
        if (firmaSocio  != null && firmaSocio!.isNotEmpty)  'firmaSocio':  firmaSocio,
        'estado': estado,
        'usuario': usuario,
        'mes': mes,
        'idSuperior': idSuperior,
        if (idTarea != null) 'idTarea': idTarea,
        if (idSocioPlan != null) 'idSocioPlan': idSocioPlan,
        'updatedAt': DateTime.now().toIso8601String(),
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// MODEL: SocioParticipante  ←→  hoja 4Cafe.SociosParticipantes
// ─────────────────────────────────────────────────────────────────────────────
class SocioParticipante {
  final String id;
  String idFat;
  String idSocio;
  String dni;
  String nombreCompleto;
  String idTema;
  String tema;
  String mes;
  String usuario;

  SocioParticipante({
    required this.id,
    required this.idFat,
    required this.idSocio,
    required this.dni,
    required this.nombreCompleto,
    this.idTema = '',
    this.tema = '',
    required this.mes,
    required this.usuario,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'id_fat': idFat,
        'id_socio': idSocio,
        'dni': dni,
        'nombre_completo': nombreCompleto,
        'id_tema': idTema,
        'tema': tema,
        'mes': mes,
        'usuario': usuario,
      };

  factory SocioParticipante.fromMap(Map<String, dynamic> m) =>
      SocioParticipante(
        id: m['id'],
        idFat: m['id_fat'],
        idSocio: m['id_socio'] ?? '',
        dni: m['dni'] ?? '',
        nombreCompleto: m['nombre_completo'] ?? '',
        idTema: m['id_tema'] ?? '',
        tema: m['tema'] ?? '',
        mes: m['mes'] ?? '',
        usuario: m['usuario'] ?? '',
      );
}
