// ─────────────────────────────────────────────────────────────────────────────
// PTA CATALOG — Plan de Trabajo Anual CAFÉ 2026
// Fuente: mg_pta_cafe (Firestore) / mg_pta_cafe.AppSheet.ViewData.2026-05-13.csv
//
// Estrategia offline-first: los datos del PTA se incrustan aquí como
// constantes estáticas. Firestore (mg_pta_cafe) se usa para reporting y sync.
// No se necesita una llamada de red para renderizar los formularios.
// ─────────────────────────────────────────────────────────────────────────────

class PtaEntry {
  final String idPta;
  final String codigo;
  final String indicadoresTareas;
  final String unidadMedida;

  /// 'a. Capacitación' | 'b. Asistencia técnica' | 'Actividades complementarias' | ''
  final String modalidad;

  /// true = aparece en los selectores de Tarea (es accionable/registrable)
  final bool esHoja;

  /// Código de nivel 1: '1' | '2' | '3' | '4' | '5' | '6'
  final String codigoRaiz;

  /// Meta programada para todo el año
  final int metaAnual;

  const PtaEntry({
    required this.idPta,
    required this.codigo,
    required this.indicadoresTareas,
    this.unidadMedida = '',
    this.modalidad = '',
    this.esHoja = false,
    required this.codigoRaiz,
    this.metaAnual = 0,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
class PtaCatalog {
  // ── TODAS LAS ENTRADAS (headers + subheaders + hojas) ─────────────────────
  static const List<PtaEntry> todas = [
    // ══════════════════════════════════════════════════════════════════════════
    // 1. PLANIFICACION Y ORGANIZACIÓN
    // ══════════════════════════════════════════════════════════════════════════
    PtaEntry(
      idPta: 'idpta006',
      codigo: '1',
      indicadoresTareas: '1.PLANIFICACION Y ORGANIZACIÓN',
      esHoja: false,
      codigoRaiz: '1',
    ),
    PtaEntry(
      idPta: 'idpta008',
      codigo: '1.1.1',
      indicadoresTareas: '1.1.1.Inducción al personal técnico',
      unidadMedida: 'Persona capacitada',
      esHoja: true,
      codigoRaiz: '1',
      metaAnual: 52,
    ),
    PtaEntry(
      idPta: 'idpta009',
      codigo: '1.1.2',
      indicadoresTareas:
          '1.1.2.Reuniones técnicas con instituciones vinculadas con la innovación',
      unidadMedida: 'Informe',
      esHoja: true,
      codigoRaiz: '1',
      metaAnual: 2,
    ),
    PtaEntry(
      idPta: 'idpta011',
      codigo: '1.2.1',
      indicadoresTareas:
          '1.2.1.Identificación/selección de zonas con aptitud productiva',
      unidadMedida: 'Informe',
      esHoja: true,
      codigoRaiz: '1',
      metaAnual: 7,
    ),
    PtaEntry(
      idPta: 'idpta012',
      codigo: '1.2.2',
      indicadoresTareas:
          '1.2.2.Reuniones de motivación y socialización con autoridades comunales',
      unidadMedida: 'Acta',
      modalidad: 'a. Capacitación',
      esHoja: true,
      codigoRaiz: '1',
      metaAnual: 7,
    ),
    PtaEntry(
      idPta: 'idpta014',
      codigo: '1.3.1',
      indicadoresTareas: '1.3.1.Prospección de campo',
      unidadMedida: 'Informe',
      esHoja: true,
      codigoRaiz: '1',
      metaAnual: 7,
    ),
    PtaEntry(
      idPta: 'idpta015',
      codigo: '1.3.2',
      indicadoresTareas:
          '1.3.2.Informe de Compatibilidad de la actividad a SERNANP y/o SERFOR',
      unidadMedida: 'Informe',
      esHoja: true,
      codigoRaiz: '1',
      metaAnual: 1,
    ),
    PtaEntry(
      idPta: 'idpta016',
      codigo: '1.3.3',
      indicadoresTareas: '1.3.3.Diagnóstico participativo',
      unidadMedida: 'Informe',
      modalidad: 'a. Capacitación',
      esHoja: true,
      codigoRaiz: '1',
      metaAnual: 55,
    ),
    PtaEntry(
      idPta: 'idpta017',
      codigo: '1.3.4',
      indicadoresTareas:
          '1.3.4.Establecimiento de alianzas estratégicas con entidades públicas y privadas',
      unidadMedida: 'Acta',
      esHoja: true,
      codigoRaiz: '1',
      metaAnual: 2,
    ),
    PtaEntry(
      idPta: 'idpta018',
      codigo: '1.3.5',
      indicadoresTareas:
          '1.3.5.Conformación y/o consolidación de comités fitosanitarios',
      unidadMedida: 'Comité fitosanitario',
      modalidad: 'a. Capacitación',
      esHoja: true,
      codigoRaiz: '1',
      metaAnual: 55,
    ),
    PtaEntry(
      idPta: 'idpta020',
      codigo: '1.4.1',
      indicadoresTareas: '1.4.1.Selección de los participantes',
      unidadMedida: 'Documento',
      esHoja: true,
      codigoRaiz: '1',
      metaAnual: 7,
    ),
    PtaEntry(
      idPta: 'idpta021',
      codigo: '1.4.2',
      indicadoresTareas:
          '1.4.2.Organización de las metodologías para el servicio de extensión',
      unidadMedida: 'Documento',
      esHoja: true,
      codigoRaiz: '1',
      metaAnual: 1,
    ),

    // ══════════════════════════════════════════════════════════════════════════
    // 2. EJECUCION
    // ══════════════════════════════════════════════════════════════════════════
    PtaEntry(
      idPta: 'idpta022',
      codigo: '2',
      indicadoresTareas: '2.EJECUCION',
      esHoja: false,
      codigoRaiz: '2',
    ),
    // ── 2.1.1 Capacitación ───────────────────────────────────────────────────
    PtaEntry(
      idPta: 'idpta025',
      codigo: '2.1.1.1',
      indicadoresTareas: '2.1.1.1.Escuela de Campo para Agricultores (ECA)',
      unidadMedida: 'Persona capacitada',
      modalidad: 'a. Capacitación',
      esHoja: true,
      codigoRaiz: '2',
      metaAnual: 1050,
    ),
    PtaEntry(
      idPta: 'idpta026',
      codigo: '2.1.1.2',
      indicadoresTareas:
          '2.1.1.2.Instalación y manejo de Parcela demostrativa',
      unidadMedida: 'Parcela demostrativa',
      modalidad: 'b. Asistencia técnica',
      esHoja: true,
      codigoRaiz: '2',
      metaAnual: 37,
    ),
    PtaEntry(
      idPta: 'idpta027',
      codigo: '2.1.1.3',
      indicadoresTareas:
          '2.1.1.3.Implementación de módulos demostrativos de Innovación',
      unidadMedida: 'Módulo demostrativo',
      modalidad: 'b. Asistencia técnica',
      esHoja: true,
      codigoRaiz: '2',
      metaAnual: 2,
    ),
    PtaEntry(
      idPta: 'idpta028',
      codigo: '2.1.1.4',
      indicadoresTareas: '2.1.1.4.Días de campo',
      unidadMedida: 'Evento',
      modalidad: 'a. Capacitación',
      esHoja: true,
      codigoRaiz: '2',
      metaAnual: 4,
    ),
    PtaEntry(
      idPta: 'idpta029',
      codigo: '2.1.1.5',
      indicadoresTareas: '2.1.1.5.Encuentros Técnicos de productores',
      unidadMedida: 'Evento',
      modalidad: 'a. Capacitación',
      esHoja: true,
      codigoRaiz: '2',
      metaAnual: 2,
    ),
    PtaEntry(
      idPta: 'idpta030',
      codigo: '2.1.1.6',
      indicadoresTareas: '2.1.1.6.Pasantías',
      unidadMedida: 'Evento',
      modalidad: 'a. Capacitación',
      esHoja: true,
      codigoRaiz: '2',
      metaAnual: 2,
    ),
    PtaEntry(
      idPta: 'idpta031',
      codigo: '2.1.1.7',
      indicadoresTareas: '2.1.1.7.Capacitación Técnica Grupal (CTG)',
      unidadMedida: 'Persona capacitada',
      modalidad: 'a. Capacitación',
      esHoja: true,
      codigoRaiz: '2',
      metaAnual: 800,
    ),
    // ── 2.1.2 Asistencia Técnica ─────────────────────────────────────────────
    PtaEntry(
      idPta: 'idpta033',
      codigo: '2.1.2.1',
      indicadoresTareas:
          '2.1.2.1.Visitas de Asistencia Técnica Personalizada (VTP)',
      unidadMedida: 'Visita Técnica',
      modalidad: 'b. Asistencia técnica',
      esHoja: true,
      codigoRaiz: '2',
      metaAnual: 17575,
    ),
    PtaEntry(
      idPta: 'idpta034',
      codigo: '2.1.2.4',
      indicadoresTareas:
          '2.1.2.4.Asistencia Técnica en Mantenimiento de Áreas en Producción',
      unidadMedida: 'ha',
      esHoja: true,
      codigoRaiz: '2',
      metaAnual: 1850,
    ),
    PtaEntry(
      idPta: 'idpta035',
      codigo: '2.1.2.5',
      indicadoresTareas:
          '2.1.2.5.AT en producción de Abonos Orgánicos sostenibles (biofertilizantes y compost)',
      unidadMedida: 'Módulo familiar',
      esHoja: true,
      codigoRaiz: '2',
      metaAnual: 185,
    ),
    PtaEntry(
      idPta: 'idpta036',
      codigo: '2.1.2.6',
      indicadoresTareas:
          '2.1.2.6.AT para la Gestión de plagas — mapeo mensual',
      unidadMedida: 'Informe',
      esHoja: true,
      codigoRaiz: '2',
      metaAnual: 10,
    ),
    PtaEntry(
      idPta: 'idpta037',
      codigo: '2.1.2.7',
      indicadoresTareas:
          '2.1.2.7.AT mediante la ejecución de Campañas fitosanitarias',
      unidadMedida: 'Campaña',
      modalidad: 'a. Capacitación',
      esHoja: true,
      codigoRaiz: '2',
      metaAnual: 110,
    ),
    PtaEntry(
      idPta: 'idpta038',
      codigo: '2.1.2.8',
      indicadoresTareas:
          '2.1.2.8.AT en Mejoramiento de prácticas de Cosecha y Post cosecha',
      unidadMedida: 'Módulo',
      modalidad: 'a. Capacitación',
      esHoja: true,
      codigoRaiz: '2',
      metaAnual: 185,
    ),
    PtaEntry(
      idPta: 'idpta039',
      codigo: '2.1.2.9',
      indicadoresTareas:
          '2.1.2.9.AT para la implementación de módulos Post Cosecha',
      unidadMedida: 'Módulo',
      modalidad: 'b. Asistencia técnica',
      esHoja: true,
      codigoRaiz: '2',
      metaAnual: 75,
    ),
    PtaEntry(
      idPta: 'idpta040',
      codigo: '2.1.2.10',
      indicadoresTareas:
          '2.1.2.10.Visitas de AT Personalizada en Post Cosecha (VATPP)',
      unidadMedida: 'Visita técnica',
      modalidad: 'b. Asistencia técnica',
      esHoja: true,
      codigoRaiz: '2',
      metaAnual: 810,
    ),
    PtaEntry(
      idPta: 'idpta041',
      codigo: '2.1.2.11',
      indicadoresTareas:
          '2.1.2.11.Mapeo y evaluación de la calidad final del grano',
      unidadMedida: 'Informe',
      esHoja: true,
      codigoRaiz: '2',
      metaAnual: 6,
    ),
    PtaEntry(
      idPta: 'idpta042',
      codigo: '2.1.2.12',
      indicadoresTareas: '2.1.2.12.Participación en eventos de ferias',
      unidadMedida: 'Eventos',
      esHoja: true,
      codigoRaiz: '2',
      metaAnual: 1,
    ),

    // ══════════════════════════════════════════════════════════════════════════
    // 3. MANEJO SOSTENIBLE DEL MEDIO AMBIENTE
    // ══════════════════════════════════════════════════════════════════════════
    PtaEntry(
      idPta: 'idpta043',
      codigo: '3',
      indicadoresTareas: '3.MANEJO SOSTENIBLE DEL MEDIO AMBIENTE',
      esHoja: false,
      codigoRaiz: '3',
    ),
    PtaEntry(
      idPta: 'idpta044',
      codigo: '3.1',
      indicadoresTareas:
          '3.1.Instalación y manejo de módulos de acopio temporal de residuos sólidos',
      unidadMedida: 'Módulo',
      modalidad: 'a. Capacitación',
      esHoja: true,
      codigoRaiz: '3',
      metaAnual: 9,
    ),
    PtaEntry(
      idPta: 'idpta046',
      codigo: '3.5.1',
      indicadoresTareas:
          '3.5.1.Piloto de evaluación y gestión territorial de venta de bonos de carbono',
      unidadMedida: 'Informe',
      esHoja: true,
      codigoRaiz: '3',
      metaAnual: 0,
    ),
    PtaEntry(
      idPta: 'idpta047',
      codigo: '3.5.2',
      indicadoresTareas:
          '3.5.2.Georreferenciación de parcelas (polígono) por cultivo/familia',
      unidadMedida: 'Polígono',
      esHoja: true,
      codigoRaiz: '3',
      metaAnual: 980,
    ),
    PtaEntry(
      idPta: 'idpta048',
      codigo: '3.5.3',
      indicadoresTareas:
          '3.5.3.Registro y gestión de la información de trazabilidad',
      unidadMedida: 'Registro',
      esHoja: true,
      codigoRaiz: '3',
      metaAnual: 2324,
    ),
    PtaEntry(
      idPta: 'idpta049',
      codigo: '3.6',
      indicadoresTareas: '3.6.Campaña de sensibilización ambiental',
      unidadMedida: 'Evento',
      modalidad: 'a. Capacitación',
      esHoja: true,
      codigoRaiz: '3',
      metaAnual: 15,
    ),

    // ══════════════════════════════════════════════════════════════════════════
    // 4. CERTIFICACIÓN DE COMPETENCIAS LABORALES
    // ══════════════════════════════════════════════════════════════════════════
    PtaEntry(
      idPta: 'idpta050',
      codigo: '4',
      indicadoresTareas: '4.CERTIFICACIÓN DE COMPETENCIAS LABORALES',
      esHoja: false,
      codigoRaiz: '4',
    ),
    PtaEntry(
      idPta: 'idpta051',
      codigo: '4.1',
      indicadoresTareas:
          '4.1.Desarrollo o fortalecimiento en certificación de competencias laborales',
      unidadMedida: 'Personas evaluadas',
      esHoja: true,
      codigoRaiz: '4',
      metaAnual: 0,
    ),

    // ══════════════════════════════════════════════════════════════════════════
    // 5. SUPERVISION
    // ══════════════════════════════════════════════════════════════════════════
    PtaEntry(
      idPta: 'idpta052',
      codigo: '5',
      indicadoresTareas: '5.SUPERVISION',
      esHoja: false,
      codigoRaiz: '5',
    ),
    PtaEntry(
      idPta: 'idpta053',
      codigo: '5.1',
      indicadoresTareas: '5.1.Supervisión Técnica y físico-financiera',
      unidadMedida: 'Informe',
      esHoja: true,
      codigoRaiz: '5',
      metaAnual: 20,
    ),
    PtaEntry(
      idPta: 'idpta054',
      codigo: '5.2',
      indicadoresTareas: '5.2.Supervisión y/o Inspección Ambiental',
      unidadMedida: 'Informe',
      esHoja: true,
      codigoRaiz: '5',
      metaAnual: 2,
    ),

    // ══════════════════════════════════════════════════════════════════════════
    // 6. ACTIVIDADES COMPLEMENTARIAS (es header Y hoja a la vez)
    // ══════════════════════════════════════════════════════════════════════════
    PtaEntry(
      idPta: 'idpta055',
      codigo: '6',
      indicadoresTareas: '6.Actividades complementarias',
      unidadMedida: 'Actividades complementarias',
      modalidad: 'Actividades complementarias',
      esHoja: true,
      codigoRaiz: '6',
    ),
  ];

  // ── SELECTORES ─────────────────────────────────────────────────────────────

  /// Las 6 secciones de nivel superior — para el dropdown "Código" en FAT y Plan.
  static List<PtaEntry> get topLevelEntries =>
      todas.where((e) => e.codigo == e.codigoRaiz).toList();

  /// Hojas bajo un [codigoRaiz] dado, opcionalmente filtradas por [modalidad].
  ///
  /// Reglas de filtrado:
  /// - `null` / vacío → devuelve TODAS las hojas bajo el código (usado en Plan).
  /// - `'Actividades complementarias'` → devuelve solo el código 6.
  /// - `'a. Capacitación'` o `'b. Asistencia técnica'` → incluye las que
  ///   coinciden con la modalidad seleccionada MÁS las que no tienen modalidad
  ///   asignada (campo vacío), porque son neutrales.
  static List<PtaEntry> leafEntriesUnderCode(
    String codigoRaiz, {
    String? modalidad,
  }) {
    return todas.where((e) {
      if (e.codigoRaiz != codigoRaiz) return false;
      if (!e.esHoja) return false;
      if (modalidad == null || modalidad.isEmpty) return true;
      if (modalidad == 'Actividades complementarias') {
        return codigoRaiz == '6';
      }
      return e.modalidad == modalidad || e.modalidad.isEmpty;
    }).toList();
  }

  /// Todas las hojas del catálogo (para búsqueda sin filtro).
  static List<PtaEntry> get todasLasHojas =>
      todas.where((e) => e.esHoja).toList();

  // ── UTILIDADES ─────────────────────────────────────────────────────────────
  //
  // IDENTIFICADOR CANÓNICO = `codigo` del PTA ('1.1.1', '2.1.2.1', '6', ...)
  //
  // RETROCOMPATIBILIDAD: Registros anteriores en SQLite/Firestore guardaban
  // el campo idPta como 'idpta033'. Todos los métodos aceptan AMBOS formatos
  // para no romper datos ya persistidos.

  /// true si el valor parece un `codigo` canónico (comienza con dígito).
  static bool _esCodigo(String s) =>
      s.isNotEmpty && RegExp(r'^\d').hasMatch(s);

  /// Devuelve `indicadoresTareas` dado un [codigo] canónico O un legacy idPta.
  static String labelFromIdPta(String valor) {
    for (final e in todas) {
      if (e.codigo == valor || e.idPta == valor) return e.indicadoresTareas;
    }
    return valor; // fallback: muestra el valor crudo
  }

  /// Devuelve el `codigoRaiz` dado un [codigo] canónico O un legacy idPta.
  static String? codigoRaizFromIdPta(String valor) {
    if (_esCodigo(valor)) {
      // Formato canónico: '2.1.2.1' → primer segmento = '2'
      return valor.split('.').first;
    }
    // Formato legacy: buscar en el catálogo por idPta
    for (final e in todas) {
      if (e.idPta == valor) return e.codigoRaiz;
    }
    return null;
  }

  /// Devuelve la [PtaEntry] dado un [codigo] canónico O un legacy idPta.
  static PtaEntry? entryFromIdPta(String valor) {
    for (final e in todas) {
      if (e.codigo == valor || e.idPta == valor) return e;
    }
    return null;
  }

  /// Convierte cualquier referencia (legacy idptaXXX o codigo) al `codigo`
  /// canónico. Si no hay coincidencia, devuelve el valor original.
  static String normalizarACodigo(String valor) {
    for (final e in todas) {
      if (e.idPta == valor || e.codigo == valor) return e.codigo;
    }
    return valor;
  }

  /// Mapa codigo → indicadoresTareas.
  /// Incluye alias legacy (idptaXXX) para retrocompatibilidad con código
  /// que todavía use CatalogData.tareasPorId.
  static Map<String, String> get ptaPorId => {
        for (final e in todas) e.codigo: e.indicadoresTareas,
        // Alias legacy — se sobreescribe si hay colisión (no la hay):
        for (final e in todas) e.idPta: e.indicadoresTareas,
      };
}
