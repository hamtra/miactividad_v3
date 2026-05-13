// ─────────────────────────────────────────────────────────────────────────────
// CATALOG DATA — extraído directamente del Excel 2026_4Cafe.xlsx
// Fuente: hojas 4Cafe.PlanTrabajo, 4Cafe.Fat, 4Cafe.Tarea
// ─────────────────────────────────────────────────────────────────────────────
import 'pta_catalog.dart';

class CatalogData {
  // ── UBICACIÓN — datos del PadronSocios_2025 (CSV) ──────────────────────────
  static const List<String> provincias = [
    'CALCA',
    'LA CONVENCION',
  ];

  /// Distritos que tienen socios registrados (del CSV)
  static const Map<String, List<String>> distritosPorProvincia = {
    'CALCA': ['YANATILE'],
    'LA CONVENCION': [
      'ECHARATE',
      'MARANURA',
      'OCOBAMBA',
      'QUELLOUNO',
      'SANTA ANA',
      'VILCABAMBA',
    ],
  };

  /// Comunidades por distrito — jerarquía exacta del CSV
  static const Map<String, List<String>> comunidadesPorDistrito = {
    'YANATILE': ['ARENAL', 'BARRIAL', 'C.P. CORIMAYO', 'CEDRUYOC', 'CHANCAMAYO',
      'COMBAPATA', 'CORIMAYO COLCA', 'CP SAN MARTIN', 'CUQUIPATA', 'HUAYNACCAPAC',
      'HUY HUY', 'LLAULLIPATA', 'LUY LUY', 'MIRAFLORES', 'MONTE SALVADO',
      'OTALO', 'PALTAYBAMBA', 'PANTORRILLA', 'PASTO GRANDE', 'PAUCARBAMBA',
      'PAYLABAMBA', 'QUINUAYARCCA', 'RIOBAMBA', 'SAN JOSE DE COLCA', 'TORRE BLANCA'],
    'ECHARATE': ['C.P. ECHARATE', 'CALCAPAMPA', 'CC.NN.KORIBENI', 'CCONDORMOCCO',
      'CHAHUARES', 'IVANQUI ALTO', 'KAPASHIARI', 'PAMPA CONCEPCION', 'PAN DE AZUCAR',
      'PIEDRA BLANCA 7 VUELTAS', 'PISPITA', 'SAJIRUYOC', 'SAN MIGUEL', 'SANTA ELENA',
      'TUTIRUYOC', 'YOMENTONI MARGEN IZQUIERDA'],
    'MARANURA': ['BEATRIZ BAJA', 'CHAULLAY CENTRO', 'HUALLPAMAYTA', 'MANDOR',
      'PINTOBAMBA ALTA', 'PIÑALPATA'],
    'OCOBAMBA': ['ANTIBAMBA ALTA', 'BELEMPATA', 'CARMEN ALTO', 'HUAYRACPATA',
      'LECHE PATA', 'MEDIA LUNA BARRANCA', 'OCOBAMBA', 'PAMPAHUASI', 'SANTA ELENA',
      'SAURAMA', 'TABLAHUASI', 'UTUMA'],
    'QUELLOUNO': ['ALTO CHIRUMBIA', 'BOMBOHUACTANA', 'CANELON', 'CCOCHAYOC BAJO',
      'CENTRO CCOCHAYOC', 'CRISTO SALVADOR', 'HATUMPAMPA', 'HUERTAPATA',
      'MERCEDESNIYOC BAJA - CAMPANAYOC', 'PUTUCUSI', 'SAN MARTIN', 'SAN MIGUEL',
      'SANTA ROSA', 'SANTA TERESITA', 'SANTUSAIRES', 'SULLUCUYOC', 'TARCUYOC',
      'TINKURI', 'TUNQUIMAYO BAJO'],
    'SANTA ANA': ['HUAYANAY', 'PAVAYOC', 'POTRERO IDMA', 'SAMBARAY CENTRO'],
    'VILCABAMBA': ['YUVENI'],
  };

