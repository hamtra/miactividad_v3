import 'dart:async' show unawaited;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../core/catalog.dart';
import '../../core/pta_catalog.dart';
import '../../models/plan_trabajo.dart';
import '../../models/socio_model.dart';
import '../../providers/plan_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/usuario_model.dart';
import '../../widgets/form_widgets.dart';
import '../../services/auth_service.dart';
import '../../services/socio_service.dart';
import '../../services/plan_pdf_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PLAN DE TRABAJO SCREEN — lista con tabs (Mis Planes / Para Aprobar)
// ═══════════════════════════════════════════════════════════════════════════════
class PlanTrabajoScreen extends StatefulWidget {
  const PlanTrabajoScreen({super.key});
  @override
  State<PlanTrabajoScreen> createState() => _PlanTrabajoScreenState();
}

class _PlanTrabajoScreenState extends State<PlanTrabajoScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _lastRol = '';
  String _lastDni = '';

  static bool _esAdminU(UsuarioModel u) =>
      u.rol.toUpperCase() == 'ADMINISTRADOR';

  static bool _esCoordU(UsuarioModel u) {
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
    final esAdm   = _esAdminU(usuario);
    final esCoord = _esCoordU(usuario);
    final nTabs   = esAdm ? 3 : esCoord ? 2 : 1;
    if (_tabController.length != nTabs) {
      final old = _tabController;
      _tabController = TabController(length: nTabs, vsync: this);
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
    print('🔑 Plan _cargarDatos rol="${usuario.rol}" cargo="${usuario.cargo}"');
    final prov    = context.read<PlanProvider>();
    final esAdm   = _esAdminU(usuario);
    final esCoord = _esCoordU(usuario);

    unawaited(prov.cargarPlanes(usuario: usuario.dni));
    if (esAdm) {
      unawaited(prov.cargarPlanesParaAprobar(usuario.uid, esAdmin: true));
      unawaited(prov.cargarTodosLosPlanes());
    } else if (esCoord) {
      unawaited(prov.cargarPlanesParaAprobar(usuario.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov    = context.watch<PlanProvider>();
    final sesion  = context.watch<SesionProvider>(); // registra dependencia → activa didChangeDependencies
    final usuario = sesion.usuario;

    final esAdmin = usuario != null && _esAdminU(usuario);
    final esCoord = usuario != null && _esCoordU(usuario);

    // tabsListo: guard de seguridad (didChangeDependencies ya actualizó el controller)
    final nTabs     = esAdmin ? 3 : (esCoord ? 2 : 1);
    final tabsListo = _tabController.length == nTabs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan de Trabajo',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nuevo plan',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlanTrabajoFormScreen()),
            ).then((_) => prov.cargarPlanes(usuario: usuario?.dni)),
          ),
        ],
        // TabBar SOLO cuando controller.length == children.length
        bottom: (esCoord || esAdmin) && tabsListo
            ? TabBar(
                controller: _tabController,
                tabs: [
                  const Tab(text: 'Mis Planes'),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Para Aprobar'),
                        if (prov.planesParaAprobar.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('${prov.planesParaAprobar.length}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (esAdmin) const Tab(text: 'Todos'),
                ],
              )
            : null,
      ),
      // TabBarView SOLO cuando controller.length == children.length
      body: (esCoord || esAdmin) && tabsListo
          ? TabBarView(
              controller: _tabController,
              children: [
                _MisPlanesList(usuario: usuario, prov: prov, esAdmin: esAdmin),
                _ParaAprobarList(prov: prov, esAdmin: esAdmin),
                if (esAdmin) _TodosLosPlanesList(prov: prov),
              ],
            )
          : (esCoord || esAdmin)
              ? const Center(child: CircularProgressIndicator())
              : _MisPlanesList(usuario: usuario, prov: prov, esAdmin: false),
    );
  }
}

// ── Lista: Mis Planes ──────────────────────────────────────────────────────────
class _MisPlanesList extends StatelessWidget {
  final UsuarioModel? usuario;
  final PlanProvider prov;
  final bool esAdmin;
  const _MisPlanesList(
      {required this.usuario, required this.prov, required this.esAdmin});

