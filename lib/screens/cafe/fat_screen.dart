import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/app_colors.dart';
import '../../core/catalog.dart';
import '../../models/fat.dart';
import '../../providers/fat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/usuario_model.dart';
import '../../widgets/form_widgets.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// LISTA DE FATs
// ═══════════════════════════════════════════════════════════════════════════════
class FatListScreen extends StatefulWidget {
  const FatListScreen({super.key});

  @override
  State<FatListScreen> createState() => _FatListScreenState();
}

class _FatListScreenState extends State<FatListScreen> {
  String? _filtroEstado;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final usuario = context.read<SesionProvider>().usuario;
      context.read<FatProvider>().cargarFats(usuario: usuario?.dni);
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<FatProvider>();
    final usuario = context.read<SesionProvider>().usuario;
    final fats = _filtroEstado == null
        ? prov.fats
        : prov.fats.where((f) => f.estado == _filtroEstado).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('FAT — Fichas de Asistencia',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) => setState(() => _filtroEstado = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('Todos')),
              ...CatalogData.estadosFat.map((e) =>
                  PopupMenuItem(value: e, child: Text(e))),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nueva FAT',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FatFormScreen()),
            ).then((_) =>
                prov.cargarFats(usuario: usuario?.dni)),
          ),
        ],
      ),
      body: prov.cargando
          ? const Center(child: CircularProgressIndicator())
          : fats.isEmpty
              ? _buildEmpty(context, prov, usuario)
              : Column(
                  children: [
                    _buildSummary(prov),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: fats.length,
                        itemBuilder: (ctx, i) => _FatCard(
                          fat: fats[i],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    FatFormScreen(fatExistente: fats[i])),
                          ).then((_) =>
                              prov.cargarFats(usuario: usuario?.dni)),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmpty(
      BuildContext context, FatProvider prov, UsuarioModel? usuario) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('Sin fichas FAT registradas',
              style:
                  TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FatFormScreen()),
            ).then((_) => prov.cargarFats(usuario: usuario?.dni)),
            icon: const Icon(Icons.add),
            label: const Text('Nueva FAT'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(FatProvider prov) {
    final counts = prov.countByEstado();
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: CatalogData.estadosFat.map((e) {
          final n = counts[e] ?? 0;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Text('$n',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.primary)),
                  Text(e,
                      style: const TextStyle(
                          fontSize: 8,
                          color: AppColors.textSecondary),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FatCard extends StatelessWidget {
  final Fat fat;
  final VoidCallback onTap;
  const _FatCard({required this.fat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      fat.nroFat.isNotEmpty
                          ? fat.nroFat
                          : fat.id.substring(0, 8),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary),
                    ),
                  ),
                  EstadoBadge(fat.estado),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${fat.comunidad} · ${fat.distrito}',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(fat.fechaFormateada,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(width: 12),
                  Icon(Icons.category,
                      size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      CatalogData.labelFromIdTema(fat.idTema),
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                fat.modalidad,
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.accentBlue,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FORMULARIO FAT — 4 páginas
// ═══════════════════════════════════════════════════════════════════════════════
class FatFormScreen extends StatefulWidget {
  final Fat? fatExistente;
  const FatFormScreen({super.key, this.fatExistente});

  @override
  State<FatFormScreen> createState() => _FatFormScreenState();
}

class _FatFormScreenState extends State<FatFormScreen> {
  int _page = 0;
  static const int _totalPages = 4;

  // ── Datos comunes ──────────────────────────────────────────────────────────
  late String _id;
  late String _nroFat;
  late DateTime _fecha;
  late String _mes;

  // ── Página 1: Identificación ───────────────────────────────────────────────
  String _modalidad = CatalogData.modalidades[1];
  String _etapa = 'Producción';
  String? _idPta;
  String? _idTema;
  String? _ubicacion;

  // ── Página 2: Ubicación ────────────────────────────────────────────────────
  String _provincia = CatalogData.provincias.last; // LA CONVENCION
  String _distrito = CatalogData.distritosPorProvincia[
          CatalogData.provincias.last]!.first;
  String? _comunidad;
  String _horaInicio = '08:00';
  String _horaFinal = '12:00';
  String _clima = CatalogData.climas.first;
  String _incidencia = CatalogData.incidencias.first;

  // ── Página 3: Responsable/Beneficiario ─────────────────────────────────────
  String _organizacion = CatalogData.organizaciones.first;

  // ── Página 4: Desarrollo ──────────────────────────────────────────────────
  final _actCtrl = TextEditingController();
  final _resCtrl = TextEditingController();
  final _acuCtrl = TextEditingController();
  final _recCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  DateTime _proximaVisita =
      DateTime.now().add(const Duration(days: 30));
  String? _idTemaProxima;
  String? _firmaSocio;
  String? _foto1;
  final _foto1DescCtrl = TextEditingController();
  String? _foto2;
  final _foto2DescCtrl = TextEditingController();
  String? _foto3;
  final _foto3DescCtrl = TextEditingController();
  final List<SocioParticipante> _socios = [];

  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final f = widget.fatExistente;
    _id = f?.id ?? const Uuid().v4().toUpperCase();
    _mes = f?.mes ?? CatalogData.meses[DateTime.now().month - 1];
    _fecha = f?.fechaAsistencia ?? DateTime.now();

    if (f != null) {
      _nroFat = f.nroFat;
      _modalidad = f.modalidad;
      _etapa = f.etapaCrianza;
      _idPta = f.idPta;
      _idTema = f.idTema;
      _ubicacion = f.ubicacion;
      _provincia = f.provincia;
      _distrito = f.distrito;
      _comunidad = f.comunidad;
      _horaInicio = f.horaInicio;
      _horaFinal = f.horaFinal;
      _clima = f.clima;
      _incidencia = f.incidencia;
      _organizacion = f.organizacionProductores;
      _actCtrl.text = f.actividadesRealizadas;
      _resCtrl.text = f.resultados;
      _acuCtrl.text = f.acuerdosCompromisos;
      _recCtrl.text = f.recomendaciones;
      _obsCtrl.text = f.observaciones;
      _proximaVisita = f.proximaVisita;
      _idTemaProxima = f.proximaVisitaTema.isEmpty ? null : f.proximaVisitaTema;
      _firmaSocio = f.firmaSocio;
      _foto1 = f.fotografia1;
      _foto1DescCtrl.text = f.foto1Descripcion;
      _foto2 = f.fotografia2;
      _foto2DescCtrl.text = f.foto2Descripcion;
      _foto3 = f.fotografia3;
      _foto3DescCtrl.text = f.foto3Descripcion;
    } else {
      final usuario = context.read<SesionProvider>().usuario;
      _nroFat = '${usuario?.dni ?? '00000000'}-118-1';
    }
  }

  @override
  void dispose() {
    _actCtrl.dispose(); _resCtrl.dispose(); _acuCtrl.dispose();
    _recCtrl.dispose(); _obsCtrl.dispose();
    _foto1DescCtrl.dispose(); _foto2DescCtrl.dispose(); _foto3DescCtrl.dispose();
    super.dispose();
  }

  // ── Obtener GPS ────────────────────────────────────────────────────────────
  Future<void> _getGps() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Activa el GPS del dispositivo');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _ubicacion =
            '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
      });
    } catch (e) {
      _showSnack('Error al obtener GPS: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Guardar FAT ────────────────────────────────────────────────────────────
  Future<void> _save() async {
    // Validaciones mínimas
    if (_idPta == null || _idTema == null || _comunidad == null) {
      _showSnack('Complete: Tarea, Tema y Comunidad (obligatorios)');
      return;
    }

    setState(() => _guardando = true);
    final usuario = context.read<SesionProvider>().usuario;

    final fat = Fat(
      id: _id,
      nroFat: _nroFat,
      fechaCreacion: widget.fatExistente?.fechaCreacion ?? DateTime.now(),
      fechaAsistencia: _fecha,
      modalidad: _modalidad,
      etapaCrianza: _etapa,
      idPta: _idPta!,
      idTema: _idTema!,
      provincia: _provincia,
      distrito: _distrito,
      comunidad: _comunidad!,
      ubicacion: _ubicacion,
      horaInicio: _horaInicio,
      horaFinal: _horaFinal,
      clima: _clima,
      incidencia: _incidencia,
      idTecEspExt: usuario?.idTecEspExt ?? '',
      nombreTecnico: usuario?.nombreCompleto ?? '',
      idCargo: usuario?.idCargo ?? '',
      cargo: usuario?.cargo ?? '',
      organizacionProductores: _organizacion,
      idSocio: '',
      nroSociosParticipantes: _socios.length,
      actividadesRealizadas: _actCtrl.text,
      resultados: _resCtrl.text,
      acuerdosCompromisos: _acuCtrl.text,
      recomendaciones: _recCtrl.text,
      observaciones: _obsCtrl.text,
      proximaVisita: _proximaVisita,
      proximaVisitaTema: _idTemaProxima ?? '',
      firmaSocio: _firmaSocio,
      fotografia1: _foto1,
      foto1Descripcion: _foto1DescCtrl.text,
      fotografia2: _foto2,
      foto2Descripcion: _foto2DescCtrl.text,
      fotografia3: _foto3,
      foto3Descripcion: _foto3DescCtrl.text,
      estado: widget.fatExistente?.estado ?? 'REGISTRADO',
      usuario: usuario?.dni ?? '',
      mes: _mes,
    );

    final prov = context.read<FatProvider>();
    bool ok;
    if (widget.fatExistente == null) {
      ok = await prov.guardarFat(fat, socios: _socios);
    } else {
      ok = await prov.actualizarFat(fat, socios: _socios);
    }

    setState(() => _guardando = false);
    if (!mounted) return;
    if (ok) {
      _showSnack('FAT guardada correctamente');
      Navigator.pop(context);
    } else {
      _showSnack('Error al guardar: ${prov.error}');
    }
  }

  void _next() {
    if (_page < _totalPages - 1) setState(() => _page++);
  }

  void _prev() {
    if (_page > 0) setState(() => _page--);
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isLast = _page == _totalPages - 1;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context)),
        title: const Text('4Cafe.FAT'),
        actions: [
          if (_page > 0)
            TextButton(
                onPressed: _prev,
                child: const Text('◄ Anterior',
                    style: TextStyle(color: Colors.white70))),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white70))),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _guardando
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)))
                : ElevatedButton(
                    onPressed: isLast ? _save : _next,
                    child: Text(isLast ? 'Guardar' : 'Siguiente ►')),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: PageIndicator(
                current: _page + 1, total: _totalPages),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: [
                _buildPage1(),
                _buildPage2(),
                _buildPage3(),
                _buildPage4(),
              ][_page],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PÁGINA 1 — Identificación
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildPage1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // GPS
        GpsField(ubicacion: _ubicacion, onGetGps: _getGps),
        const SizedBox(height: 14),

        const FieldLabel('Número de Ficha'),
        ReadOnlyField(_nroFat),
        const SizedBox(height: 14),

        const FieldLabel('Fecha de asistencia', required: true),
        DatePickerField(
            value: _fecha,
            onChanged: (d) => setState(() {
                  _fecha = d;
                  _mes = CatalogData.meses[d.month - 1];
                })),
        const SizedBox(height: 20),

        const SectionTitle('1. Identificación de la intervención'),
        const SizedBox(height: 12),

        const FieldLabel('Modalidad: ECA / CTG / VTP', required: true),
        DropdownButtonFormField<String>(
          value: _modalidad,
          decoration: const InputDecoration(),
          items: CatalogData.modalidades
              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
              .toList(),
          onChanged: (v) => setState(() => _modalidad = v!),
        ),
        const SizedBox(height: 14),

        const FieldLabel('Etapa del cultivo', required: true),
        DropdownButtonFormField<String>(
          value: _etapa,
          decoration: const InputDecoration(),
          items: CatalogData.etapas
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => setState(() => _etapa = v!),
        ),
        const SizedBox(height: 14),

        const FieldLabel('Tarea / Actividad', required: true),
        DropdownButtonFormField<String>(
          value: _idPta,
          decoration:
              const InputDecoration(hintText: 'Seleccionar...'),
          items: CatalogData.tareasPorId.entries
              .map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value,
                      overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) => setState(() => _idPta = v),
        ),
        const SizedBox(height: 14),

        const FieldLabel('Tema', required: true),
        DropdownButtonFormField<String>(
          value: _idTema,
          decoration:
              const InputDecoration(hintText: 'Seleccionar...'),
          items: CatalogData.temasPorId.entries
              .map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value)))
              .toList(),
          onChanged: (v) => setState(() => _idTema = v),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PÁGINA 2 — Ubicación
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildPage2() {
    final distritos =
        CatalogData.distritosPorProvincia[_provincia] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('2. Ubicación'),
        const SizedBox(height: 12),

        const FieldLabel('Provincia', required: true),
        ChipSelector(
          options: CatalogData.provincias,
          selected: _provincia,
          onSelected: (v) => setState(() {
            _provincia = v;
            _distrito =
                CatalogData.distritosPorProvincia[v]!.first;
            _comunidad = null;
          }),
        ),
        const SizedBox(height: 14),

        const FieldLabel('Distrito', required: true),
        DropdownButtonFormField<String>(
          value: distritos.contains(_distrito)
              ? _distrito
              : distritos.first,
          decoration: const InputDecoration(),
          items: distritos
              .map((d) =>
                  DropdownMenuItem(value: d, child: Text(d)))
              .toList(),
          onChanged: (v) => setState(() => _distrito = v!),
        ),
        const SizedBox(height: 14),

        const FieldLabel('Comunidad / Sector', required: true),
        DropdownButtonFormField<String>(
          value: _comunidad,
          decoration:
              const InputDecoration(hintText: 'Seleccionar...'),
          items: CatalogData.comunidades
              .map((c) =>
                  DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _comunidad = v),
        ),
        const SizedBox(height: 14),

        const FieldLabel('Hora de inicio', required: true),
        TimePickerField(
            value: _horaInicio,
            onChanged: (t) => setState(() => _horaInicio = t)),
        const SizedBox(height: 14),

        const FieldLabel('Hora de finalización', required: true),
        TimePickerField(
            value: _horaFinal,
            onChanged: (t) => setState(() => _horaFinal = t)),
        const SizedBox(height: 14),

        const FieldLabel('Clima', required: true),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CatalogData.climas
              .map((c) => SelectableChip(
                    label: c,
                    selected: _clima == c,
                    onTap: () => setState(() => _clima = c),
                  ))
              .toList(),
        ),
        const SizedBox(height: 14),

        const FieldLabel('Incidencia', required: true),
        StackedOptionList(
          options: CatalogData.incidencias,
          selected: _incidencia,
          onSelected: (v) => setState(() => _incidencia = v),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PÁGINA 3 — Responsable / Beneficiario
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildPage3() {
    final usuario = context.read<SesionProvider>().usuario;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('3. Responsable(s)'),
        const SizedBox(height: 12),

        const FieldLabel('Técnico / Extensionista responsable'),
        ReadOnlyField(
          usuario?.nombreCompleto ?? '',
          color: AppColors.accentBlue,
        ),
        const SizedBox(height: 10),

        const FieldLabel('Cargo / Rol'),
        ReadOnlyField(
          usuario?.cargo ?? '',
          color: AppColors.accentBlue,
        ),
        const SizedBox(height: 20),

        const SectionTitle(
            '4. Beneficiario / Participantes\n'
            '(Para VTP: 1 productor. Para ECA/CTG: adjuntar lista)'),
        const SizedBox(height: 12),

        const FieldLabel(
            'Organización de productores\n'
            '(Consignar la AEO, sino: SIN ORGANIZACIÓN)'),
        DropdownButtonFormField<String>(
          value: _organizacion,
          decoration: const InputDecoration(),
          items: CatalogData.organizaciones
              .map((o) =>
                  DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) =>
              setState(() => _organizacion = v!),
        ),
        const SizedBox(height: 20),

        const SectionTitle(
            'ANEXO 2. Lista de participantes (Obligatorio ECA/CTG)'),
        const SizedBox(height: 10),
        _buildSociosList(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSociosList() {
    return Column(
      children: [
        ..._socios.asMap().entries.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle),
                    child: Center(
                      child: Text('${e.key + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.value.nombreCompleto,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        Text('DNI: ${e.value.dni}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.danger, size: 18),
                      onPressed: () =>
                          setState(() => _socios.removeAt(e.key))),
                ],
              ),
            )),
        GestureDetector(
          onTap: _addSocio,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.accentBlue, width: 1.5),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add,
                    color: AppColors.accentBlue, size: 16),
                SizedBox(width: 6),
                Text('Agregar participante',
                    style: TextStyle(
                        color: AppColors.accentBlue,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _addSocio() {
    final dniCtrl = TextEditingController();
    final nombreCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuevo participante'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dniCtrl,
              decoration: const InputDecoration(
                  labelText: 'DNI', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              maxLength: 8,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  border: OutlineInputBorder()),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (dniCtrl.text.length == 8) {
                final usuario =
                    context.read<SesionProvider>().usuario;
                setState(() => _socios.add(SocioParticipante(
                      id: const Uuid().v4().substring(0, 8),
                      idFat: _id,
                      idSocio: 'id_so_manual',
                      dni: dniCtrl.text,
                      nombreCompleto:
                          nombreCtrl.text.toUpperCase(),
                      mes: _mes,
                      usuario: usuario?.dni ?? '',
                    )));
              }
              Navigator.pop(context);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PÁGINA 4 — Desarrollo, firmas y fotos
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildPage4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
            '5. Desarrollo, resultados y acuerdos\n'
            '(Registre lo que realmente realizó)'),
        const SizedBox(height: 12),

        const FieldLabel('Actividades realizadas (resumen)'),
        TextFormField(
            controller: _actCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
                hintText: 'Describa las actividades...')),
        const SizedBox(height: 14),

        const FieldLabel(
            'Resultados / aprendizajes clave\n'
            '(Ej: El productor identificó la plaga X y aplican MIP)'),
        TextFormField(controller: _resCtrl, maxLines: 3),
        const SizedBox(height: 14),

        const FieldLabel(
            'Acuerdos y compromisos\n'
            '(Ej: Realizar poda sanitaria antes de la próxima visita)'),
        TextFormField(controller: _acuCtrl, maxLines: 3),
        const SizedBox(height: 20),

        const SectionTitle(
            '6. Recomendaciones, próxima visita y observaciones'),
        const SizedBox(height: 12),

        const FieldLabel('Recomendaciones técnicas'),
        TextFormField(controller: _recCtrl, maxLines: 2),
        const SizedBox(height: 14),

        const FieldLabel('Próxima visita', required: true),
        DatePickerField(
            value: _proximaVisita,
            onChanged: (d) =>
                setState(() => _proximaVisita = d)),
        const SizedBox(height: 14),

        const FieldLabel('Tema para próxima visita'),
        DropdownButtonFormField<String>(
          value: _idTemaProxima,
          decoration: const InputDecoration(hintText: 'Seleccionar...'),
          items: [
            const DropdownMenuItem(value: null, child: Text('—')),
            ...CatalogData.temasPorId.entries.map((e) =>
                DropdownMenuItem(value: e.key, child: Text(e.value))),
          ],
          onChanged: (v) =>
              setState(() => _idTemaProxima = v),
        ),
        const SizedBox(height: 14),

        const FieldLabel(
            'Observaciones\n'
            '(Incidencias, retrasos, riesgos, acciones correctivas)'),
        TextFormField(controller: _obsCtrl, maxLines: 3),
        const SizedBox(height: 20),

        // ── FIRMAS ─────────────────────────────────────────────────────────
        const SectionTitle('7. Firma del productor / representante'),
        const SizedBox(height: 12),
        PhotoField(
          label: 'Fotografía de la firma',
          imagePath: _firmaSocio,
          onImageSelected: (p) => setState(() => _firmaSocio = p),
        ),
        const SizedBox(height: 20),

        // ── PANEL FOTOGRÁFICO ──────────────────────────────────────────────
        const SectionTitle(
            'ANEXO 1. Panel fotográfico\n'
            '(Mínimo 3 fotos: inicio, desarrollo, cierre)'),
        const SizedBox(height: 12),

        PhotoField(
          label: 'Fotografía inicio',
          imagePath: _foto1,
          onImageSelected: (p) => setState(() => _foto1 = p),
        ),
        const FieldLabel('Descripción fotografía N°1'),
        TextFormField(
            controller: _foto1DescCtrl,
            decoration: const InputDecoration(
                hintText: 'Describe la foto de inicio...')),
        const SizedBox(height: 14),

        PhotoField(
          label: 'Fotografía desarrollo',
          imagePath: _foto2,
          onImageSelected: (p) => setState(() => _foto2 = p),
        ),
        const FieldLabel('Descripción fotografía N°2'),
        TextFormField(
            controller: _foto2DescCtrl,
            decoration: const InputDecoration(
                hintText: 'Describe la foto de desarrollo...')),
        const SizedBox(height: 14),

        PhotoField(
          label: 'Fotografía cierre',
          imagePath: _foto3,
          onImageSelected: (p) => setState(() => _foto3 = p),
        ),
        const FieldLabel('Descripción fotografía N°3'),
        TextFormField(
            controller: _foto3DescCtrl,
            decoration: const InputDecoration(
                hintText: 'Describe la foto de cierre...')),
        const SizedBox(height: 30),
      ],
    );
  }
}