  /// Retorna comunidades del distrito seleccionado
  static List<String> comunidadesDeDistrito(String distrito) =>
      comunidadesPorDistrito[distrito] ?? [];

  /// Todas las comunidades (lista plana para compatibilidad con FAT)
  static List<String> get todasLasComunidades {
    final all = <String>[];
    comunidadesPorDistrito.values.forEach(all.addAll);
    all.sort();
    return all;
  }

  // ── TAREAS (idPta) — ahora delegan a PtaCatalog ────────────────────────────
  // El catálogo completo y actualizado vive en lib/core/pta_catalog.dart.
  // Estos helpers se mantienen por compatibilidad con el código existente.

  /// Mapa idPta → indicadoresTareas (para compatibilidad con código legacy)
  static Map<String, String> get tareasPorId => PtaCatalog.ptaPorId;

  static List<String> get tareasLabel =>
      PtaCatalog.todasLasHojas.map((e) => e.indicadoresTareas).toList()..sort();

  static String idPtaFromLabel(String label) {
    for (final e in PtaCatalog.todas) {
      if (e.indicadoresTareas == label) return e.idPta;
    }
    return 'idpta000';
  }

  /// Delega a PtaCatalog para que funcione con los nuevos idPta.
  static String labelFromIdPta(String id) => PtaCatalog.labelFromIdPta(id);

  // ── TEMAS — alineados por mes según tabla oficial 2026 ───────────────────
  // Orden: idtema_001 = MARZO ... idtema_010 = DICIEMBRE
  // idtema_011 = AMBIENTAL, idtema_012 = POSTCOSECHA, idtema_013 = OTROS
  static const Map<String, String> temasPorId = {
    'idtema_001': 'MANEJO Y ADECUACION AMBIENTAL',        // MES: MARZO
    'idtema_002': 'COSECHA Y POSTCOSECHA DE CAFÉ',         // MES: ABRIL
    'idtema_003': 'PRODUCCION DE PLANTONES (RECALCE)',     // MES: MAYO
    'idtema_004': 'ABONOS ORGÁNICOS (COMPOST)',            // MES: JUNIO
    'idtema_005': 'NUTRICIÓN LÍQUIDA',                     // MES: JULIO
    'idtema_006': 'MANEJO DE TEJIDOS (PODAS)',             // MES: AGOSTO
    'idtema_007': 'MIP - ENFERMEDADES',                    // MES: SEPTIEMBRE
    'idtema_008': 'NUTRICIÓN (ABONAMIENTO/FERTILIZACION)', // MES: OCTUBRE
    'idtema_009': 'MIP - BROCA',                           // MES: NOVIEMBRE
    'idtema_010': 'MANEJO Y ADECUACION AMBIENTAL',        // MES: DICIEMBRE
    'idtema_011': 'GESTION AMBIENTAL',                     // MES: AMBIENTAL
    'idtema_012': 'GESTION DE LA CALIDAD',                 // MES: POSTCOSECHA
    'idtema_013': 'OTROS',                                 // MES: OTROS
  };

  /// Tema sugerido automáticamente según el mes del año (1-12).
  /// Devuelve null para ENERO y FEBRERO (sin tema asignado en el PTA).
  static const Map<int, String> temaPorNumeroMes = {
    3:  'idtema_001', // MARZO
    4:  'idtema_002', // ABRIL
    5:  'idtema_003', // MAYO
    6:  'idtema_004', // JUNIO
    7:  'idtema_005', // JULIO
    8:  'idtema_006', // AGOSTO
    9:  'idtema_007', // SEPTIEMBRE
    10: 'idtema_008', // OCTUBRE
    11: 'idtema_009', // NOVIEMBRE
    12: 'idtema_010', // DICIEMBRE
    // 1 y 2 (Enero/Febrero): sin tema por mes fijo
  };

