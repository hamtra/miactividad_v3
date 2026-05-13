import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/app_colors.dart';
import '../../core/catalog.dart';
import '../../models/fat.dart';
import '../../models/plan_trabajo.dart';
import '../../providers/fat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/usuario_model.dart';
import '../../widgets/form_widgets.dart';
import '../../widgets/signature_field.dart';
import '../../services/fat_pdf_service.dart';
import '../../services/socio_service.dart';
import '../../models/socio_model.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// LISTA DE FATs
// ═══════════════════════════════════════════════════════════════════════════════
class FatListScreen extends StatefulWidget {
  const FatListScreen({super.key});

  @override
  State<FatListScreen> createState() => _FatListScreenState();
}

class _FatListScreenState extends State<FatListScreen>
    with TickerProviderStateMixin {
  String? _filtroEstado;
  late TabController _tabController;

  // Último rol cargado — detecta cambios de sesión para recargar datos
  String _lastRol   = '';
  String _lastDni   = '';

  static bool _esAdminFromUsuario(UsuarioModel u) =>
      u.rol.toUpperCase() == 'ADMINISTRADOR';

  static bool _esSuperiorFromUsuario(UsuarioModel u) {
    final rol   = u.rol.toUpperCase();
    final cargo = u.cargo.toUpperCase();
    return rol != 'ADMINISTRADOR' && (
        rol   == 'COORDINADOR' ||
        cargo.contains('COORDINADOR') ||
        cargo.contains('SUPERVISOR') ||
        cargo.contains('JEFE') ||
        cargo.contains('GESTOR'));
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
  }

  // ── didChangeDependencies: se llama ANTES de build() cuando cambia SesionProvider ──
  // Garantiza que el TabController tenga la longitud correcta antes del primer render.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final usuario = context.read<SesionProvider>().usuario;
    if (usuario == null) return;

    final rol = usuario.rol;
    final dni = usuario.dni;
    if (rol == _lastRol && dni == _lastDni) return; // sin cambios
    _lastRol = rol;
    _lastDni = dni;

    // Actualizar TabController antes del build() siguiente
    final esAdm = _esAdminFromUsuario(usuario);
    final esSup = _esSuperiorFromUsuario(usuario);
    final nTabs = esAdm ? 3 : esSup ? 2 : 1;
    if (_tabController.length != nTabs) {
      final old = _tabController;
      _tabController = TabController(length: nTabs, vsync: this);
      // Dispose del viejo DESPUÉS del frame (cuando ya no está en el árbol)
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }

    // Disparar carga de datos tras el primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cargarDatos(usuario);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Solo carga datos — TabController ya está actualizado por didChangeDependencies
  Future<void> _cargarDatos(UsuarioModel usuario) async {
    // ignore: avoid_print
    print('🔑 FAT _cargarDatos rol="${usuario.rol}" cargo="${usuario.cargo}"');
    final prov  = context.read<FatProvider>();
    final esAdm = _esAdminFromUsuario(usuario);
    final esSup = _esSuperiorFromUsuario(usuario);

    unawaited(prov.cargarFats(usuario: usuario.dni));
    if (esAdm) {
      unawaited(prov.cargarTodasLasFats());
      unawaited(prov.cargarFatsParaAprobar(usuario.uid, esAdmin: true));
    } else if (esSup) {
      unawaited(prov.cargarFatsParaAprobar(usuario.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov    = context.watch<FatProvider>();
    final sesion  = context.watch<SesionProvider>(); // registra dependencia → activa didChangeDependencies
    final usuario = sesion.usuario;

    final esAdmin    = usuario != null && _esAdminFromUsuario(usuario);
    final esSuperior = usuario != null && _esSuperiorFromUsuario(usuario);

    final fats = _filtroEstado == null
        ? prov.fats
        : prov.fats.where((f) => f.estado == _filtroEstado).toList();

    // tabsListo: guard de seguridad (didChangeDependencies ya actualizó el controller)
    final nTabs     = esAdmin ? 3 : esSuperior ? 2 : 1;
    final tabsListo = _tabController.length == nTabs;

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
            ).then((_) => prov.cargarFats(usuario: usuario?.dni)),
          ),
        ],
        // Solo mostrar TabBar cuando el controller ya tiene la longitud correcta
        bottom: (esAdmin || esSuperior) && tabsListo
            ? TabBar(
                controller: _tabController,
                tabs: [
                  const Tab(text: 'Mis FATs'),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Para Aprobar'),
                        if (prov.fatsParaAprobar.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          CircleAvatar(
                            radius: 9,
                            backgroundColor: Colors.red,
                            child: Text('${prov.fatsParaAprobar.length}',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (esAdmin) const Tab(text: 'Todas'),
                ],
              )
            : null,
      ),
      // TabBarView SOLO cuando controller.length == children.length
      body: (esAdmin || esSuperior) && tabsListo
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildMisFats(context, fats, prov, usuario),
                _buildParaAprobar(context, prov, usuario),
                if (esAdmin) _buildTodasFats(context, prov),
              ],
            )
          : (esAdmin || esSuperior)
              ? const Center(child: CircularProgressIndicator())
              : prov.cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _buildMisFats(context, fats, prov, usuario),
    );
  }

  Widget _buildMisFats(BuildContext context, List<Fat> fats,
      FatProvider prov, UsuarioModel? usuario) {
    if (prov.cargando && fats.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (fats.isEmpty) return _buildEmpty(context, prov, usuario);
    return Column(
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
                    builder: (_) => FatFormScreen(fatExistente: fats[i])),
              ).then((_) => prov.cargarFats(usuario: usuario?.dni)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParaAprobar(BuildContext context, FatProvider prov,
      UsuarioModel? usuario) {
    final lista = prov.fatsParaAprobar;
    // Mostrar spinner mientras carga (flag independiente)
    if (prov.cargandoParaAprobar) {
      return const Center(child: CircularProgressIndicator());
    }
    // Mostrar error si Firestore falló (ej: falta índice compuesto)
    if (prov.errorParaAprobar != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.orange),
              const SizedBox(height: 12),
              Text('Error al cargar FATs para aprobar:\n${prov.errorParaAprobar}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => prov.cargarFatsParaAprobar(
                    usuario?.uid ?? '',
                    esAdmin: usuario != null && _esAdminFromUsuario(usuario)),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (lista.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            SizedBox(height: 12),
            Text('No hay FATs pendientes de aprobación',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: lista.length,
      itemBuilder: (ctx, i) {
        final fat = lista[i];
        return _FatCard(
          fat: fat,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.green),
                tooltip: 'Aprobar',
                onPressed: () async {
                  final ok = await prov.aprobarFat(fat.id);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text(ok ? '✅ FAT aprobada' : '❌ Error'),
                      backgroundColor: ok ? Colors.green : Colors.red,
                    ));
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle, color: Colors.orange),
                tooltip: 'Observar',
                onPressed: () => _mostrarDialogoObservar(ctx, prov, fat.id),
              ),
            ],
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => FatFormScreen(fatExistente: fat)),
          ).then((_) => prov.cargarFatsParaAprobar(
              usuario?.uid ?? '',
              esAdmin: usuario != null && _esAdminFromUsuario(usuario))),
        );
      },
    );
  }

  Future<void> _mostrarDialogoObservar(
      BuildContext ctx, FatProvider prov, String fatId) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Observación'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
              hintText: 'Describa la observación...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enviar')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      final res = await prov.observarFat(fatId, ctrl.text.trim());
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(res ? '✅ Observación enviada' : '❌ Error'),
          backgroundColor: res ? Colors.orange : Colors.red,
        ));
      }
    }
  }

  Widget _buildTodasFats(BuildContext context, FatProvider prov) {
    if (prov.cargandoTodos) {
      return const Center(child: CircularProgressIndicator());
    }
    if (prov.errorTodos != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: Colors.orange),
              const SizedBox(height: 12),
              Text('⚠️ Sin acceso a todas las FATs.\n'
                  'Verifica las reglas de Firestore.\n\n'
                  '${prov.errorTodos}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: prov.cargarTodasLasFats,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (prov.todasLasFats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('No hay FATs registradas en el sistema',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: prov.cargarTodasLasFats,
              icon: const Icon(Icons.refresh),
              label: const Text('Recargar'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: prov.cargarTodasLasFats,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: prov.todasLasFats.length,
        itemBuilder: (ctx, i) {
          final fat = prov.todasLasFats[i];
          return _FatCard(
            fat: fat,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => FatFormScreen(fatExistente: fat)),
            ).then((_) => prov.cargarTodasLasFats()),
          );
        },
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
  final Widget? trailing;
  const _FatCard({required this.fat, required this.onTap, this.trailing});

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
                  if (trailing != null) trailing!,
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
//
// Si se pasa [tareaOrigen] + [socioOrigen], la FAT se pre-llena con:
//   • idPta, comunidad, distrito, provincia (de la tarea)
//   • fecha = fecha de la tarea
//   • horaInicio / horaFinal (de la tarea)
//   • un participante con los datos del socio
// Y al guardar, marca al socio como completado en el plan.
// ═══════════════════════════════════════════════════════════════════════════════
class FatFormScreen extends StatefulWidget {
  final Fat? fatExistente;
  final Tarea? tareaOrigen;
  final Map<String, String>? socioOrigen;

  const FatFormScreen({
    super.key,
    this.fatExistente,
    this.tareaOrigen,
    this.socioOrigen,
  });

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
  bool _obteniendoGps = false;
  String? _errorGps;
  // Modo lectura: si abres una FAT ya creada, primero se ve como vista,
  // y debes pulsar "Editar" (lápiz) para activar la edición. Las FATs
  // ENVIADAs/APROBADAs no se pueden editar nunca.
  late bool _modoLectura;
  bool get _bloqueadoPorEstado {
    final e = widget.fatExistente?.estado;
    return e == 'ENVIADO' || e == 'APROBADO';
  }
  bool get _puedeEditar => !_bloqueadoPorEstado;

  @override
  void initState() {
    super.initState();
    final f = widget.fatExistente;
    // Vista por defecto: lectura si abres una FAT existente, edición si es nueva
    _modoLectura = f != null;
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

      // ── Pre-llenado desde una tarea del plan (vista "Mi día") ──────────
      final t = widget.tareaOrigen;
      final s = widget.socioOrigen;
      if (t != null) {
        _idPta = t.idPta;
        _provincia = t.provincia.isNotEmpty
            ? t.provincia
            : _provincia;
        _distrito = t.distrito.isNotEmpty
            ? t.distrito
            : _distrito;
        _comunidad = t.comunidad.isNotEmpty ? t.comunidad : null;
        _fecha = t.fecha;
        _mes = CatalogData.meses[t.fecha.month - 1];
        if (t.horaInicio.isNotEmpty) _horaInicio = t.horaInicio;
        if (t.horaFinal.isNotEmpty) _horaFinal = t.horaFinal;
      }
      if (s != null && (s['nombre'] ?? '').isNotEmpty) {
        _socios.add(SocioParticipante(
          id: const Uuid().v4().substring(0, 8),
          idFat: _id,
          idSocio: s['id'] ?? '',
          dni: s['dni'] ?? '',
          nombreCompleto: s['nombre'] ?? '',
          mes: _mes,
          usuario: usuario?.dni ?? '',
        ));
      }
    }

    // GPS automático al abrir el formulario (solo si no hay ubicación previa).
    if (_ubicacion == null || _ubicacion!.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _getGps());
    }
    // Cargar socios de FAT existente (async, no bloquea el build inicial)
    if (f != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final prov = context.read<FatProvider>();
        final lista = await prov.getSociosDeFat(f.id);
        if (mounted && lista.isNotEmpty) setState(() => _socios.addAll(lista));
      });
    }
  }

  @override
  void dispose() {
    _actCtrl.dispose(); _resCtrl.dispose(); _acuCtrl.dispose();
    _recCtrl.dispose(); _obsCtrl.dispose();
    _foto1DescCtrl.dispose(); _foto2DescCtrl.dispose(); _foto3DescCtrl.dispose();
    super.dispose();
  }

  // ── Obtener GPS automáticamente ────────────────────────────────────────────
  // No se permite editar a mano. Sólo reintentar.
  Future<void> _getGps() async {
    if (_obteniendoGps) return;
    setState(() {
      _obteniendoGps = true;
      _errorGps = null;
    });
    try {
      final servicio = await Geolocator.isLocationServiceEnabled();
      if (!servicio) {
        setState(() => _errorGps = 'Activa el GPS del dispositivo');
        return;
      }
      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        setState(() => _errorGps = 'Permiso de ubicación denegado');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      setState(() {
        _ubicacion =
            '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
        _errorGps = null;
      });
    } catch (e) {
      final msg = e.toString();
      String legible;
      if (msg.contains('No location permissions') ||
          msg.contains('manifest')) {
        legible =
            'Faltan permisos de ubicación. Cierra y vuelve a instalar la app (flutter clean + flutter run).';
      } else if (msg.contains('TimeoutException') ||
          msg.contains('timeout')) {
        legible =
            'GPS sin respuesta. Sal a un lugar abierto y reintenta.';
      } else {
        legible =
            'No se pudo obtener GPS. Verifica la señal e intenta de nuevo.';
      }
      setState(() => _errorGps = legible);
    } finally {
      if (mounted) setState(() => _obteniendoGps = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Enviar para aprobación ────────────────────────────────────────────────
  Future<void> _enviarParaAprobacion() async {
    final fat = widget.fatExistente;
    if (fat == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.send, color: AppColors.accentBlue, size: 20),
            SizedBox(width: 8),
            Text('Enviar para aprobación'),
          ],
        ),
        content: const Text(
          '¿Deseas enviar esta FAT al coordinador para su revisión?\n\n'
          'Una vez enviada, ya no podrás editarla hasta que sea observada.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Enviar'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBlue),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    setState(() => _guardando = true);
    final prov = context.read<FatProvider>();
    final ok = await prov.enviarFat(fat.id);
    setState(() => _guardando = false);
    if (!mounted) return;
    if (ok) {
      _showSnack('FAT enviada para aprobación ✓');
      Navigator.pop(context);
    } else {
      _showSnack('Error al enviar: ${prov.error}');
    }
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
      // UID del superior jerárquico (para flujo de aprobación)
      idSuperior: widget.fatExistente?.idSuperior ?? usuario?.idSuperior ?? '',
      // Vínculo con el plan (si la FAT viene de "Mi día")
      idTarea: widget.fatExistente?.idTarea ?? widget.tareaOrigen?.id,
      idSocioPlan: widget.fatExistente?.idSocioPlan ??
          widget.socioOrigen?['id'],
    );

    final prov = context.read<FatProvider>();
    bool ok;
    if (widget.fatExistente == null) {
      ok = await prov.guardarFat(fat, socios: _socios,
          idPlanTrabajo: widget.tareaOrigen?.idPlanTrabajo);
    } else {
      ok = await prov.actualizarFat(fat, socios: _socios,
          idPlanTrabajo: widget.tareaOrigen?.idPlanTrabajo);
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
        title: Text(_modoLectura ? 'FAT (lectura)' : '4Cafe.FAT'),
        actions: [
          // Botón ENVIAR PARA APROBACIÓN (lectura, estado REGISTRADO u OBSERVADO)
          if (_modoLectura &&
              (widget.fatExistente?.estado == 'REGISTRADO' ||
                  widget.fatExistente?.estado == 'OBSERVADO'))
            _guardando
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)),
                  )
                : TextButton.icon(
                    onPressed: _enviarParaAprobacion,
                    icon: const Icon(Icons.send,
                        color: Colors.white, size: 16),
                    label: const Text('Enviar',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
          // Botón EDITAR (solo si está en lectura y se permite editar)
          if (_modoLectura && _puedeEditar)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar',
              onPressed: () => setState(() => _modoLectura = false),
            ),
          if (_modoLectura && !_puedeEditar)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Row(
                  children: [
                    Icon(Icons.lock_outline,
                        color: Colors.white70, size: 16),
                    SizedBox(width: 4),
                    Text('Solo lectura',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ),
          if (!_modoLectura) ...[
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
                      onPressed: isLast ? _save : _intentarAvanzar,
                      child: Text(isLast ? 'Guardar' : 'Siguiente ►')),
            ),
          ],
        ],
      ),
      body: _modoLectura
          ? _FatVistaLectura(fat: widget.fatExistente!)
          : Column(
              children: [
                if (widget.tareaOrigen != null && widget.fatExistente == null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.accentBlue.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.link,
                            color: AppColors.accentBlue, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'FAT vinculada al plan · ${widget.tareaOrigen!.comunidad}'
                            '${widget.socioOrigen != null ? " · ${widget.socioOrigen!['nombre']}" : ''}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.accentBlue,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
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
        // GPS automático (no editable)
        _GpsAutoField(
          ubicacion: _ubicacion,
          obteniendo: _obteniendoGps,
          error: _errorGps,
          onReintentar: _getGps,
        ),
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
          items: CatalogData.todasLasComunidades
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
    final programados =
        widget.tareaOrigen?.sociosList ?? const <Map<String, String>>[];
    final idsProgramados =
        programados.map((s) => s['id'] ?? '').toSet();

    // Si hay un socio PROGRAMADO (del plan de trabajo) en la lista,
    // no se permite añadir más. Solo socios no programados pueden convivir
    // con otros no programados.
    final hayProgramado =
        _socios.any((s) => idsProgramados.contains(s.idSocio));

    // VTP = Visita a un productor → máximo 1 participante.
    final esVtp = _modalidad.toUpperCase().contains('VTP');

    final puedeAgregarMas =
        !hayProgramado && !(esVtp && _socios.isNotEmpty);

    return Column(
      children: [
        ..._socios.asMap().entries.map((e) {
          final esProgramado = idsProgramados.contains(e.value.idSocio);
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: esProgramado
                      ? AppColors.success.withOpacity(0.4)
                      : AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                      color: esProgramado
                          ? AppColors.success
                          : AppColors.primary,
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(e.value.nombreCompleto,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 6),
                          if (esProgramado)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: AppColors.success
                                        .withOpacity(0.4)),
                              ),
                              child: const Text('PROGRAMADO',
                                  style: TextStyle(
                                      fontSize: 8,
                                      color: AppColors.success,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5)),
                            )
                          else if (widget.tareaOrigen != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.warning
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: AppColors.warning
                                        .withOpacity(0.4)),
                              ),
                              child: const Text('NO PROGRAMADO',
                                  style: TextStyle(
                                      fontSize: 8,
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5)),
                            ),
                        ],
                      ),
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
          );
        }),
        if (puedeAgregarMas)
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
          )
        else if (esVtp)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.accentBlue.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.accentBlue.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    color: AppColors.accentBlue, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'VTP: solo se permite 1 productor por ficha.',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.accentBlue,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Avanzar a siguiente página.
  // GPS OBLIGATORIO: si no hay coordenadas capturadas no se puede avanzar.
  // Se muestra un mensaje de error y se reintenta la obtención del GPS.
  Future<void> _intentarAvanzar() async {
    if (_page == 0 && (_ubicacion == null || _ubicacion!.isEmpty)) {
      // Bloquear avance — no hay dialog de bypass
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.gps_off, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'GPS obligatorio. Debes estar en la parcela del socio '
                  'para capturar las coordenadas antes de continuar.',
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Reintentar',
            textColor: Colors.white,
            onPressed: _getGps,
          ),
        ),
      );
      // Reintenta GPS automáticamente
      if (!_obteniendoGps) _getGps();
      return; // no avanza
    }
    _next();
  }

  void _addSocio() {
    final usuario = context.read<SesionProvider>().usuario;
    // Socios programados en el plan (si la FAT viene de Mi Día)
    final programados = widget.tareaOrigen?.sociosList ?? const [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => _SelectorParticipantesSheet(
        sociosProgramados: programados,
        socioSeleccionadoActualmente: widget.socioOrigen,
        sociosYaAgregados: _socios.map((s) => s.idSocio).toSet(),
        comunidad: _comunidad ?? '',
        distrito:  _distrito  ?? '',
        provincia: _provincia ?? '',
        onAgregar: (s) {
          setState(() => _socios.add(SocioParticipante(
                id: const Uuid().v4().substring(0, 8),
                idFat: _id,
                idSocio: s['id'] ?? 'id_so_manual',
                dni: s['dni'] ?? '',
                nombreCompleto: (s['nombre'] ?? '').toUpperCase(),
                mes: _mes,
                usuario: usuario?.dni ?? '',
              )));
        },
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

        // ── FIRMA DIGITAL DEL SOCIO ────────────────────────────────────────
        const SectionTitle('7. Firma del productor / representante'),
        const SizedBox(height: 12),
        SignatureField(
          label: 'Firma del socio (dedo o lápiz óptico)',
          imagePath: _firmaSocio,
          onSignatureSaved: (p) => setState(() => _firmaSocio = p),
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
          addGpsWatermark: true,
          comunidad: _comunidad,
          distrito: _distrito,
          nombreSocio: _socios.isNotEmpty
              ? _socios.first.nombreCompleto
              : widget.socioOrigen?['nombre'],
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
          addGpsWatermark: true,
          comunidad: _comunidad,
          distrito: _distrito,
          nombreSocio: _socios.isNotEmpty
              ? _socios.first.nombreCompleto
              : widget.socioOrigen?['nombre'],
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
          addGpsWatermark: true,
          comunidad: _comunidad,
          distrito: _distrito,
          nombreSocio: _socios.isNotEmpty
              ? _socios.first.nombreCompleto
              : widget.socioOrigen?['nombre'],
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

// ─────────────────────────────────────────────────────────────────────────────
// SELECTOR DE PARTICIPANTES
// • Muestra socios programados del plan (si los hay).
// • "No programado" → busca en el catálogo Firestore (mg.socios_ae)
//   filtrando por la comunidad/distrito/provincia de la FAT.
// • Fallback manual si el socio no aparece en el catálogo.
// ─────────────────────────────────────────────────────────────────────────────
class _SelectorParticipantesSheet extends StatefulWidget {
  final List<Map<String, String>> sociosProgramados;
  final Map<String, String>? socioSeleccionadoActualmente;
  final Set<String> sociosYaAgregados;
  final void Function(Map<String, String>) onAgregar;
  final String comunidad;
  final String distrito;
  final String provincia;

  const _SelectorParticipantesSheet({
    required this.sociosProgramados,
    required this.socioSeleccionadoActualmente,
    required this.sociosYaAgregados,
    required this.onAgregar,
    required this.comunidad,
    required this.distrito,
    required this.provincia,
  });

  @override
  State<_SelectorParticipantesSheet> createState() =>
      _SelectorParticipantesSheetState();
}

class _SelectorParticipantesSheetState
    extends State<_SelectorParticipantesSheet> {
  // ── estado ───────────────────────────────────────────────────────────────
  bool _modoNoProgramado = false;
  bool _modoManualPuro   = false; // fallback si no está en catálogo

  // catálogo Firestore
  final _service          = SocioService();
  final _busquedaCtrl     = TextEditingController();
  List<SocioModel> _catalogo  = [];
  List<SocioModel> _filtrados = [];
  bool    _cargandoCatalogo   = false;
  String? _errorCatalogo;

  // entrada manual
  final _dniCtrl    = TextEditingController();
  final _nombreCtrl = TextEditingController();

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    _dniCtrl.dispose();
    _nombreCtrl.dispose();
    super.dispose();
  }

  // ── cargar socios del catálogo por comunidad ──────────────────────────────
  Future<void> _cargarCatalogo() async {
    setState(() { _cargandoCatalogo = true; _errorCatalogo = null; });
    try {
      final lista = await _service.getSociosPorComunidad(widget.comunidad);
      // Excluir socios ya agregados a la FAT
      _catalogo  = lista.where((s) =>
          !widget.sociosYaAgregados.contains(s.idSocio)).toList();
      _filtrados = _catalogo;
    } catch (e) {
      _errorCatalogo = e.toString();
    }
    if (mounted) setState(() => _cargandoCatalogo = false);
  }

  void _filtrar(String q) {
    final up = q.trim().toUpperCase();
    setState(() {
      _filtrados = up.isEmpty
          ? _catalogo
          : _catalogo.where((s) =>
              s.nombreCompleto.toUpperCase().contains(up) ||
              s.dni.contains(up)).toList();
    });
  }

  void _entrarModoNoProgramado() {
    setState(() => _modoNoProgramado = true);
    _cargarCatalogo();
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final pendientes = widget.sociosProgramados
        .where((s) => !widget.sociosYaAgregados.contains(s['id']))
        .toList();

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Título ─────────────────────────────────────────────
                    Text(
                      _modoManualPuro
                          ? 'Agregar manualmente'
                          : _modoNoProgramado
                              ? 'Socios en ${widget.comunidad}'
                              : 'Agregar participante',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _modoManualPuro
                          ? 'El socio no aparece en el catálogo — ingresa sus datos.'
                          : _modoNoProgramado
                              ? 'Filtrando por ${widget.distrito} · ${widget.provincia}'
                              : pendientes.isNotEmpty
                                  ? 'Toca un socio programado para agregarlo.'
                                  : 'Esta FAT no viene del plan.',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),

                    // ════════════════════════════════════════════════════════
                    // VISTA PRINCIPAL: programados + botón "no programado"
                    // ════════════════════════════════════════════════════════
                    if (!_modoNoProgramado && !_modoManualPuro) ...[
                      if (pendientes.isNotEmpty)
                        _ProgramadosList(
                            pendientes: pendientes,
                            onTap: (s) {
                              widget.onAgregar(s);
                              Navigator.pop(context);
                            }),
                      if (pendientes.isEmpty &&
                          widget.sociosProgramados.isNotEmpty)
                        _allDoneChip(),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          onPressed: _entrarModoNoProgramado,
                          icon: const Icon(Icons.person_search, size: 16),
                          label: const Text('Agregar socio no programado'),
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.warning),
                        ),
                      ),
                    ],

                    // ════════════════════════════════════════════════════════
                    // VISTA CATÁLOGO: búsqueda por comunidad
                    // ════════════════════════════════════════════════════════
                    if (_modoNoProgramado && !_modoManualPuro) ...[
                      // Buscador
                      TextField(
                        controller: _busquedaCtrl,
                        onChanged: _filtrar,
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre o DNI...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                          suffixIcon: _busquedaCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _busquedaCtrl.clear();
                                    _filtrar('');
                                  })
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Estado de carga / error / lista
                      if (_cargandoCatalogo)
                        const Center(
                            child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ))
                      else if (_errorCatalogo != null)
                        _errorChip(_errorCatalogo!)
                      else if (_filtrados.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            _catalogo.isEmpty
                                ? 'No hay socios registrados en "${widget.comunidad}".'
                                : 'Sin resultados para "${_busquedaCtrl.text}".',
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13),
                          ),
                        )
                      else
                        Container(
                          constraints: const BoxConstraints(maxHeight: 320),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: AppColors.border.withOpacity(0.5)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _filtrados.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final s = _filtrados[i];
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor:
                                      AppColors.warning.withOpacity(0.15),
                                  child: Text(
                                    s.nombreCompleto.isNotEmpty
                                        ? s.nombreCompleto[0]
                                        : '?',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.warning,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(s.nombreCompleto,
                                    style: const TextStyle(fontSize: 13)),
                                subtitle: Text(
                                    'DNI: ${s.dni}  ·  ${s.sexo}',
                                    style: const TextStyle(fontSize: 11)),
                                trailing: const Icon(
                                    Icons.add_circle_outline,
                                    color: AppColors.warning),
                                onTap: () {
                                  widget.onAgregar(s.toRef());
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                        ),

                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () =>
                                setState(() => _modoNoProgramado = false),
                            child: const Text('← Volver'),
                          ),
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _modoManualPuro = true),
                            icon: const Icon(Icons.edit, size: 14),
                            label: const Text('No está en la lista'),
                            style: TextButton.styleFrom(
                                foregroundColor: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],

                    // ════════════════════════════════════════════════════════
                    // FALLBACK MANUAL: DNI + nombre libres
                    // ════════════════════════════════════════════════════════
                    if (_modoManualPuro) ...[
                      TextField(
                        controller: _dniCtrl,
                        decoration: const InputDecoration(
                            labelText: 'DNI',
                            border: OutlineInputBorder(),
                            counterText: ''),
                        keyboardType: TextInputType.number,
                        maxLength: 8,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _nombreCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Nombre completo',
                            border: OutlineInputBorder()),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () =>
                                setState(() => _modoManualPuro = false),
                            child: const Text('← Volver'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              if (_dniCtrl.text.trim().isEmpty ||
                                  _nombreCtrl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Completa DNI y nombre')),
                                );
                                return;
                              }
                              widget.onAgregar({
                                'id':     'id_so_manual',
                                'dni':    _dniCtrl.text.trim(),
                                'nombre': _nombreCtrl.text.trim().toUpperCase(),
                              });
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Agregar'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.warning),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _allDoneChip() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(children: [
          Icon(Icons.check_circle, color: AppColors.success, size: 18),
          SizedBox(width: 8),
          Expanded(
              child: Text('Ya agregaste a todos los socios programados.',
                  style: TextStyle(fontSize: 12, color: AppColors.success))),
        ]),
      );

  Widget _errorChip(String msg) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text('Error al cargar socios: $msg',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.danger))),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Lista de socios programados reutilizable