  @override
  Widget build(BuildContext context) {
    if (prov.cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (prov.planes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined,
                size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('Sin planes registrados',
                style: TextStyle(
                    fontSize: 16, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PlanTrabajoFormScreen()),
              ).then((_) => prov.cargarPlanes(usuario: usuario?.dni)),
              icon: const Icon(Icons.add),
              label: const Text('Crear Plan'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => prov.cargarPlanes(usuario: usuario?.dni),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: prov.planes.length,
        itemBuilder: (ctx, i) {
          final plan = prov.planes[i];
          return _PlanCard(
            plan: plan,
            esCoordinador: false,
            esAdmin: esAdmin,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => PlanTrabajoFormScreen(planExistente: plan)),
            ).then((_) => prov.cargarPlanes(usuario: usuario?.dni)),
            onAccion: _accionPorEstado(context, plan, prov, usuario),
            onAprobar: esAdmin && plan.estado == 'ENVIADO'
                ? () => _aprobarAdmin(context, plan, prov, usuario)
                : null,
            onObservar: esAdmin && plan.estado == 'ENVIADO'
                ? () => _observarAdmin(context, plan, prov, usuario)
                : null,
            onRegistrar: esAdmin && plan.estado != 'REGISTRADO'
                ? () => _registrarAdmin(context, plan, prov, usuario)
                : null,
            onEliminar:
                (plan.estado == 'REGISTRADO' || plan.estado == 'OBSERVADO')
                    ? () => _eliminarPlan(context, plan, prov, usuario)
                    : null,
          );
        },
      ),
    );
  }

  VoidCallback? _accionPorEstado(
    BuildContext context,
    PlanTrabajo plan,
    PlanProvider prov,
    UsuarioModel? usuario,
  ) {
    // Admin puede enviar desde cualquier estado editable
    // Técnico solo desde REGISTRADO u OBSERVADO
    if (!esAdmin &&
        plan.estado != 'REGISTRADO' &&
        plan.estado != 'OBSERVADO') return null;
    if (esAdmin && plan.estado == 'ENVIADO') return null; // admin usa aprobar/observar
    if (esAdmin && plan.estado == 'APROBADO') return null;
    return () async {
      final ok = await prov.enviarPlan(plan.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? '✅ Plan enviado al coordinador'
              : '❌ Error: ${prov.error}'),
          backgroundColor: ok ? AppColors.success : AppColors.danger,
        ));
        if (ok) prov.cargarPlanes(usuario: usuario?.dni);
      }
    };
  }

  Future<void> _aprobarAdmin(BuildContext context, PlanTrabajo plan,
      PlanProvider prov, UsuarioModel? usuario) async {
    final ok = await prov.aprobarPlan(plan.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '✅ Plan aprobado' : '❌ Error: ${prov.error}'),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
      ));
      if (ok) prov.cargarPlanes(usuario: usuario?.dni);
    }
  }

  Future<void> _observarAdmin(BuildContext context, PlanTrabajo plan,
      PlanProvider prov, UsuarioModel? usuario) async {
    final ctrl = TextEditingController();
    final obs = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Observar Plan'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
              hintText: 'Escribe las observaciones…',
              border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                Navigator.pop(context, ctrl.text.trim());
              }
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Observar'),
          ),
        ],
      ),
    );
    if (obs == null || !context.mounted) return;
    final ok = await prov.observarPlan(plan.id, obs);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '⚠️ Plan observado' : '❌ Error: ${prov.error}'),
        backgroundColor: ok ? AppColors.warning : AppColors.danger,
      ));
      if (ok) prov.cargarPlanes(usuario: usuario?.dni);
    }
  }

  Future<void> _registrarAdmin(BuildContext context, PlanTrabajo plan,
      PlanProvider prov, UsuarioModel? usuario) async {
    final ok = await prov.registrarPlan(plan.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            ok ? '🔄 Plan vuelto a REGISTRADO' : '❌ Error: ${prov.error}'),
        backgroundColor: ok ? AppColors.primary : AppColors.danger,
      ));
      if (ok) prov.cargarPlanes(usuario: usuario?.dni);
    }
  }

  Future<void> _eliminarPlan(BuildContext context, PlanTrabajo plan,
      PlanProvider prov, UsuarioModel? usuario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar Plan'),
        content: Text(
          '¿Eliminar el plan de ${plan.mes}? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;
    final ok = await prov.eliminarPlan(plan.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '🗑 Plan eliminado' : '❌ Error: ${prov.error}'),
        backgroundColor: ok ? AppColors.textSecondary : AppColors.danger,
      ));
      if (ok) prov.cargarPlanes(usuario: usuario?.dni);
    }
  }
}

// ── Lista: Para Aprobar (coordinador / admin) ──────────────────────────────────
class _ParaAprobarList extends StatelessWidget {
  final PlanProvider prov;
  final bool esAdmin;
  const _ParaAprobarList({required this.prov, required this.esAdmin});

  @override
  Widget build(BuildContext context) {
    // Usar flag independiente para no interferir con carga de "Mis Planes"
    if (prov.cargandoParaAprobar) {
      return const Center(child: CircularProgressIndicator());
    }
    if (prov.errorParaAprobar != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.orange),
              const SizedBox(height: 12),
              Text('Error al cargar planes:\n${prov.errorParaAprobar}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }
    if (prov.planesParaAprobar.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('No hay planes pendientes de aprobación',
                style: TextStyle(
                    fontSize: 15, color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: prov.planesParaAprobar.length,
      itemBuilder: (ctx, i) {
        final plan = prov.planesParaAprobar[i];
        return _PlanCard(
          plan: plan,
          esCoordinador: true,
          esAdmin: esAdmin,
          onTap: () => _verDetalle(ctx, plan),
          onAprobar: () => _aprobar(ctx, plan, prov),
          onObservar: () => _observar(ctx, plan, prov),
          onRegistrar: esAdmin
              ? () => _registrar(ctx, plan, prov)
              : null,
        );
      },
    );
  }

  void _verDetalle(BuildContext context, PlanTrabajo plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _DetallePlanSheet(plan: plan),
    );
  }

  Future<void> _aprobar(
      BuildContext context, PlanTrabajo plan, PlanProvider prov) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aprobar Plan'),
        content: Text('¿Aprobar el plan de ${plan.nombreTecnico} — ${plan.mes}?'),
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
    if (confirmar != true || !context.mounted) return;
    final ok = await prov.aprobarPlan(plan.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '✅ Plan aprobado' : '❌ Error: ${prov.error}'),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
      ));
    }
  }

  Future<void> _registrar(
      BuildContext context, PlanTrabajo plan, PlanProvider prov) async {
    final ok = await prov.registrarPlan(plan.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            ok ? '🔄 Plan vuelto a REGISTRADO' : '❌ Error: ${prov.error}'),
        backgroundColor: ok ? AppColors.primary : AppColors.danger,
      ));
    }
  }

  Future<void> _observar(
      BuildContext context, PlanTrabajo plan, PlanProvider prov) async {
    final ctrl = TextEditingController();
    final obs = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Observar Plan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plan de ${plan.nombreTecnico} — ${plan.mes}'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Describe las observaciones…',
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
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(context, ctrl.text.trim());
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning),
            child: const Text('Observar'),
          ),
        ],
      ),
    );
    if (obs == null || !context.mounted) return;
    final ok = await prov.observarPlan(plan.id, obs);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? '⚠️ Plan observado — el técnico será notificado'
            : '❌ Error: ${prov.error}'),
        backgroundColor: ok ? AppColors.warning : AppColors.danger,
      ));
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TODOS LOS PLANES (admin)
// ═══════════════════════════════════════════════════════════════════════════════
class _TodosLosPlanesList extends StatelessWidget {
  final PlanProvider prov;
  const _TodosLosPlanesList({required this.prov});