  /// Tema sugerido por nombre de mes (ej. 'MARZO' → 'idtema_001').
  static const Map<String, String> temaPorMes = {
    'MARZO':      'idtema_001',
    'ABRIL':      'idtema_002',
    'MAYO':       'idtema_003',
    'JUNIO':      'idtema_004',
    'JULIO':      'idtema_005',
    'AGOSTO':     'idtema_006',
    'SEPTIEMBRE': 'idtema_007',
    'OCTUBRE':    'idtema_008',
    'NOVIEMBRE':  'idtema_009',
    'DICIEMBRE':  'idtema_010',
  };

  static List<String> get temasLabel =>
      temasPorId.values.toSet().toList()..sort();

  static String idTemaFromLabel(String label) =>
      temasPorId.entries
          .firstWhere((e) => e.value == label,
              orElse: () => const MapEntry('idtema_000', ''))
          .key;

  static String labelFromIdTema(String id) => temasPorId[id] ?? id;

  // ── MODALIDADES FAT ────────────────────────────────────────────────────────
  static const List<String> modalidades = [
    'a. Capacitación',
    'b. Asistencia técnica',
    'Actividades complementarias',
  ];

  // ── ETAPAS ─────────────────────────────────────────────────────────────────
  static const List<String> etapas = [
    'Instalación',
    'Crecimiento',
    'Producción',
    'Podado',
  ];

  // ── CLIMAS ─────────────────────────────────────────────────────────────────
  static const List<String> climas = [
    'Soleado',
    'Nublado',
    'Llovizna (Garúa)',
    'Lluvia Fuerte',
    'Niebla - Neblina',
    'Viento - Frío',
  ];

  // ── INCIDENCIAS ────────────────────────────────────────────────────────────
  static const List<String> incidencias = [
    'Sin Novedades (Todo conforme)',
    'Derrumbe - Vía bloqueada',
    'Camino Intransitable (Lodo)',
    'Crecida de Río / Quebrada',
    'Productor Ausente - Cancelación',
    'Retraso por Transporte - Logística',
  ];

  // ── ESTADOS FAT ────────────────────────────────────────────────────────────
  static const List<String> estadosFat = [
    'REGISTRADO',
    'ENVIADO',
    'APROBADO',
    'OBSERVADO',
  ];

  // ── ESTADOS PLAN DE TRABAJO ────────────────────────────────────────────────
  static const List<String> estadosPlan = [
    'REGISTRADO',
    'ENVIADO',
    'APROBADO',
  ];

  // ── MESES ──────────────────────────────────────────────────────────────────
  static const List<String> meses = [
    'ENERO', 'FEBRERO', 'MARZO', 'ABRIL', 'MAYO', 'JUNIO',
    'JULIO', 'AGOSTO', 'SEPTIEMBRE', 'OCTUBRE', 'NOVIEMBRE', 'DICIEMBRE',
  ];

  // ── ORGANIZACIONES (principales) ───────────────────────────────────────────
  static const List<String> organizaciones = [
    'SIN ORGANIZACIÓN',
    'AEO CAFÉ DEL VALLE',
    'ASOCIACION DE PRODUCTORES ECOLOGICOS',
    'COOPERATIVA AGRARIA CAFETALERA',
    'COOPERATIVA LOS ANDES',
    'JUNTA DE USUARIOS',
  ];

  // ── CARGOS ─────────────────────────────────────────────────────────────────
  static const Map<String, String> cargosPorId = {
    'idcarg001': 'TECNICO DE CAMPO',
    'idcarg002': 'EXTENSIONISTA',
    'idcarg003': 'ESPECIALISTA',
    'idcarg004': 'COORDINADOR',
    'idcarg005': 'SUPERVISOR',
    'idcarg006': 'GESTOR DE INFORMACIÓN',
  };

  // ── ACTIVIDAD PRINCIPAL ────────────────────────────────────────────────────
  static const String nombreActividad =
      'Asistencia técnica en la diversificación productiva de bienes y '
      'servicios alternativos sostenibles - café - OZ Quillabamba';
}