// ─────────────────────────────────────────────────────────────────────────────
class _ProgramadosList extends StatelessWidget {
  final List<Map<String, String>> pendientes;
  final void Function(Map<String, String>) onTap;
  const _ProgramadosList({required this.pendientes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Column(
        children: pendientes.map((s) {
          return ListTile(
            dense: true,
            leading: const CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.success,
              child: Icon(Icons.add, color: Colors.white, size: 16),
            ),
            title: Text(s['nombre'] ?? '—',
                style: const TextStyle(fontSize: 13)),
            subtitle: Text('DNI: ${s['dni'] ?? '—'}',
                style: const TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.chevron_right,
                color: AppColors.textSecondary),
            onTap: () => onTap(s),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VISTA DE LECTURA DE LA FAT
//
// Muestra todos los campos guardados de una FAT existente como tarjetas
// de información y miniaturas de fotos (no editables). Para editar el
// usuario debe pulsar el icono de lápiz en la AppBar.
// ─────────────────────────────────────────────────────────────────────────────
class _FatVistaLectura extends StatefulWidget {
  final Fat fat;
  const _FatVistaLectura({required this.fat});
  @override
  State<_FatVistaLectura> createState() => _FatVistaLecturaState();
}

class _FatVistaLecturaState extends State<_FatVistaLectura> {
  List<SocioParticipante> _socios = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final prov = context.read<FatProvider>();
      final lista = await prov.getSociosDeFat(widget.fat.id);
      if (mounted) setState(() => _socios = lista);
    });
  }

  Fat get fat => widget.fat;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera con N° y estado
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fat.nroFat,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark)),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('dd MMM y', 'es').format(fat.fechaAsistencia)}'
                        ' · ${fat.horaInicio}–${fat.horaFinal}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                EstadoBadge(fat.estado),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _seccion('Identificación', [
            _kv('Modalidad', fat.modalidad),
            _kv('Etapa cultivo', fat.etapaCrianza),
            _kv('Tarea/Actividad', CatalogData.labelFromIdPta(fat.idPta)),
            _kv('Tema', CatalogData.labelFromIdTema(fat.idTema)),
          ]),

          _seccion('Ubicación', [
            _kv('Provincia', fat.provincia),
            _kv('Distrito', fat.distrito),
            _kv('Comunidad', fat.comunidad),
            _kv('Coordenadas GPS', fat.ubicacion ?? '—'),
            _kv('Clima', fat.clima),
            _kv('Incidencia', fat.incidencia),
          ]),

          _seccion('Responsable', [
            _kv('Técnico', fat.nombreTecnico),
            _kv('Cargo', fat.cargo),
            _kv('Organización', fat.organizacionProductores),
            _kv('N° participantes',
                _socios.isEmpty
                    ? fat.nroSociosParticipantes.toString()
                    : _socios.length.toString()),
          ]),

          // ── Participantes ────────────────────────────────────────────────────
          if (_socios.isNotEmpty)
            _seccion('Participantes',
              _socios.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Container(
                    width: 22, height: 22,
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                    child: Center(child: Text('${e.key + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 10))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.value.nombreCompleto,
                      style: const TextStyle(fontSize: 13))),
                  Text(e.value.dni,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ]),
              )).toList(),
            )
          else if (fat.nroSociosParticipantes > 0)
            _seccion('Participantes', [
              const Center(child: Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )),
            ]),

          _seccion('Desarrollo', [
            _kvLargo('Actividades', fat.actividadesRealizadas),
            _kvLargo('Resultados', fat.resultados),
            _kvLargo('Acuerdos / compromisos', fat.acuerdosCompromisos),
            _kvLargo('Recomendaciones', fat.recomendaciones),
            _kv('Próxima visita',
                DateFormat('dd/MM/yyyy').format(fat.proximaVisita)),
            if (fat.proximaVisitaTema.isNotEmpty)
              _kv('Tema próxima visita',
                  CatalogData.labelFromIdTema(fat.proximaVisitaTema)),
            if (fat.observaciones.isNotEmpty)
              _kvLargo('Observaciones', fat.observaciones),
          ]),

          // Firma del socio
          if ((fat.firmaSocio ?? '').isNotEmpty)
            _seccion('Firma del productor', [
              Container(
                width: double.infinity,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _imagenFirma(fat.firmaSocio!),
                ),
              ),
            ]),

          // Panel fotográfico
          _seccion('Panel fotográfico', [
            _foto('Inicio', fat.fotografia1, fat.foto1Descripcion),
            _foto('Desarrollo', fat.fotografia2, fat.foto2Descripcion),
            _foto('Cierre', fat.fotografia3, fat.foto3Descripcion),
          ]),

          if (fat.estado == 'OBSERVADO' &&
              (fat.estadoObservaciones ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.warning.withOpacity(0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_outlined,
                      color: AppColors.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Observaciones del coordinador',
                            style: TextStyle(
                                color: AppColors.warning,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(fat.estadoObservaciones!,
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── BOTONES DE ACCIÓN (pie de página) ────────────────────────────
          const SizedBox(height: 16),
          _AccionesFatSection(fat: fat),
        ],
      ),
    );
  }

  Widget _seccion(String titulo, List<Widget> hijos) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          ...hijos,
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(k,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(v.isEmpty ? '—' : v,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _kvLargo(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(v.isEmpty ? '—' : v,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _foto(String titulo, String? path, String descripcion) {
    final tieneGps = (fat.ubicacion ?? '').isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          if (path == null || path.isEmpty)
            Container(
              width: double.infinity,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Icon(Icons.image_not_supported,
                    color: Colors.grey.shade400),
              ),
            )
          else
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: path.startsWith('data:image')
                      ? Image.memory(base64.decode(path.split(',').last),
                          fit: BoxFit.cover, width: double.infinity, height: 200)
                      : (kIsWeb || path.startsWith('http'))
                          ? Image.network(
                              path,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 200,
                              loadingBuilder: (_, child, progress) {
                                if (progress == null) return child;
                                final total = progress.expectedTotalBytes;
                                final loaded = progress.cumulativeBytesLoaded;
                                return SizedBox(
                                  height: 200,
                                  width: double.infinity,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      value: total != null
                                          ? loaded / total
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (_, error, __) => SizedBox(
                                height: 200,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image,
                                        size: 36,
                                        color: Colors.grey.shade400),
                                    const SizedBox(height: 4),
                                    Text('No se pudo cargar',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500)),
                                  ],
                                ),
                              ))
                          : Image.file(File(path),
                              fit: BoxFit.cover,
                              width: double.infinity, height: 200,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image, size: 40)),
                ),
                // Banda GPS encima de la foto (visible en web donde no se estampa en la imagen)
                if (kIsWeb)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                      child: Container(
                        color: Colors.black.withOpacity(0.65),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (tieneGps)
                              Row(
                                children: [
                                  const Icon(Icons.gps_fixed,
                                      color: Colors.greenAccent, size: 11),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      fat.ubicacion!,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            if ((fat.comunidad).isNotEmpty ||
                                (fat.distrito).isNotEmpty)
                              Text(
                                [
                                  if (fat.comunidad.isNotEmpty) fat.comunidad,
                                  if (fat.distrito.isNotEmpty) fat.distrito,
                                ].join(' · '),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 10),
                              ),
                            if (fat.nroSociosParticipantes > 0)
                              Text(
                                'Participantes: ${fat.nroSociosParticipantes} · ${fat.modalidad}',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 10),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Badge GPS (no-web): indica que la imagen ya tiene watermark
                if (!kIsWeb && tieneGps)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.gps_fixed,
                              color: Colors.greenAccent, size: 10),
                          SizedBox(width: 3),
                          Text('GPS en imagen',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          if (descripcion.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(descripcion,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  Widget _imagenFirma(String path) {
    if (path.startsWith('data:image')) {
      final base = path.split(',').last;
      try {
        return Image.memory(base64.decode(base), fit: BoxFit.contain);
      } catch (_) {
        return const Icon(Icons.broken_image);
      }
    }
    if (kIsWeb || path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) =>
            progress == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
      );
    }
    return Image.file(File(path), fit: BoxFit.contain);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECCIÓN DE ACCIONES FAT — concentra TODOS los botones de acción de la vista
// de lectura: Enviar, PDF, Aprobar, Observar, Revertir (según rol y estado).
// ─────────────────────────────────────────────────────────────────────────────
class _AccionesFatSection extends StatefulWidget {
  final Fat fat;
  const _AccionesFatSection({required this.fat});
  @override
  State<_AccionesFatSection> createState() => _AccionesFatSectionState();
}

class _AccionesFatSectionState extends State<_AccionesFatSection> {
  bool _cargando = false;

  bool get _esAdmin {
    final u = context.read<SesionProvider>().usuario;
    return u?.rol.toUpperCase() == 'ADMINISTRADOR';
  }

  Future<void> _accion(Future<bool> Function() fn, String mensajeOk,
      {Color colorOk = AppColors.success}) async {
    setState(() => _cargando = true);
    final ok = await fn();
    if (!mounted) return;
    setState(() => _cargando = false);
    final prov = context.read<FatProvider>();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? mensajeOk : 'Error: ${prov.error}'),
      backgroundColor: ok ? colorOk : AppColors.danger,
    ));
    if (ok) Navigator.pop(context);
  }

  Future<void> _observar() async {
    final ctrl = TextEditingController();
    final obs = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Observar FAT'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FAT: ${widget.fat.nroFat}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              maxLines: 4,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Escribe las observaciones…',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) Navigator.pop(context, ctrl.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Observar'),
          ),
        ],
      ),
    );
    if (obs == null || !mounted) return;
    final prov = context.read<FatProvider>();
    await _accion(() => prov.observarFat(widget.fat.id, obs),
        '⚠️ FAT observada — el técnico será notificado',
        colorOk: AppColors.warning);
  }

  Future<void> _generarPdf() async {
    final prov = context.read<FatProvider>();
    setState(() => _cargando = true);
    final socios = await prov.getSociosDeFat(widget.fat.id);
    setState(() => _cargando = false);
    if (!mounted) return;
    await FatPdfService.mostrarPdf(context, widget.fat, socios: socios);
  }

  @override
  Widget build(BuildContext context) {
    final fat    = widget.fat;
    final esAdmin = _esAdmin;
    final prov   = context.read<FatProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Técnico: Enviar ──────────────────────────────────────────────────
        if (fat.estado == 'REGISTRADO' || fat.estado == 'OBSERVADO')
          _BotonAccion(
            label: fat.estado == 'OBSERVADO'
                ? 'Re-enviar para aprobación'
                : 'Enviar para aprobación',
            icon: Icons.send,
            color: AppColors.accentBlue,
            cargando: _cargando,
            onTap: () async {
              final confirmar = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Row(children: [
                    Icon(Icons.send, color: AppColors.accentBlue, size: 18),
                    SizedBox(width: 8),
                    Text('Enviar para aprobación'),
                  ]),
                  content: const Text(
                    '¿Enviar esta FAT al coordinador?\n'
                    'Una vez enviada no podrás editarla hasta que sea observada.',
                    style: TextStyle(fontSize: 13),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar')),
                    ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentBlue),
                        child: const Text('Enviar')),
                  ],
                ),
              );
              if (confirmar == true) {
                await _accion(() => prov.enviarFat(fat.id), '✅ FAT enviada para aprobación');
              }
            },
          ),

        // ── Admin: Aprobar ────────────────────────────────────────────────
        if (esAdmin && fat.estado == 'ENVIADO') ...[
          const SizedBox(height: 8),
          _BotonAccion(
            label: 'Aprobar FAT',
            icon: Icons.verified,
            color: AppColors.success,
            cargando: _cargando,
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Aprobar FAT'),
                  content: Text('¿Aprobar la FAT ${fat.nroFat}?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar')),
                    ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Aprobar')),
                  ],
                ),
              );
              if (ok == true) {
                await _accion(() => prov.aprobarFat(fat.id), '✅ FAT aprobada');
              }
            },
          ),
        ],

        // ── Admin: Observar ───────────────────────────────────────────────
        if (esAdmin && fat.estado == 'ENVIADO') ...[
          const SizedBox(height: 8),
          _BotonAccion(
            label: 'Observar FAT',
            icon: Icons.warning_amber,
            color: AppColors.warning,
            cargando: _cargando,
            onTap: _observar,
          ),
        ],

        // ── Admin: Revertir a REGISTRADO ──────────────────────────────────
        if (esAdmin && fat.estado != 'REGISTRADO') ...[
          const SizedBox(height: 8),
          _BotonAccion(
            label: 'Revertir a REGISTRADO',
            icon: Icons.refresh,
            color: AppColors.primary,
            cargando: _cargando,
            onTap: () async {
              await _accion(
                () => prov.cambiarEstado(fat.id, 'REGISTRADO'),
                '🔄 FAT vuelto a REGISTRADO',
                colorOk: AppColors.primary,
              );
            },
          ),
        ],

        // ── PDF: disponible cuando aprobado (o admin siempre) ─────────────
        if (fat.estado == 'APROBADO' || esAdmin) ...[
          const SizedBox(height: 8),
          _BotonAccion(
            label: 'Generar PDF',
            icon: Icons.picture_as_pdf,
            color: AppColors.success,
            cargando: _cargando,
            onTap: _generarPdf,
          ),
        ],
      ],
    );
  }
}