  @override
  Widget build(BuildContext context) {
    // Usa cargandoTodos (flag independiente) para no interferir con cargarPlanes
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
              Text('⚠️ Sin acceso a todos los planes.\n'
                  'Verifica las reglas de Firestore.\n\n'
                  '${prov.errorTodos}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: prov.cargarTodosLosPlanes,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (prov.todosLosPlanes.isEmpty) {
      return const Center(
        child: Text('No hay planes registrados',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return RefreshIndicator(
      onRefresh: prov.cargarTodosLosPlanes,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: prov.todosLosPlanes.length,
        itemBuilder: (ctx, i) {
          final plan = prov.todosLosPlanes[i];
          return _PlanCard(
            plan: plan,
            esCoordinador: false,
            esAdmin: true,
            onTap: () => showModalBottomSheet(
              context: ctx,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(16))),
              builder: (_) => _DetallePlanSheet(plan: plan),
            ),
            onAccion: (plan.estado == 'REGISTRADO' || plan.estado == 'OBSERVADO')
                ? () async {
                    final ok = await prov.enviarPlan(plan.id);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text(ok
                            ? '✅ Plan enviado'
                            : '❌ Error: ${prov.error}'),
                        backgroundColor:
                            ok ? AppColors.success : AppColors.danger,
                      ));
                      if (ok) prov.cargarTodosLosPlanes();
                    }
                  }
                : null,
            onAprobar: plan.estado == 'ENVIADO'
                ? () async {
                    final ok = await prov.aprobarPlan(plan.id);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text(
                            ok ? '✅ Plan aprobado' : '❌ Error: ${prov.error}'),
                        backgroundColor:
                            ok ? AppColors.success : AppColors.danger,
                      ));
                      if (ok) prov.cargarTodosLosPlanes();
                    }
                  }
                : null,
            onObservar: plan.estado == 'ENVIADO'
                ? () async {
                    final ctrl = TextEditingController();
                    final obs = await showDialog<String>(
                      context: ctx,
                      builder: (_) => AlertDialog(
                        title: const Text('Observar Plan'),
                        content: TextField(
                            controller: ctrl,
                            maxLines: 4,
                            decoration: const InputDecoration(
                                hintText: 'Observaciones…',
                                border: OutlineInputBorder())),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancelar')),
                          ElevatedButton(
                            onPressed: () {
                              if (ctrl.text.trim().isNotEmpty) {
                                Navigator.pop(ctx, ctrl.text.trim());
                              }
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.warning),
                            child: const Text('Observar'),
                          ),
                        ],
                      ),
                    );
                    if (obs == null || !ctx.mounted) return;
                    final ok = await prov.observarPlan(plan.id, obs);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text(
                            ok ? '⚠️ Observado' : '❌ Error: ${prov.error}'),
                        backgroundColor:
                            ok ? AppColors.warning : AppColors.danger,
                      ));
                      if (ok) prov.cargarTodosLosPlanes();
                    }
                  }
                : null,
            onRegistrar: plan.estado != 'REGISTRADO'
                ? () async {
                    final ok = await prov.registrarPlan(plan.id);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text(ok
                            ? '🔄 Vuelto a REGISTRADO'
                            : '❌ Error: ${prov.error}'),
                        backgroundColor:
                            ok ? AppColors.primary : AppColors.danger,
                      ));
                      if (ok) prov.cargarTodosLosPlanes();
                    }
                  }
                : null,
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PLAN CARD
// ═══════════════════════════════════════════════════════════════════════════════
class _PlanCard extends StatelessWidget {
  final PlanTrabajo plan;
  final bool        esCoordinador;
  final bool        esAdmin;
  final VoidCallback  onTap;
  final VoidCallback? onAccion;    // enviar (técnico / admin)
  final VoidCallback? onAprobar;   // aprobar (coordinador / admin)
  final VoidCallback? onObservar;  // observar (coordinador / admin)
  final VoidCallback? onRegistrar; // volver a REGISTRADO (solo admin)
  final VoidCallback? onEliminar;  // eliminar plan (REGISTRADO / OBSERVADO)

