// ─────────────────────────────────────────────────────────────────────────────
// CATALOG DATA — extraído directamente del Excel 2026_4Cafe.xlsx
// Fuente: hojas 4Cafe.PlanTrabajo, 4Cafe.Fat, 4Cafe.Tarea
// ─────────────────────────────────────────────────────────────────────────────

class CatalogData {
  // ── UBICACIÓN ──────────────────────────────────────────────────────────────
  static const List<String> provincias = [
    'CALCA',
    'LA CONVENCION',
  ];

  static const Map<String, List<String>> distritosPorProvincia = {
    'CALCA': ['YANATILE', 'CALCA', 'PISAQ', 'LAMAY'],
    'LA CONVENCION': [
      'ECHARATE',
      'HUAYOPATA',
      'INKAWASI',
      'KIMBIRI',
      'MARANURA',
      'OCOBAMBA',
      'QUELLOUNO',
      'SANTA ANA',
      'SANTA TERESA',
      'VILCABAMBA',
    ],
  };

  static const List<String> comunidades = [
    'ALTO CHIRUMBIA',
    'ANTIBAMBA ALTA',
    'ARENAL',
    'BARRIAL',
    'BEATRIZ BAJA',
    'BELEMPATA',
    'BOMBOHUACTANA',
    'C.P. CORIMAYO',
    'CANELON',
    'CARMEN ALTO',
    'CEDRUYOC',
    'CHALLHUAHUACHO',
    'CHANCAMAYO',
    'COMBAPATA',
    'CORIMAYO COLCA',
    'CP SAN MARTIN',
    'CRISTO SALVADOR',
    'CUQUIPATA',
    'HATUMPAMPA',
    'HUALLPAMAYTA',
    'HUAYANAY',
    'HUAYNACCAPAC',
    'HUAYRACPATA',
    'HUERTAPATA',
    'HUY HUY',
    'LECHE PATA',
    'LLAULLIPATA',
    'LUY LUY',
    'MEDIA LUNA BARRANCA',
    'MIRAFLORES',
    'MONTE SALVADO',
    'OCOBAMBA',
    'OTALO',
    'PALTAYBAMBA',
    'PAMPAHUASI',
    'PANTORRILLA',
    'PASTO GRANDE',
    'PAUCARBAMBA',
    'PAVAYOC',
    'PAYLABAMBA',
    'POTRERO IDMA',
    'PUCYURA',
    'PUTUCUSI',
    'QUINUAYARCCA',
    'RIOBAMBA',
    'SAMBARAY CENTRO',
    'SAN JOSE DE COLCA',
    'SAN MARTIN',
    'SAN MIGUEL',
    'SANTA ELENA',
    'SANTA ROSA',
    'SANTA TERESITA',
    'SANTUSAIRES',
    'SAURAMA',
    'TABLAHUASI',
    'TARCUYOC',
    'TINKURI',
    'TORRE BLANCA',
    'TRAPICHE',
    'UTUMA',
  ];

  // ── TAREAS (idPta) — de la hoja 4Cafe.Tarea ────────────────────────────────
  /// Mapa idPta → descripción
  static const Map<String, String> tareasPorId = {
    'idpta006': '6. Actividades complementarias',
    'idpta012': 'Coordinación para realizar la reunión del DPR',
    'idpta016': 'Manejo y adecuación ambiental',
    'idpta018': 'Conformación del comité fitosanitario',
    'idpta022': 'Manejo de residuos sólidos',
    'idpta025': 'Implementación de la ECA',
    'idpta026': 'Instalación de parcela demostrativa',
    'idpta028': 'Día de campo',
    'idpta030': 'Selección de semilla de café / vivero familiar',
    'idpta031': 'Cosecha y postcosecha',
    'idpta033': 'Manejo de residuos orgánicos',
    'idpta037': 'Conformación de comité fitosanitario',
    'idpta038': 'Mantenimiento de Áreas: cosecha y postcosecha',
    'idpta039': 'Implementación de módulos de cosecha',
    'idpta040': 'VATPP: Mantenimiento de módulos y equipos',
    'idpta043': 'Verificación de vivienda - manejo sostenible',
    'idpta044': 'Mantenimiento de módulo de acopio residuos sólidos',
    'idpta049': 'Campaña de sensibilización',
    'idpta055': 'Trabajo de gabinete, revisión de adendas',
  };

  static List<String> get tareasLabel =>
      tareasPorId.values.toList()..sort();

  static String idPtaFromLabel(String label) =>
      tareasPorId.entries
          .firstWhere((e) => e.value == label,
              orElse: () => const MapEntry('idpta000', ''))
          .key;

  static String labelFromIdPta(String id) => tareasPorId[id] ?? id;

  // ── TEMAS — de la hoja 4Cafe.Fat ───────────────────────────────────────────
  static const Map<String, String> temasPorId = {
    'idtema_001': 'MIP - ENFERMEDADES',
    'idtema_002': 'MIP - PLAGAS',
    'idtema_003': 'NUTRICIÓN Y FERTILIZACIÓN',
    'idtema_004': 'PODAS',
    'idtema_005': 'COSECHA Y POSTCOSECHA',
    'idtema_006': 'COMERCIALIZACIÓN',
    'idtema_007': 'INSTALACIÓN DEL CULTIVO',
    'idtema_010': 'MANEJO Y ADECUACIÓN AMBIENTAL',
    'idtema_011': 'DIAGNÓSTICO PARTICIPATIVO',
    'idtema_012': 'SISTEMA AGROFORESTAL',
    'idtema_013': 'SUELOS Y COMPOSTAJE',
  };

  static List<String> get temasLabel =>
      temasPorId.values.toList()..sort();

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
