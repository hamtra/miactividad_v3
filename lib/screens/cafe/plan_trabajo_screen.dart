import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../core/catalog.dart';
import '../../models/plan_trabajo.dart';
import '../../providers/plan_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/form_widgets.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// LISTA DE PLANES DE TRABAJO
// ═══════════════════════════════════════════════════════════════════════════════
class PlanTrabajoScreen extends StatefulWidget {
  const PlanTrabajoScreen({super.key});

  @override
  State<PlanTrabajoScreen> createState() => _PlanTrabajoScreenState();
}

class _PlanTrabajoScreenState extends State<PlanTrabajoScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final usuario = context.read<AuthProvider>().usuario;
      context
          .read<PlanProvider>()
          .cargarPlanes(usuario: usuario?.dni);
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PlanProvider>();
    final usuario = context.read<AuthProvider>().usuario;

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
              MaterialPageRoute(
                  builder: (_) => const PlanTrabajoFormScreen()),
            ).then((_) =>
                prov.cargarPlanes(usuario: usuario?.dni)),
          ),
        ],
      ),
      body: prov.cargando
          ? const Center(child: CircularProgressIndicator())
          : prov.planes.isEmpty
              ? _buildEmpty(context, usuario, prov)
              : _buildList(context, prov, usuario),
    );
  }

  Widget _buildEmpty(
      BuildContext context, UsuarioSesion? usuario, PlanProvider prov) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined,
              size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('Sin planes registrados',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
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

  Widget _buildList(
      BuildContext context, PlanProvider prov, UsuarioSesion? usuario) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: prov.planes.length,
      itemBuilder: (ctx, i) {
        final plan = prov.planes[i];
        return _PlanCard(
          plan: plan,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    PlanTrabajoFormScreen(planExistente: plan)),
          ).then((_) => prov.cargarPlanes(usuario: usuario?.dni)),
          onEnviar: plan.estado == 'REGISTRADO'
              ? () async {
                  await prov.cambiarEstado(plan.id, 'ENVIADO');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Plan enviado correctamente')));
                  }
                }
              : null,
        );
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanTrabajo plan;
  final VoidCallback onTap;
  final VoidCallback? onEnviar;
  const _PlanCard(
      {required this.plan, required this.onTap, this.onEnviar});

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
              const SizedBox(height: 6),
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
              if (onEnviar != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: onEnviar,
                    icon: const Icon(Icons.send, size: 14),
                    label: const Text('ENVIAR',
                        style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6)),
                  ),
                ),
              ],
            ],
          ),
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

  @override
  void initState() {
    super.initState();
    final p = widget.planExistente;
    _id = p?.id ?? const Uuid().v4().toUpperCase();
    _mes = p?.mes ?? _mesActual();
    _fecha = p?.fechaCreacion ?? DateTime.now();
    _tareas = List.from(p?.tareas ?? []);
  }

  String _mesActual() {
    final m = DateTime.now().month;
    return CatalogData.meses[m - 1];
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? true)) return;
    final usuario =
        context.read<AuthProvider>().usuario;
    if (usuario == null) return;

    final plan = PlanTrabajo(
      id: _id,
      mes: _mes,
      idTecEspExt: usuario.idTecEspExt,
      nombreTecnico: usuario.nombreCompleto,
      nombreActividad: CatalogData.nombreActividad,
      fechaCreacion: _fecha,
      idCoordinador: 'idus01',
      nombreCoordinador: 'SALGADO VERAMENDI DEYVER',
      estado: widget.planExistente?.estado ?? 'REGISTRADO',
      usuario: usuario.dni,
      tareas: _tareas,
    );

    final prov = context.read<PlanProvider>();
    bool ok;
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

  void _addTarea() async {
    final usuario = context.read<AuthProvider>().usuario;
    final result = await Navigator.push<Tarea>(
      context,
      MaterialPageRoute(
          builder: (_) => TareaFormScreen(idPlan: _id, usuario: usuario?.dni ?? '')),
    );
    if (result != null) setState(() => _tareas.add(result));
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.read<AuthProvider>().usuario;
    final isEdit = widget.planExistente != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context)),
        title: Text(isEdit ? 'Editar Plan' : 'Nuevo Plan'),
        actions: [
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
              // ── ID (solo lectura) ────────────────────────────────────────
              const FieldLabel('idPlanTrabajo'),
              ReadOnlyField(_id.substring(0, 8) + '...'),
              const SizedBox(height: 14),

              // ── MES ──────────────────────────────────────────────────────
              const FieldLabel('Seleccione el mes', required: true),
              DropdownButtonFormField<String>(
                value: _mes,
                decoration: const InputDecoration(),
                items: CatalogData.meses
                    .map((m) =>
                        DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() => _mes = v!),
              ),
              const SizedBox(height: 14),

              // ── TÉCNICO ──────────────────────────────────────────────────
              const FieldLabel('Técnico / Especialista / Extensionista'),
              ReadOnlyField(
                  usuario?.nombreCompleto ?? '',
                  color: AppColors.accentBlue),
              const SizedBox(height: 14),

              // ── FECHA ────────────────────────────────────────────────────
              const FieldLabel('Fecha elaboración del plan', required: true),
              DatePickerField(
                  value: _fecha,
                  onChanged: (d) => setState(() => _fecha = d)),
              const SizedBox(height: 14),

              // ── COORDINADOR ──────────────────────────────────────────────
              const FieldLabel('Coordinador asignado'),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text('SALGADO VERAMENDI DEYVER',
                    style: TextStyle(fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 20),

              // ── TAREAS ───────────────────────────────────────────────────
              const SectionTitle(
                  'Tareas a realizar (por día) durante el mes'),
              const SizedBox(height: 10),

              ..._tareas.asMap().entries.map((e) => _TareaItem(
                    index: e.key + 1,
                    tarea: e.value,
                    onDelete: () =>
                        setState(() => _tareas.removeAt(e.key)),
                  )),

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
                      Icon(Icons.add,
                          color: AppColors.accentBlue, size: 18),
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

class _TareaItem extends StatelessWidget {
  final int index;
  final Tarea tarea;
  final VoidCallback onDelete;
  const _TareaItem(
      {required this.index, required this.tarea, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final tareaLabel = CatalogData.labelFromIdPta(tarea.idPta);
    return Container(
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
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 10),
                ),
              ],
            ),
          ),
          IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.danger, size: 20),
              onPressed: onDelete),
        ],
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
  const TareaFormScreen(
      {super.key, required this.idPlan, required this.usuario});

  @override
  State<TareaFormScreen> createState() => _TareaFormScreenState();
}