  const _PlanCard({
    required this.plan,
    required this.esCoordinador,
    required this.esAdmin,
    required this.onTap,
    this.onAccion,
    this.onAprobar,
    this.onObservar,
    this.onRegistrar,
    this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera: mes + badge estado
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.mes,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textPrimary),
                    ),
                  ),
                  EstadoBadge(plan.estado),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                plan.nombreTecnico,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd/MM/yyyy').format(plan.fechaCreacion),
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.task_alt,
                      size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    '${plan.tareas.length} tareas',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),

              // ── Progreso de visitas (socios completados / totales) ──────
              if (plan.tareas.isNotEmpty) ...[
                const SizedBox(height: 8),
                _ProgresoPlan(plan: plan),
              ],

              // Observaciones previas
              if (plan.estado == 'OBSERVADO' &&
                  plan.observaciones != null &&
                  plan.observaciones!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppColors.warning.withOpacity(0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_outlined,
                          size: 14, color: AppColors.warning),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          plan.observaciones!,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // Botón eliminar plan (REGISTRADO / OBSERVADO, no coordinador)
              if (!esCoordinador && onEliminar != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onEliminar,
                    icon: const Icon(Icons.delete_outline,
                        size: 14, color: AppColors.danger),
                    label: const Text('ELIMINAR',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.danger)),
                  ),
                ),
              ],

              // Botones de acción
              if (!esCoordinador && onAccion != null)
                _boton(
                  label: plan.estado == 'OBSERVADO' ? 'RE-ENVIAR' : 'ENVIAR',
                  icon: Icons.send,
                  color: AppColors.primary,
                  onTap: onAccion!,
                ),
              if (!esCoordinador && plan.estado == 'APROBADO')
                _boton(
                  label: 'GENERAR PDF',
                  icon: Icons.picture_as_pdf,
                  color: AppColors.success,
                  onTap: () => PlanPdfService.mostrarPdf(context, plan),
                ),
              if (!esCoordinador && !esAdmin && plan.estado == 'ENVIADO')
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hourglass_empty,
                          size: 13, color: Colors.blue),
                      SizedBox(width: 4),
                      Text('Esperando aprobación',
                          style: TextStyle(
                              fontSize: 11, color: Colors.blue)),
                    ],
                  ),
                ),

              // Botones coordinador / admin
              if (esCoordinador || esAdmin) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onRegistrar != null)
                      TextButton.icon(
                        onPressed: onRegistrar,
                        icon: const Icon(Icons.refresh,
                            size: 14, color: AppColors.primary),
                        label: const Text('REGISTRAR',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.primary)),
                      ),
                    if (onObservar != null)
                      TextButton.icon(
                        onPressed: onObservar,
                        icon: const Icon(Icons.warning_amber,
                            size: 14, color: AppColors.warning),
                        label: const Text('OBSERVAR',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.warning)),
                      ),
                    const SizedBox(width: 4),
                    if (onAprobar != null)
                      ElevatedButton.icon(
                        onPressed: onAprobar,
                        icon: const Icon(Icons.check, size: 14),
                        label: const Text('APROBAR',
                            style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _boton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DETALLE PLAN (bottom sheet para coordinador)
// ═══════════════════════════════════════════════════════════════════════════════
class _DetallePlanSheet extends StatelessWidget {
  final PlanTrabajo plan;
  const _DetallePlanSheet({required this.plan});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, ctrl) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 12),
            Text('Plan — ${plan.mes}',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold)),
            Text(plan.nombreTecnico,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                itemCount: plan.tareas.length,
                itemBuilder: (_, i) {
                  final t = plan.tareas[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ),
                    title: Text(
                      DateFormat('dd/MM/yyyy').format(t.fecha),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${CatalogData.labelFromIdPta(t.idPta)} · ${t.comunidad}'
                      '${t.sociosResumen.isNotEmpty ? '\n${t.sociosResumen}' : ''}',
                    ),
                    isThreeLine: t.sociosResumen.isNotEmpty,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FORMULARIO PLAN DE TRABAJO
// ═══════════════════════════════════════════════════════════════════════════════
class PlanTrabajoFormScreen extends StatefulWidget {
  final PlanTrabajo? planExistente;
  const PlanTrabajoFormScreen({super.key, this.planExistente});

  @override
  State<PlanTrabajoFormScreen> createState() =>
      _PlanTrabajoFormScreenState();
}

class _PlanTrabajoFormScreenState extends State<PlanTrabajoFormScreen> {
  late String _id;
  late String _mes;
  late DateTime _fecha;
  late List<Tarea> _tareas;
  final _formKey = GlobalKey<FormState>();

  // Coordinador
  String _idCoordinador     = '';
  String _nombreCoordinador = '';
  bool   _cargandoCoord     = false;

  @override
  void initState() {
    super.initState();
    final p = widget.planExistente;
    _id     = p?.id            ?? const Uuid().v4().toUpperCase();
    _mes    = p?.mes           ?? _mesActual();
    _fecha  = p?.fechaCreacion ?? DateTime.now();
    _tareas = List.from(p?.tareas ?? []);

    if (p != null) {
      _idCoordinador     = p.idCoordinador;
      _nombreCoordinador = p.nombreCoordinador;
    } else {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _cargarCoordinador());
    }
  }

  Future<void> _cargarCoordinador() async {
    final usuario = context.read<SesionProvider>().usuario;
    final idSuperior = usuario?.idSuperior ?? '';
    if (idSuperior.isEmpty) return;

    setState(() => _cargandoCoord = true);
    try {
      final todos = await AuthService().getUsuarios();
      final sup = todos.firstWhere(
        (u) => u.uid == idSuperior,
        orElse: () => UsuarioModel(
          uid: '', nombreCompleto: '', dni: '', celular: '',
          sexo: '', fechaNacimiento: DateTime(2000),
          actividad: '', cargo: '', rol: '',
          idSuperior: '', estado: false,
          email: '', firmaUrl: '',
        ),
      );
      if (sup.uid.isNotEmpty && mounted) {
        setState(() {
          _idCoordinador     = sup.uid;
          _nombreCoordinador = sup.nombreCompleto;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _cargandoCoord = false);
  }

  String _mesActual() {
    final m = DateTime.now().month;
    return CatalogData.meses[m - 1];
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? true)) return;
    final usuario = context.read<SesionProvider>().usuario;
    if (usuario == null) return;

    // No se puede editar un plan en estado ENVIADO o APROBADO
    final estadoActual = widget.planExistente?.estado ?? 'REGISTRADO';
    if (estadoActual == 'ENVIADO' || estadoActual == 'APROBADO') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No puedes editar un plan enviado o aprobado')));
      return;
    }

    final plan = PlanTrabajo(
      id:                _id,
      mes:               _mes,
      idTecEspExt:       usuario.idTecEspExt,
      nombreTecnico:     usuario.nombreCompleto,
      nombreActividad:   CatalogData.nombreActividad,
      fechaCreacion:     _fecha,
      idCoordinador:     _idCoordinador,
      nombreCoordinador: _nombreCoordinador,
      estado:            estadoActual,
      usuario:           usuario.dni,
      tareas:            _tareas,
    );

    final prov = context.read<PlanProvider>();
    final bool ok;
    if (widget.planExistente == null) {
      ok = await prov.guardarPlan(plan);
    } else {
      ok = await prov.actualizarPlan(plan);
    }

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan guardado correctamente')));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${prov.error ?? 'desconocido'}')));
    }
  }

  Future<void> _editTarea(int index) async {
    final usuario = context.read<SesionProvider>().usuario;
    final result = await Navigator.push<Tarea>(
      context,
      MaterialPageRoute(
        builder: (_) => TareaFormScreen(
          idPlan: _id,
          usuario: usuario?.dni ?? '',
          tareaExistente: _tareas[index],
        ),
      ),
    );
    if (result != null) setState(() => _tareas[index] = result);
  }

  void _addTarea() async {
    final usuario = context.read<SesionProvider>().usuario;
    final result = await Navigator.push<Tarea>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              TareaFormScreen(idPlan: _id, usuario: usuario?.dni ?? '')),
    );
    if (result != null) setState(() => _tareas.add(result));
  }

  bool get _bloqueado {
    final e = widget.planExistente?.estado;
    return e == 'ENVIADO' || e == 'APROBADO';
  }

  void _verDetalleTarea(BuildContext context, Tarea tarea) {
    final socios = tarea.sociosList;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 12),
            Text(CatalogData.labelFromIdPta(tarea.idPta),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            Text(
              '${tarea.comunidad} · ${DateFormat('dd/MM/yyyy').format(tarea.fecha)}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Text('${socios.length} socio(s) programado(s)',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.primary)),
            const Divider(height: 16),
            ...socios.map((s) => ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.accentBlue.withOpacity(0.15),
                    child: Text(
                      (s['nombre'] ?? '?').isNotEmpty
                          ? s['nombre']![0]
                          : '?',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.accentBlue,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(s['nombre'] ?? '—',
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Text('DNI: ${s['dni'] ?? '—'}',
                      style: const TextStyle(fontSize: 11)),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.read<SesionProvider>().usuario;
    final isEdit  = widget.planExistente != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context)),
        title: Text(isEdit ? 'Editar Plan' : 'Nuevo Plan'),
        actions: [
          if (!_bloqueado)
            TextButton(
              onPressed: _save,
              child: const Text('GUARDAR',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Aviso si plan bloqueado
              if (_bloqueado)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline,
                          color: Colors.amber, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Plan en estado ${widget.planExistente!.estado} — solo lectura',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.amber),
                        ),
                      ),
                    ],
                  ),
                ),

              // ID
              const FieldLabel('idPlanTrabajo'),
              ReadOnlyField('${_id.substring(0, 8)}...'),
              const SizedBox(height: 14),

              // MES
              const FieldLabel('Seleccione el mes', required: true),
              DropdownButtonFormField<String>(
                value: _mes,
                decoration: const InputDecoration(),
                items: CatalogData.meses
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: _bloqueado ? null : (v) => setState(() => _mes = v!),
              ),
              const SizedBox(height: 14),

              // TÉCNICO
              const FieldLabel('Técnico / Especialista / Extensionista'),
              ReadOnlyField(usuario?.nombreCompleto ?? '',
                  color: AppColors.accentBlue),
              const SizedBox(height: 14),

              // FECHA
              const FieldLabel('Fecha elaboración del plan', required: true),
              _bloqueado
                  ? ReadOnlyField(
                      DateFormat('dd/MM/yyyy').format(_fecha))
                  : DatePickerField(
                      value: _fecha,
                      onChanged: (d) => setState(() => _fecha = d)),
              const SizedBox(height: 14),

              // COORDINADOR
              const FieldLabel('Coordinador asignado'),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: _cargandoCoord
                    ? const Row(children: [
                        SizedBox(
                            width: 14,
                            height: 14,
                            child:
                                CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 8),
                        Text('Cargando coordinador...',
                            style: TextStyle(
                                color: AppColors.textSecondary)),
                      ])
                    : Text(
                        _nombreCoordinador.isNotEmpty
                            ? _nombreCoordinador
                            : 'Sin coordinador asignado',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: _nombreCoordinador.isNotEmpty
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
              ),

              // Observaciones (si fue observado)
              if (widget.planExistente?.estado == 'OBSERVADO' &&
                  widget.planExistente!.observaciones != null) ...[
                const SizedBox(height: 14),
                const FieldLabel('Observaciones del coordinador'),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.warning.withOpacity(0.5)),
                  ),
                  child: Text(widget.planExistente!.observaciones!,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.warning)),
                ),
              ],

              const SizedBox(height: 20),

              // TAREAS
              const SectionTitle('Tareas a realizar (por día) durante el mes'),
              const SizedBox(height: 10),

              ..._tareas.asMap().entries.map((e) => _TareaItem(
                    index: e.key + 1,
                    tarea: e.value,
                    onEdit: _bloqueado ? null : () => _editTarea(e.key),
                    onDelete: _bloqueado
                        ? null
                        : () => setState(() => _tareas.removeAt(e.key)),
                    onInfo: _bloqueado
                        ? () => _verDetalleTarea(context, e.value)
                        : null,
                  )),

              // ── Acciones admin (Aprobar / Observar / Registrar / Enviar) ─────
              if (_bloqueado || widget.planExistente != null)
                _AccionesAdminPlan(planExistente: widget.planExistente),

              if (!_bloqueado)
                GestureDetector(
                  onTap: _addTarea,
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
                        Icon(Icons.add, color: AppColors.accentBlue, size: 18),
                        SizedBox(width: 6),
                        Text('Nueva tarea',
                            style: TextStyle(
                                color: AppColors.accentBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAREA ITEM en la lista del formulario
// ═══════════════════════════════════════════════════════════════════════════════
class _TareaItem extends StatelessWidget {
  final int index;
  final Tarea tarea;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onInfo; // lectura: ver socios completos
  const _TareaItem(
      {required this.index,
      required this.tarea,
      this.onEdit,
      this.onDelete,
      this.onInfo});

  @override
  Widget build(BuildContext context) {
    final tareaLabel = CatalogData.labelFromIdPta(tarea.idPta);
    final soloLectura = onEdit == null && onDelete == null;
    return InkWell(
      onTap: soloLectura ? onInfo : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
              child: Center(
                child: Text('$index',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('dd/MM/yyyy').format(tarea.fecha),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    '$tareaLabel — ${tarea.comunidad}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${tarea.horaInicio} – ${tarea.horaFinal} · ${tarea.distrito}',
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 10),
                  ),
                  if (tarea.sociosResumen.isNotEmpty)
                    Text(
                      '👤 ${tarea.sociosResumen}',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.accentBlue),
                    ),
                ],
              ),
            ),
            // Modo lectura: ícono para ver todos los socios
            if (soloLectura && tarea.sociosList.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.people_outline,
                    color: AppColors.accentBlue, size: 20),
                tooltip: 'Ver socios',
                onPressed: onInfo,
              ),
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: AppColors.accentBlue, size: 20),
                tooltip: 'Editar tarea',
                onPressed: onEdit,
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.danger, size: 20),
                tooltip: 'Eliminar tarea',
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FORMULARIO TAREA
// ═══════════════════════════════════════════════════════════════════════════════
class TareaFormScreen extends StatefulWidget {
  final String idPlan;
  final String usuario;
  final Tarea? tareaExistente;   // null = nueva tarea, != null = editar
  const TareaFormScreen({
    super.key,
    required this.idPlan,
    required this.usuario,
    this.tareaExistente,
  });