// ── Botón de acción reutilizable ───────────────────────────────────────────
class _BotonAccion extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool cargando;
  final VoidCallback onTap;

  const _BotonAccion({
    required this.label,
    required this.icon,
    required this.color,
    required this.cargando,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: cargando ? null : onTap,
        icon: cargando
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Icon(icon, size: 18),
        label: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTÓN ENVIAR PARA APROBACIÓN — aparece en la vista de lectura de la FAT
// cuando el estado es REGISTRADO u OBSERVADO.
// ─────────────────────────────────────────────────────────────────────────────
class _EnviarFatButton extends StatefulWidget {
  final Fat fat;
  const _EnviarFatButton({required this.fat});

  @override
  State<_EnviarFatButton> createState() => _EnviarFatButtonState();
}

class _EnviarFatButtonState extends State<_EnviarFatButton> {
  bool _enviando = false;

  Future<void> _enviar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.send, color: AppColors.accentBlue, size: 20),
            SizedBox(width: 8),
            Text('Enviar para aprobación'),
          ],
        ),
        content: const Text(
          '¿Deseas enviar esta FAT al coordinador para su revisión?\n\n'
          'Una vez enviada, ya no podrás editarla hasta que sea observada.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Enviar'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBlue),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    setState(() => _enviando = true);
    final prov = context.read<FatProvider>();
    final ok = await prov.enviarFat(widget.fat.id);
    if (!mounted) return;
    setState(() => _enviando = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('FAT enviada para aprobación ✓'),
            ],
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${prov.error}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _enviando ? null : _enviar,
        icon: _enviando
            ? const SizedBox(
                width: 16,
                height: 16,
                child:
                    CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.send, size: 18),
        label: Text(
          widget.fat.estado == 'OBSERVADO'
              ? 'Re-enviar para aprobación'
              : 'Enviar para aprobación',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentBlue,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CAMPO GPS AUTOMÁTICO — captura la posición al abrir, no permite edición.
// Solo botón de "reintentar" si falla. Esto obliga al técnico a estar
// físicamente en la parcela del socio.
// ─────────────────────────────────────────────────────────────────────────────
class _GpsAutoField extends StatelessWidget {
  final String? ubicacion;
  final bool obteniendo;
  final String? error;
  final VoidCallback onReintentar;

  const _GpsAutoField({
    required this.ubicacion,
    required this.obteniendo,
    required this.error,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    final tieneGps = ubicacion != null && ubicacion!.isNotEmpty;
    final colorBorde = tieneGps
        ? AppColors.success
        : (error != null ? AppColors.danger : AppColors.border);
    final colorFondo = tieneGps
        ? AppColors.success.withOpacity(0.06)
        : (error != null
            ? AppColors.danger.withOpacity(0.05)
            : Colors.grey.shade50);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorBorde, width: 1.4),
      ),
      child: Row(
        children: [
          // Icono / spinner
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tieneGps
                  ? AppColors.success
                  : (error != null
                      ? AppColors.danger
                      : AppColors.accentBlue),
              shape: BoxShape.circle,
            ),
            child: obteniendo
                ? const Padding(
                    padding: EdgeInsets.all(11),
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.4),
                  )
                : Icon(
                    tieneGps
                        ? Icons.gps_fixed
                        : (error != null ? Icons.gps_off : Icons.gps_not_fixed),
                    color: Colors.white,
                    size: 22,
                  ),
          ),
          const SizedBox(width: 12),
          // Texto principal
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tieneGps
                      ? 'Ubicación capturada'
                      : (obteniendo
                          ? 'Obteniendo GPS…'
                          : (error != null
                              ? 'No se obtuvo GPS'
                              : 'Esperando GPS')),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tieneGps
                        ? AppColors.success
                        : (error != null
                            ? AppColors.danger
                            : AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tieneGps
                      ? ubicacion!
                      : (error ?? 'Asegúrate de estar en la parcela del socio'),
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // Botón reintentar (solo si no se obtuvo)
          if (!obteniendo && !tieneGps)
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.accentBlue),
              tooltip: 'Reintentar',
              onPressed: onReintentar,
            ),
          if (tieneGps && !obteniendo)
            IconButton(
              icon: const Icon(Icons.refresh,
                  color: AppColors.textSecondary, size: 20),
              tooltip: 'Actualizar GPS',
              onPressed: onReintentar,
            ),
        ],
      ),
    );
  }
}