class _TareaFormScreenState extends State<TareaFormScreen> {
  DateTime _fecha = DateTime.now();
  String _horaInicio = '08:00';
  String _horaFin = '17:00';
  String? _idPta;
  String _provincia = CatalogData.provincias.first;
  String _distrito = CatalogData.distritosPorProvincia[
          CatalogData.provincias.first]!
      .first;
  String? _comunidad;
  final _detalleCtrl = TextEditingController();

  @override
  void dispose() {
    _detalleCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_idPta == null || _comunidad == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Seleccione la tarea y comunidad')));
      return;
    }
    final tarea = Tarea(
      id: const Uuid().v4().substring(0, 8),
      idPlanTrabajo: widget.idPlan,
      fecha: _fecha,
      horaInicio: _horaInicio,
      horaFinal: _horaFin,
      idPta: _idPta!,
      provincia: _provincia,
      distrito: _distrito,
      comunidad: _comunidad!,
      detallePta: _detalleCtrl.text,
      usuario: widget.usuario,
    );
    Navigator.pop(context, tarea);
  }

  @override
  Widget build(BuildContext context) {
    final distritos =
        CatalogData.distritosPorProvincia[_provincia] ?? [];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Nueva Tarea'),
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
            const FieldLabel('Fecha de la tarea', required: true),
            DatePickerField(
                value: _fecha,
                onChanged: (d) => setState(() => _fecha = d)),
            const SizedBox(height: 14),

            const FieldLabel('Hora de inicio', required: true),
            TimePickerField(
                value: _horaInicio,
                onChanged: (t) => setState(() => _horaInicio = t)),
            const SizedBox(height: 14),

            const FieldLabel('Hora de finalización', required: true),
            TimePickerField(
                value: _horaFin,
                onChanged: (t) => setState(() => _horaFin = t)),
            const SizedBox(height: 14),

            const FieldLabel('Seleccione la tarea', required: true),
            DropdownButtonFormField<String>(
              value: _idPta,
              decoration: const InputDecoration(hintText: 'Seleccionar...'),
              items: CatalogData.tareasPorId.entries
                  .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value,
                          overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => _idPta = v),
            ),
            const SizedBox(height: 14),

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
              decoration: const InputDecoration(hintText: 'Seleccionar...'),
              items: CatalogData.comunidades
                  .map((c) =>
                      DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _comunidad = v),
            ),
            const SizedBox(height: 14),

            const FieldLabel('Detalle de la tarea'),
            TextFormField(
              controller: _detalleCtrl,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Descripción detallada...'),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