  @override
  State<TareaFormScreen> createState() => _TareaFormScreenState();
}

class _TareaFormScreenState extends State<TareaFormScreen> {
  late DateTime _fecha;
  late String _horaInicio;
  late String _horaFin;
  String? _codigoPta;   // sección de nivel 1: '1','2','3','4','5','6'
  String? _idPta;       // idPta de la hoja (ej. 'idpta033')
  late String _provincia;
  late String _distrito;
  String? _comunidad;
  final _detalleCtrl    = TextEditingController();

  // Socios seleccionados
  List<SocioModel> _sociosSeleccionados = [];

  @override
  void initState() {
    super.initState();
    final t = widget.tareaExistente;
    if (t != null) {
      // Editar tarea existente — pre-cargar todos los campos
      _fecha      = t.fecha;
      _horaInicio = t.horaInicio;
      _horaFin    = t.horaFinal;
      // Normalizar al codigo canónico; soporta registros legacy 'idptaXXX'
      _idPta     = t.idPta.isNotEmpty ? PtaCatalog.normalizarACodigo(t.idPta) : null;
      _codigoPta = PtaCatalog.codigoRaizFromIdPta(t.idPta);
      _provincia  = t.provincia.isNotEmpty
          ? t.provincia
          : CatalogData.provincias.first;
      _distrito   = t.distrito.isNotEmpty
          ? t.distrito
          : CatalogData.distritosPorProvincia[_provincia]!.first;
      _comunidad  = t.comunidad.isNotEmpty ? t.comunidad : null;
      _detalleCtrl.text = t.detallePta;
      // Reconstruir socios desde JSON guardado
      if (t.sociosJson.isNotEmpty) {
        try {
          final refs = jsonDecode(t.sociosJson) as List;
          _sociosSeleccionados = refs
              .map((r) => SocioModel.fromRef(Map<String, dynamic>.from(r as Map)))
              .toList();
        } catch (_) {}
      }
    } else {
      // Nueva tarea — valores por defecto
      _fecha      = DateTime.now();
      _horaInicio = '08:00';
      _horaFin    = '17:00';
      _provincia  = CatalogData.provincias.first;
      _distrito   = CatalogData.distritosPorProvincia[
              CatalogData.provincias.first]!
          .first;
    }
  }

