import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../core/catalog.dart';
import '../../models/plan_trabajo.dart';
import '../../providers/plan_provider.dart';
import '../../providers/auth_provider.dart';
import 'fat_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MI DÍA DE TRABAJO
//
// Muestra las tareas programadas del usuario para una fecha (por defecto HOY)
// con la lista de socios. Cada socio tiene un atajo "Hacer FAT" que pre-llena
// el formulario con los datos de la tarea (comunidad, distrito, idPta) y del
// socio (id, nombre, dni). Al guardar la FAT, el socio queda marcado como
// COMPLETADO en el plan de trabajo.
// ═══════════════════════════════════════════════════════════════════════════════
class MiDiaScreen extends StatefulWidget {
  const MiDiaScreen({super.key});

  @override
  State<MiDiaScreen> createState() => _MiDiaScreenState();
}

class _MiDiaScreenState extends State<MiDiaScreen> {
  DateTime _fecha = DateTime.now();
  List<Tarea> _tareas = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    final usuario = context.read<SesionProvider>().usuario;
    if (usuario == null) {
      setState(() { _cargando = false; _tareas = []; });
      return;
    }
    try {
      final prov = context.read<PlanProvider>();
      final tareas = await prov.tareasDelDia(usuario.dni, _fecha);
      if (!mounted) return;
      setState(() { _tareas = tareas; _cargando = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _cargando = false; _tareas = []; _error = e.toString(); });
    }
  }

  Future<void> _cambiarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _fecha = picked);
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final esHoy = _esMismaFecha(_fecha, DateTime.now());
    final maxWidth = MediaQuery.of(context).size.width;
    final useWide = maxWidth > 720;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mi día de trabajo',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(
              esHoy
                  ? 'Hoy · ${DateFormat('EEEE d MMM y', 'es').format(_fecha)}'
                  : DateFormat('EEEE d MMM y', 'es').format(_fecha),
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Cambiar fecha',
            onPressed: _cambiarFecha,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: _cargar,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: useWide ? 720 : double.infinity),
          child: _cargando
              ? const SizedBox.expand(
                  child: Center(child: CircularProgressIndicator()))
              : _error != null
                  ? _errorView()
                  : _tareas.isEmpty
                      ? _vacio()
                      : RefreshIndicator(
                          onRefresh: _cargar,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                            children: [
                              _resumenDia(),
                              const SizedBox(height: 12),
                              ..._tareas.map((t) => _TareaDelDia(
                                    tarea: t,
                                    onSocioFat: (socio) =>
                                        _hacerFat(t, socio),
                                  )),
                            ],
                          ),
                        ),
        ),
      ),
    );
  }

  Widget _vacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            const Text(
              'No tienes visitas programadas para esta fecha',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _cambiarFecha,
              icon: const Icon(Icons.calendar_today, size: 16),
              label: const Text('Elegir otra fecha'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            const Text(
              'No se pudieron cargar las tareas',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resumenDia() {
    int totalSocios = 0;
    int completados = 0;
    for (final t in _tareas) {
      totalSocios += t.totalSocios;
      completados += t.completados;
    }
    final pct = totalSocios == 0 ? 0.0 : completados / totalSocios;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.10),
            AppColors.primary.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined,
                  color: AppColors.primaryDark, size: 18),
              const SizedBox(width: 6),
              Text(
                '${_tareas.length} ${_tareas.length == 1 ? "tarea" : "tareas"} · '
                '$completados de $totalSocios visitas completadas',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                    fontSize: 13),
              ),
            ],
          ),
          if (totalSocios > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: Colors.white,
                valueColor: const AlwaysStoppedAnimation(AppColors.success),
              ),
            ),
            const SizedBox(height: 4),
            Text('${(pct * 100).toStringAsFixed(0)}% del día',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }

  Future<void> _hacerFat(Tarea tarea, Map<String, String> socio) async {
    if (tarea.socioCompletado(socio['id'] ?? '')) {
      final idFat = tarea.sociosCompletadosMap[socio['id']];
      if (idFat == null) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Este socio ya tiene FAT (${idFat.substring(0, 8)}...)'),
        backgroundColor: AppColors.success,
      ));
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FatFormScreen(
          tareaOrigen: tarea,
          socioOrigen: socio,
        ),
      ),
    );
    if (mounted) _cargar();
  }

  bool _esMismaFecha(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TARJETA DE TAREA DEL DÍA con sus socios
// ═══════════════════════════════════════════════════════════════════════════════
class _TareaDelDia extends StatelessWidget {
  final Tarea tarea;
  final void Function(Map<String, String> socio) onSocioFat;

  const _TareaDelDia({required this.tarea, required this.onSocioFat});

  @override
  Widget build(BuildContext context) {
    final completa = tarea.tareaCompleta;
    final color = completa ? AppColors.success : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera de la tarea
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${tarea.horaInicio} – ${tarea.horaFinal}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    CatalogData.labelFromIdPta(tarea.idPta),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (completa)
                  const Icon(Icons.check_circle,
                      color: AppColors.success, size: 20),
              ],
            ),
          ),
          // Ubicación
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${tarea.comunidad} · ${tarea.distrito}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
                Text(
                  '${tarea.completados}/${tarea.totalSocios}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: completa ? AppColors.success : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          // Socios
          if (tarea.sociosList.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Sin socios programados en esta tarea',
                style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                    fontStyle: FontStyle.italic),
              ),
            )
          else
            ...tarea.sociosList.map((s) {
              final completado = tarea.socioCompletado(s['id'] ?? '');
              return _SocioRow(
                socio: s,
                completado: completado,
                onFat: () => onSocioFat(s),
              );
            }),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _SocioRow extends StatelessWidget {
  final Map<String, String> socio;
  final bool completado;
  final VoidCallback onFat;
  const _SocioRow({
    required this.socio,
    required this.completado,
    required this.onFat,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: completado ? null : onFat,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: completado
                  ? AppColors.success
                  : AppColors.accentBlue.withOpacity(0.15),
              child: completado
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text(
                      (socio['nombre'] ?? '?').isNotEmpty
                          ? socio['nombre']![0]
                          : '?',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentBlue),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    socio['nombre'] ?? '—',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: completado
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      decoration: completado
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  if ((socio['dni'] ?? '').isNotEmpty)
                    Text(
                      'DNI ${socio['dni']}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            if (completado)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.success.withOpacity(0.4)),
                ),
                child: const Text('FAT lista',
                    style: TextStyle(
                        fontSize: 10,
                        color: AppColors.success,
                        fontWeight: FontWeight.bold)),
              )
            else
              ElevatedButton.icon(
                onPressed: onFat,
                icon: const Icon(Icons.assignment_add, size: 14),
                label: const Text('Hacer FAT',
                    style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  textStyle: const TextStyle(fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