  @override
  void dispose() {
    _detalleCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_idPta == null || _comunidad == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Seleccione la tarea y comunidad')));
      return;
    }

    final sociosJson = _sociosSeleccionados.isEmpty
        ? ''
        : jsonEncode(_sociosSeleccionados.map((s) => s.toRef()).toList());

    final tarea = Tarea(
      // Conservar el mismo ID al editar para no duplicar la tarea
      id:            widget.tareaExistente?.id ?? const Uuid().v4().substring(0, 8),
      idPlanTrabajo: widget.idPlan,
      fecha:         _fecha,
      horaInicio:    _horaInicio,
      horaFinal:     _horaFin,
      idPta:         _idPta!,
      provincia:     _provincia,
      distrito:      _distrito,
      comunidad:     _comunidad!,
      detallePta:    _detalleCtrl.text,
      usuario:       widget.usuario,
      sociosJson:    sociosJson,
    );
    Navigator.pop(context, tarea);
  }

  Future<void> _seleccionarSocios() async {
    if (_comunidad == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Primero seleccione una comunidad')));
      return;
    }
    final resultado = await showModalBottomSheet<List<SocioModel>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _SocioSelectorSheet(
        comunidad: _comunidad!,
        seleccionados: _sociosSeleccionados,
      ),
    );
    if (resultado != null) {
      setState(() => _sociosSeleccionados = resultado);
    }
  }

  @override
  Widget build(BuildContext context) {
    final distritos = CatalogData.distritosPorProvincia[_provincia] ?? [];
    final comunidades =
        CatalogData.comunidadesPorDistrito[_distrito] ?? [];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context)),
        title: Text(widget.tareaExistente != null ? 'Editar Tarea' : 'Nueva Tarea'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton(
              onPressed: _save,
              child: const Text('Guardar'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FECHA
            const FieldLabel('Fecha de la tarea', required: true),
            DatePickerField(
                value: _fecha,
                onChanged: (d) => setState(() => _fecha = d)),
            const SizedBox(height: 14),

            // HORA INICIO
            const FieldLabel('Hora de inicio', required: true),
            TimePickerField(
                value: _horaInicio,
                onChanged: (t) => setState(() => _horaInicio = t)),
            const SizedBox(height: 14),

            // HORA FIN
            const FieldLabel('Hora de finalización', required: true),
            TimePickerField(
                value: _horaFin,
                onChanged: (t) => setState(() => _horaFin = t)),
            const SizedBox(height: 14),

            // TAREA — selector de 2 niveles: Código → Indicador/Tarea
            const FieldLabel('Código (sección PTA)', required: true),
            DropdownButtonFormField<String>(
              value: _codigoPta,
              decoration: const InputDecoration(hintText: 'Seleccionar sección...'),
              isExpanded: true,
              items: PtaCatalog.topLevelEntries
                  .map((e) => DropdownMenuItem(
                        value: e.codigoRaiz,
                        child: Text(e.indicadoresTareas,
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() {
                _codigoPta = v;
                _idPta = null; // resetear indicador al cambiar sección
              }),
            ),
            const SizedBox(height: 14),

            const FieldLabel('Indicador / Tarea', required: true),
            DropdownButtonFormField<String>(
              key: ValueKey('tarea_plan_$_codigoPta'),
              value: _idPta,
              decoration: InputDecoration(
                hintText: _codigoPta == null
                    ? 'Primero seleccione el código…'
                    : 'Seleccionar tarea…',
              ),
              isExpanded: true,
              items: _codigoPta == null
                  ? []
                  : PtaCatalog.leafEntriesUnderCode(_codigoPta!)
                      .map((e) => DropdownMenuItem(
                            // ← valor canónico = codigo ('1.1.1', '2.1.2.1'…)
                            value: e.codigo,
                            child: Text(
                              '[${e.codigo}] ${e.indicadoresTareas}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
              onChanged: _codigoPta == null
                  ? null
                  : (v) => setState(() => _idPta = v),
            ),
            const SizedBox(height: 14),

            // PROVINCIA
            const FieldLabel('Provincia', required: true),
            ChipSelector(
              options: CatalogData.provincias,
              selected: _provincia,
              onSelected: (v) => setState(() {
                _provincia = v;
                _distrito =
                    CatalogData.distritosPorProvincia[v]!.first;
                _comunidad = null;
                _sociosSeleccionados = [];
              }),
            ),
            const SizedBox(height: 14),

            // DISTRITO
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
              onChanged: (v) => setState(() {
                _distrito  = v!;
                _comunidad = null;
                _sociosSeleccionados = [];
              }),
            ),
            const SizedBox(height: 14),

            // COMUNIDAD
            const FieldLabel('Comunidad / Sector', required: true),
            DropdownButtonFormField<String>(
              value: _comunidad,
              decoration:
                  const InputDecoration(hintText: 'Seleccionar...'),
              items: comunidades
                  .map((c) =>
                      DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() {
                _comunidad           = v;
                _sociosSeleccionados = [];
              }),
            ),
            const SizedBox(height: 14),

            // SOCIOS
            const FieldLabel('Socios a visitar'),
            if (_sociosSeleccionados.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _sociosSeleccionados
                    .map((s) => Chip(
                          label: Text(s.nombreCompleto,
                              style: const TextStyle(fontSize: 11)),
                          onDeleted: () => setState(() =>
                              _sociosSeleccionados.remove(s)),
                          deleteIconColor: AppColors.danger,
                          backgroundColor: AppColors.accentBlue.withOpacity(0.1),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              onPressed: _seleccionarSocios,
              icon: const Icon(Icons.people_outline, size: 16),
              label: Text(
                _sociosSeleccionados.isEmpty
                    ? 'Seleccionar socios de la comunidad'
                    : 'Cambiar selección (${_sociosSeleccionados.length})',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentBlue,
                side: const BorderSide(color: AppColors.accentBlue),
              ),
            ),
            const SizedBox(height: 14),

            // DETALLE
            const FieldLabel('Detalle de la tarea'),
            TextFormField(
              controller: _detalleCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                  hintText: 'Descripción detallada...'),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACCIONES ADMIN DENTRO DEL FORMULARIO DEL PLAN
// Mismo patrón que _AccionesFatSection en fat_screen.dart.
// Visible para admin/coordinador cuando el plan ya tiene estado.
// ═══════════════════════════════════════════════════════════════════════════════
class _AccionesAdminPlan extends StatelessWidget {
  final PlanTrabajo? planExistente;
  const _AccionesAdminPlan({required this.planExistente});

  @override
  Widget build(BuildContext context) {
    if (planExistente == null) return const SizedBox.shrink();

    final usuario = context.read<SesionProvider>().usuario;
    if (usuario == null) return const SizedBox.shrink();

    final esAdmin = usuario.rol.toUpperCase() == 'ADMINISTRADOR';
    final esCoord = !esAdmin &&
        (usuario.cargo.toUpperCase().contains('COORDINADOR') ||
            usuario.rol.toUpperCase() == 'COORDINADOR');
    if (!esAdmin && !esCoord) return const SizedBox.shrink();

    final estado = planExistente!.estado;
    final prov   = context.read<PlanProvider>();

    // Qué acciones están disponibles
    final puedeAprobar   = estado == 'ENVIADO';
    final puedeObservar  = estado == 'ENVIADO';
    final puedeRegistrar = esAdmin && estado != 'REGISTRADO';
    final puedeEnviar    = esAdmin &&
        (estado == 'REGISTRADO' || estado == 'OBSERVADO');

    if (!puedeAprobar && !puedeObservar && !puedeRegistrar && !puedeEnviar) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 6),
        const Text('Acciones',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (puedeEnviar)
              ElevatedButton.icon(
                onPressed: () =>
                    _enviar(context, planExistente!.id, prov, usuario.dni),
                icon: const Icon(Icons.send, size: 14),
                label: const Text('ENVIAR',
                    style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary),
              ),
            if (puedeAprobar)
              ElevatedButton.icon(
                onPressed: () =>
                    _aprobar(context, planExistente!.id, prov, usuario.dni),
                icon: const Icon(Icons.check, size: 14),
                label: const Text('APROBAR',
                    style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success),
              ),
            if (puedeObservar)
              OutlinedButton.icon(
                onPressed: () =>
                    _observar(context, planExistente!.id, prov),
                icon: const Icon(Icons.warning_amber,
                    size: 14, color: AppColors.warning),
                label: const Text('OBSERVAR',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.warning)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.warning)),
              ),
            if (puedeRegistrar)
              OutlinedButton.icon(
                onPressed: () =>
                    _registrar(context, planExistente!.id, prov),
                icon: const Icon(Icons.refresh,
                    size: 14, color: AppColors.primary),
                label: const Text('VOLVER A REGISTRADO',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.primary)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary)),
              ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _enviar(BuildContext context, String planId,
      PlanProvider prov, String dni) async {
    final ok = await prov.enviarPlan(planId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '✅ Plan enviado' : '❌ ${prov.error}'),
      backgroundColor: ok ? AppColors.success : AppColors.danger,
    ));
    if (ok) {
      prov.cargarPlanes(usuario: dni);
      Navigator.pop(context);
    }
  }

  Future<void> _aprobar(BuildContext context, String planId,
      PlanProvider prov, String dni) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aprobar Plan'),
        content: const Text('¿Confirmas la aprobación de este plan?'),
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
    if (confirmar != true || !context.mounted) return;
    final ok = await prov.aprobarPlan(planId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '✅ Plan aprobado' : '❌ ${prov.error}'),
      backgroundColor: ok ? AppColors.success : AppColors.danger,
    ));
    if (ok) {
      prov.cargarPlanes(usuario: dni);
      Navigator.pop(context);
    }
  }

  Future<void> _observar(
      BuildContext context, String planId, PlanProvider prov) async {
    final ctrl = TextEditingController();
    final obs = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Observar Plan'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
              hintText: 'Escribe las observaciones…',
              border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                Navigator.pop(context, ctrl.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning),
            child: const Text('Observar'),
          ),
        ],
      ),
    );
    if (obs == null || !context.mounted) return;
    final ok = await prov.observarPlan(planId, obs);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '⚠️ Plan observado' : '❌ ${prov.error}'),
      backgroundColor: ok ? AppColors.warning : AppColors.danger,
    ));
    if (ok) Navigator.pop(context);
  }

  Future<void> _registrar(
      BuildContext context, String planId, PlanProvider prov) async {
    final ok = await prov.registrarPlan(planId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '🔄 Vuelto a REGISTRADO' : '❌ ${prov.error}'),
      backgroundColor: ok ? AppColors.primary : AppColors.danger,
    ));
    if (ok) Navigator.pop(context);
  }
}

// ── BARRA DE PROGRESO DEL PLAN (visitas completadas) ─────────────────────────
class _ProgresoPlan extends StatelessWidget {
  final PlanTrabajo plan;
  const _ProgresoPlan({required this.plan});

  @override
  Widget build(BuildContext context) {
    int total = 0;
    int hechas = 0;
    for (final t in plan.tareas) {
      total += t.totalSocios;
      hechas += t.completados;
    }
    if (total == 0) return const SizedBox.shrink();
    final pct = hechas / total;
    final color = pct >= 1
        ? AppColors.success
        : pct >= 0.5
            ? AppColors.accentBlue
            : AppColors.warning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_outline, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              '$hechas / $total visitas completadas',
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              '${(pct * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 5,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SELECTOR DE SOCIOS (bottom sheet)
// ═══════════════════════════════════════════════════════════════════════════════
class _SocioSelectorSheet extends StatefulWidget {
  final String comunidad;
  final List<SocioModel> seleccionados;
  const _SocioSelectorSheet(
      {required this.comunidad, required this.seleccionados});

  @override
  State<_SocioSelectorSheet> createState() => _SocioSelectorSheetState();
}

class _SocioSelectorSheetState extends State<_SocioSelectorSheet> {
  final _busqCtrl   = TextEditingController();
  final _service    = SocioService();
  List<SocioModel> _todos    = [];
  List<SocioModel> _filtrados = [];
  late List<SocioModel> _seleccionados;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _seleccionados = List.from(widget.seleccionados);
    _cargarSocios();
    _busqCtrl.addListener(_filtrar);
  }

  @override
  void dispose() {
    _busqCtrl.removeListener(_filtrar);
    _busqCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarSocios() async {
    try {
      _todos     = await _service.getSociosPorComunidad(widget.comunidad);
      _filtrados = List.from(_todos);
      _error     = null;
      // ignore: avoid_print
      print('✅ _SocioSelectorSheet: ${_todos.length} socios cargados');
    } catch (e) {
      _error = e.toString();
      // ignore: avoid_print
      print('❌ _SocioSelectorSheet error: $e');
    }
    if (mounted) setState(() => _cargando = false);
  }

  void _filtrar() {
    final q = _busqCtrl.text;
    setState(() {
      if (q.isEmpty) {
        _filtrados = List.from(_todos);
      } else {
        final qu = q.toUpperCase();
        _filtrados = _todos
            .where((s) =>
                s.nombreCompleto.contains(qu) || s.dni.contains(qu))
            .toList();
      }
    });
  }

  bool _estaSeleccionado(SocioModel s) =>
      _seleccionados.any((x) => x.idSocio == s.idSocio);

  void _toggle(SocioModel s) {
    setState(() {
      if (_estaSeleccionado(s)) {
        _seleccionados.removeWhere((x) => x.idSocio == s.idSocio);
      } else {
        _seleccionados.add(s);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 12),
            // Encabezado
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Socios de la comunidad',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(widget.comunidad,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context, _seleccionados),
                  child: Text(
                    'Confirmar (${_seleccionados.length})',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Búsqueda
            TextField(
              controller: _busqCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o DNI…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _busqCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _busqCtrl.clear();
                          _filtrar();
                        })
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(height: 8),

            if (_cargando)
              const Expanded(
                  child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off,
                          size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 8),
                      const Text('Sin conexión o padrón no cargado',
                          style: TextStyle(
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(_error!,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.red)),
                    ],
                  ),
                ),
              )
            else if (_filtrados.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('No se encontraron socios',
                      style:
                          TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _filtrados.length,
                  itemBuilder: (_, i) {
                    final s = _filtrados[i];
                    final sel = _estaSeleccionado(s);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: sel
                            ? AppColors.primary
                            : Colors.grey.shade200,
                        child: sel
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 16)
                            : Text(
                                s.nombreCompleto.isNotEmpty
                                    ? s.nombreCompleto[0]
                                    : '?',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                      ),
                      title: Text(
                        s.nombreCompleto,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        'DNI: ${s.dni}  ·  ${s.totalHa} ha',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: s.celular.isNotEmpty
                          ? Text(s.celular,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary))
                          : null,
                      selected: sel,
                      selectedTileColor:
                          AppColors.primary.withOpacity(0.05),
                      onTap: () => _toggle(s),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
