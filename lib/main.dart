import 'package:flutter/material.dart';
import 'dart:math';
import 'package:intl/intl.dart';

void main() {
  runApp(const MiActividadApp());
}

// ─── THEME ────────────────────────────────────────────────────────────────────
class AppColors {
  static const primary = Color(0xFF1B6E2F);
  static const primaryDark = Color(0xFF144F22);
  static const primaryLight = Color(0xFF2E9448);
  static const accent = Color(0xFF4CAF50);
  static const accentBlue = Color(0xFF1976D2);
  static const surface = Color(0xFFF8FBF8);
  static const cardBg = Colors.white;
  static const border = Color(0xFFDDE8DD);
  static const textPrimary = Color(0xFF1A2E1A);
  static const textSecondary = Color(0xFF5A7A5A);
  static const chipSelected = Color(0xFF1976D2);
  static const chipUnselected = Color(0xFFEEEEEE);
  static const danger = Color(0xFFE53935);
}

// ─── APP ──────────────────────────────────────────────────────────────────────
class MiActividadApp extends StatelessWidget {
  const MiActividadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MiActividad',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: AppColors.surface,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: false,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      home: const MainMenuScreen(),
    );
  }
}

// ─── HELPERS ──────────────────────────────────────────────────────────────────
String generateUUID() {
  final rng = Random();
  const chars = '0123456789ABCDEF';
  String hex(int n) =>
      List.generate(n, (_) => chars[rng.nextInt(16)]).join();
  return '${hex(8)}-${hex(4)}-4${hex(3)}-${hex(4)}-${hex(12)}';
}

String formatDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
String formatDateTime(DateTime d) =>
    DateFormat('dd/MM/yyyy HH:mm:ss').format(d);
String formatTime(DateTime d) => DateFormat('HH:mm').format(d);

// ─── MAIN MENU ────────────────────────────────────────────────────────────────
class _MenuCategory {
  final String label;
  final String sub;
  final IconData icon;
  final Color iconColor;
  final Widget? route;
  const _MenuCategory(
      {required this.label,
      required this.sub,
      required this.icon,
      required this.iconColor,
      this.route});
}

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = [
      _MenuCategory(
        label: 'CAFÉ',
        sub: 'Cafe',
        icon: Icons.eco,
        iconColor: AppColors.primary,
        route: const CafeMenuScreen(),
      ),
      _MenuCategory(
          label: 'CACAO',
          sub: 'Cacao',
          icon: Icons.spa,
          iconColor: const Color(0xFF795548)),
      _MenuCategory(
          label: 'APÍCOLA',
          sub: 'Apicola',
          icon: Icons.hive,
          iconColor: const Color(0xFFFFA000)),
      _MenuCategory(
          label: 'ASOCIATIVIDAD',
          sub: 'Asociatividad',
          icon: Icons.people_alt,
          iconColor: const Color(0xFF1565C0)),
      _MenuCategory(
          label: 'ALMACÉN',
          sub: 'Insumos',
          icon: Icons.warehouse,
          iconColor: const Color(0xFF546E7A)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('MiActividad',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.account_circle), onPressed: () {}),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('menu general',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: categories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (ctx, i) => _CategoryCard(cat: categories[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final _MenuCategory cat;
  const _CategoryCard({required this.cat});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (cat.route != null) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => cat.route!));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${cat.label} - próximamente')));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cat.iconColor, width: 2.5),
                color: cat.iconColor.withOpacity(0.07),
              ),
              child: Icon(cat.icon, size: 36, color: cat.iconColor),
            ),
            const SizedBox(height: 10),
            Text(cat.label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(cat.sub,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ─── CAFÉ SUBMENU ─────────────────────────────────────────────────────────────
class _CafeSubItem {
  final String label;
  final String sub;
  final IconData icon;
  final Widget? route;
  const _CafeSubItem(
      {required this.label,
      required this.sub,
      required this.icon,
      this.route});
}

class CafeMenuScreen extends StatelessWidget {
  const CafeMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _CafeSubItem(
          label: 'PLAN DE TRABAJO',
          sub: 'Plan de trabajo',
          icon: Icons.assignment,
          route: const PlanTrabajoScreen()),
      _CafeSubItem(
          label: 'FAT',
          sub: 'F.A.T',
          icon: Icons.people,
          route: const FATScreen()),
      _CafeSubItem(
          label: 'TRAZABILIDAD',
          sub: 'Trazabilidad',
          icon: Icons.track_changes),
      _CafeSubItem(
          label: 'SUPERVISIÓN',
          sub: 'F.A.T. Supervisión',
          icon: Icons.calendar_today),
      _CafeSubItem(
          label: 'A7', sub: 'Prospección', icon: Icons.map_outlined),
      _CafeSubItem(label: 'FSAM', sub: 'FSAM', icon: Icons.search),
      _CafeSubItem(
          label: 'SENASA', sub: 'SENASA', icon: Icons.verified_outlined),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('menu general',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const Icon(Icons.chevron_right, size: 16, color: Colors.white54),
            const Text('4Cafe.menu',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.05,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemBuilder: (ctx, i) {
          final item = items[i];
          return GestureDetector(
            onTap: () {
              if (item.route != null) {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => item.route!));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${item.label} - próximamente')));
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.primary, width: 2.5),
                      color: AppColors.primary.withOpacity(0.07),
                    ),
                    child: Icon(item.icon,
                        size: 32, color: AppColors.primary),
                  ),
                  const SizedBox(height: 8),
                  Text(item.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(item.sub,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 10)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── PLAN DE TRABAJO ──────────────────────────────────────────────────────────
class TareaItem {
  String fecha;
  String horaInicio;
  String horaFin;
  String tarea;
  String provincia;
  String distrito;
  String comunidad;
  List<String> socios;
  String detalle;

  TareaItem({
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
    required this.tarea,
    required this.provincia,
    required this.distrito,
    required this.comunidad,
    required this.socios,
    required this.detalle,
  });
}

class PlanTrabajoScreen extends StatefulWidget {
  const PlanTrabajoScreen({super.key});

  @override
  State<PlanTrabajoScreen> createState() => _PlanTrabajoScreenState();
}

class _PlanTrabajoScreenState extends State<PlanTrabajoScreen> {
  final _idCtrl = TextEditingController(text: generateUUID().toUpperCase());
  String _mes = 'MAYO';
  final _tecnico = 'TORRES CUADROS HAMILTON MARLON';
  final _coordinador = 'SALGADO VERAMENDI DEYVER';
  DateTime _fecha = DateTime.now();
  List<TareaItem> _tareas = [];

  final _meses = [
    'ENERO','FEBRERO','MARZO','ABRIL','MAYO','JUNIO',
    'JULIO','AGOSTO','SEPTIEMBRE','OCTUBRE','NOVIEMBRE','DICIEMBRE'
  ];

  @override
  void dispose() {
    _idCtrl.dispose();
    super.dispose();
  }

  void _addTarea() async {
    final result = await Navigator.push<TareaItem>(
      context,
      MaterialPageRoute(builder: (_) => const TareaFormScreen()),
    );
    if (result != null) setState(() => _tareas.add(result));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan de Trabajo'),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Plan guardado correctamente')));
            },
            child: const Text('GUARDAR',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FieldLabel('idPlanTrabajo *'),
            TextFormField(
              controller: _idCtrl,
              readOnly: true,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(),
            ),
            const SizedBox(height: 14),
            _FieldLabel('Seleccione el mes *'),
            DropdownButtonFormField<String>(
              value: _mes,
              decoration: const InputDecoration(),
              items: _meses
                  .map((m) =>
                      DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _mes = v!),
            ),
            const SizedBox(height: 14),
            _FieldLabel('Tecnico / Especialista / Extensionista'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.accentBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_tecnico,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 14),
            _FieldLabel('Fecha elaboración del plan *'),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _fecha,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) setState(() => _fecha = picked);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Expanded(child: Text(formatDateTime(_fecha))),
                    const Icon(Icons.calendar_today,
                        size: 18, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _FieldLabel('Coordinador asignado'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(_coordinador,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 20),
            _FieldLabel('Tareas a realizar (por día) durante el mes:'),
            const SizedBox(height: 8),
            ..._tareas.asMap().entries.map((e) => _TareaCard(
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
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Text('Nuevo',
                      style: TextStyle(
                          color: AppColors.accentBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _TareaCard extends StatelessWidget {
  final int index;
  final TareaItem tarea;
  final VoidCallback onDelete;
  const _TareaCard(
      {required this.index, required this.tarea, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
            decoration: BoxDecoration(
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
                Text(tarea.fecha,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${tarea.tarea} - ${tarea.comunidad}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
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

// ─── TAREA FORM ───────────────────────────────────────────────────────────────
class TareaFormScreen extends StatefulWidget {
  const TareaFormScreen({super.key});

  @override
  State<TareaFormScreen> createState() => _TareaFormScreenState();
}

class _TareaFormScreenState extends State<TareaFormScreen> {
  DateTime _fecha = DateTime.now();
  DateTime _horaInicio = DateTime.now();
  DateTime _horaFin =
      DateTime.now().add(const Duration(hours: 3));
  String? _tarea;
  String _provincia = 'CALCA';
  String _distrito = 'YANATILE';
  String? _comunidad;
  final List<String> _socios = [];
  final _detalle = TextEditingController();
  final _socioCtrl = TextEditingController();

  final _tareas = [
    'Asistencia técnica en campo',
    'Capacitación grupal',
    'Visita domiciliaria',
    'Reunión de coordinación',
    'Evaluación de parcela',
  ];

  final _provincias = ['CALCA', 'LA CONVENCION'];
  final _distritos = {
    'CALCA': ['YANATILE', 'CALCA', 'PISAQ', 'LAMAY'],
    'LA CONVENCION': ['MARANURA', 'SANTA ANA', 'HUAYOPATA', 'QUELLOUNO'],
  };
  final _comunidades = [
    'COMBAPATA', 'BEATRIZ BAJA', 'CHALLHUAHUACHO', 'PUCYURA', 'TRAPICHE'
  ];

  @override
  void dispose() {
    _detalle.dispose();
    _socioCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_tarea == null || _comunidad == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Complete los campos obligatorios')));
      return;
    }
    Navigator.pop(
      context,
      TareaItem(
        fecha: formatDate(_fecha),
        horaInicio: formatTime(_horaInicio),
        horaFin: formatTime(_horaFin),
        tarea: _tarea!,
        provincia: _provincia,
        distrito: _distrito,
        comunidad: _comunidad!,
        socios: List.from(_socios),
        detalle: _detalle.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final distritos = _distritos[_provincia] ?? [];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: const Text('4Cafe.Tarea Form'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white70))),
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
            _PageIndicator(current: 1, total: 1),
            const SizedBox(height: 16),
            _FieldLabel('Fecha de la tarea:'),
            _DatePickerField(
                value: _fecha,
                onChanged: (d) => setState(() => _fecha = d)),
            const SizedBox(height: 14),
            _FieldLabel('Hora de inicio:'),
            _TimePickerField(
                value: _horaInicio,
                onChanged: (d) => setState(() => _horaInicio = d)),
            const SizedBox(height: 14),
            _FieldLabel('Hora de finalización:'),
            _TimePickerField(
                value: _horaFin,
                onChanged: (d) => setState(() => _horaFin = d)),
            const SizedBox(height: 14),
            _FieldLabel('Seleccione la tarea:'),
            DropdownButtonFormField<String>(
              value: _tarea,
              decoration: const InputDecoration(hintText: 'Seleccionar...'),
              items: _tareas
                  .map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => _tarea = v),
            ),
            const SizedBox(height: 14),
            _FieldLabel('Provincia'),
            _ChipSelector(
              options: _provincias,
              selected: _provincia,
              onSelected: (v) => setState(() {
                _provincia = v;
                _distrito = (_distritos[v] ?? []).first;
              }),
            ),
            const SizedBox(height: 14),
            _FieldLabel('Distrito'),
            DropdownButtonFormField<String>(
              value: distritos.contains(_distrito) ? _distrito : distritos.first,
              decoration: const InputDecoration(),
              items: distritos
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) => setState(() => _distrito = v!),
            ),
            const SizedBox(height: 14),
            _FieldLabel('Comunidad / Sector'),
            DropdownButtonFormField<String>(
              value: _comunidad,
              decoration: const InputDecoration(hintText: 'Seleccionar...'),
              items: _comunidades
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _comunidad = v),
            ),
            const SizedBox(height: 14),
            _FieldLabel('Socio(s) participantes'),
            _SociosField(
              socios: _socios,
              controller: _socioCtrl,
              onAdd: () {
                if (_socioCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    _socios.add(_socioCtrl.text.trim().toUpperCase());
                    _socioCtrl.clear();
                  });
                }
              },
              onRemove: (i) => setState(() => _socios.removeAt(i)),
              onClear: () => setState(() => _socios.clear()),
            ),
            const SizedBox(height: 14),
            _FieldLabel('Detalle la tarea a realizar:'),
            TextFormField(
              controller: _detalle,
              maxLines: 3,
              decoration: const InputDecoration(hintText: ''),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// ─── FAT SCREEN ───────────────────────────────────────────────────────────────
class FATScreen extends StatefulWidget {
  const FATScreen({super.key});

  @override
  State<FATScreen> createState() => _FATScreenState();
}

class _FATScreenState extends State<FATScreen> {
  int _page = 0;
  final _pages = 4;

  // Page 1 – Identificación
  final _idFat = generateUUID().toUpperCase().substring(0, 35) + '...';
  String _numeroFicha = '${Random().nextInt(90000000) + 10000000}-124-1';
  DateTime _fecha = DateTime.now();
  String? _modalidad = 'b. Asistencia técnica';
  String? _etapa = 'Producción';
  String? _tarea;
  String? _tema;

  // Page 2 – Ubicación
  String _provincia = 'LA CONVENCION';
  String _distrito = 'MARANURA';
  String? _comunidad = 'BEATRIZ BAJA';
  DateTime _horaInicio = DateTime.now();
  DateTime _horaFin = DateTime.now().add(const Duration(hours: 3));
  String _clima = 'Soleado';
  String _incidencia = 'Sin Novedades (Todo conforme)';

  // Page 3 – Responsable / Beneficiario
  final _responsable = 'TORRES CUADROS HAMILTON MARLON';
  final _cargo = 'GESTOR DE INFORMACION';
  String? _organizacion = 'ASOCIACION DE PROD...';

  // Page 4 – Desarrollo, recomendaciones, firma, fotos
  final _actividades = TextEditingController();
  final _resultados = TextEditingController();
  final _acuerdos = TextEditingController();
  final _recomendaciones = TextEditingController();
  DateTime _proximaVisita =
      DateTime.now().add(const Duration(days: 30));
  String? _temaProxima = 'COSECHA Y POSTCOSECHA';
  final _observaciones = TextEditingController();

  final _modalidades = [
    'a. Capacitación',
    'b. Asistencia técnica',
    'c. Actividades complementarias',
  ];
  final _etapas = ['Instalación', 'Crecimiento', 'Producción', 'Podado'];
  final _tareas = [
    '1.Establecimiento del cultivo',
    '2.Manejo agronómico',
    '3.Control fitosanitario',
    '4.Cosecha',
    '5.Post cosecha',
    '6.Actividades complementarias',
  ];
  final _temas = [
    'MIP - ENFERMEDADES',
    'MIP - PLAGAS',
    'NUTRICIÓN',
    'PODAS',
    'COSECHA Y POSTCOSECHA',
    'COMERCIALIZACIÓN',
  ];
  final _provincias = ['CALCA', 'LA CONVENCION'];
  final _distritos = {
    'CALCA': ['YANATILE', 'CALCA', 'PISAQ', 'LAMAY'],
    'LA CONVENCION': ['MARANURA', 'SANTA ANA', 'HUAYOPATA', 'QUELLOUNO'],
  };
  final _comunidades = [
    'BEATRIZ BAJA', 'COMBAPATA', 'CHALLHUAHUACHO', 'PUCYURA', 'TRAPICHE'
  ];
  final _climas = [
    'Soleado', 'Nublado', 'Llovizna (Garúa)', 'Lluvia Fuerte',
    'Niebla - Neblina', 'Viento - Frío',
  ];
  final _incidencias = [
    'Sin Novedades (Todo conforme)',
    'Derrumbe - Vía bloqueada',
    'Camino Intransitable (Lodo)',
    'Crecida de Río / Quebrada',
    'Otro',
  ];
  final _temasProxima = [
    'COSECHA Y POSTCOSECHA', 'MIP - ENFERMEDADES', 'NUTRICIÓN',
    'PODAS', 'COMERCIALIZACIÓN',
  ];

  @override
  void dispose() {
    _actividades.dispose();
    _resultados.dispose();
    _acuerdos.dispose();
    _recomendaciones.dispose();
    _observaciones.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages - 1) setState(() => _page++);
  }

  void _prev() {
    if (_page > 0) setState(() => _page--);
  }

  void _save() {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('FAT guardada correctamente')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages - 1;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: const Text('4Cafe.Fat_filtro'),
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
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton(
              onPressed: isLast ? _save : _next,
              child: Text(isLast ? 'Guardar' : 'Siguiente ►'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: [
          _buildPage1(),
          _buildPage2(),
          _buildPage3(),
          _buildPage4(),
        ][_page],
      ),
    );
  }

  // PAGE 1 – Identificación
  Widget _buildPage1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MapPlaceholder(),
        const SizedBox(height: 14),
        _FieldLabel('idFat *'),
        _ReadOnlyField(_idFat),
        const SizedBox(height: 14),
        _FieldLabel('Número de Ficha'),
        _ReadOnlyField(_numeroFicha),
        const SizedBox(height: 14),
        _FieldLabel('Fecha *'),
        _DatePickerField(
            value: _fecha, onChanged: (d) => setState(() => _fecha = d)),
        const SizedBox(height: 20),
        const _SectionTitle('1. Identificación de la intervención'),
        const SizedBox(height: 12),
        _FieldLabel('Modalidad: ECA / CTG / VTP *'),
        DropdownButtonFormField<String>(
          value: _modalidad,
          decoration: const InputDecoration(),
          items: _modalidades
              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
              .toList(),
          onChanged: (v) => setState(() => _modalidad = v),
        ),
        const SizedBox(height: 14),
        _FieldLabel('Etapa *'),
        DropdownButtonFormField<String>(
          value: _etapa,
          decoration: const InputDecoration(),
          items: _etapas
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => setState(() => _etapa = v),
        ),
        const SizedBox(height: 14),
        _FieldLabel('Tarea *'),
        DropdownButtonFormField<String>(
          value: _tarea,
          decoration: const InputDecoration(hintText: 'Seleccionar...'),
          items: _tareas
              .map((t) => DropdownMenuItem(
                  value: t, child: Text(t, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) => setState(() => _tarea = v),
        ),
        const SizedBox(height: 14),
        _FieldLabel('Tema *'),
        DropdownButtonFormField<String>(
          value: _tema,
          decoration: const InputDecoration(hintText: 'Seleccionar...'),
          items: _temas
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) => setState(() => _tema = v),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  // PAGE 2 – Ubicación
  Widget _buildPage2() {
    final distritos = _distritos[_provincia] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('2. Ubicación'),
        const SizedBox(height: 12),
        _FieldLabel('Provincia *'),
        _ChipSelector(
          options: _provincias,
          selected: _provincia,
          onSelected: (v) => setState(() {
            _provincia = v;
            _distrito = (_distritos[v] ?? []).first;
          }),
        ),
        const SizedBox(height: 14),
        _FieldLabel('Distrito *'),
        DropdownButtonFormField<String>(
          value: distritos.contains(_distrito) ? _distrito : distritos.first,
          decoration: const InputDecoration(),
          items: distritos
              .map((d) => DropdownMenuItem(value: d, child: Text(d)))
              .toList(),
          onChanged: (v) => setState(() => _distrito = v!),
        ),
        const SizedBox(height: 14),
        _FieldLabel('Comunidad / sector *'),
        DropdownButtonFormField<String>(
          value: _comunidad,
          decoration: const InputDecoration(hintText: 'Seleccionar...'),
          items: _comunidades
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _comunidad = v),
        ),
        const SizedBox(height: 14),
        _FieldLabel('Hora de inicio: *'),
        _TimePickerField(
            value: _horaInicio,
            onChanged: (d) => setState(() => _horaInicio = d)),
        const SizedBox(height: 14),
        _FieldLabel('Hora de finalización: *'),
        _TimePickerField(
            value: _horaFin,
            onChanged: (d) => setState(() => _horaFin = d)),
        const SizedBox(height: 14),
        _FieldLabel('Clima *'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _climas
              .map((c) => _SelectableChip(
                  label: c,
                  selected: _clima == c,
                  onTap: () => setState(() => _clima = c)))
              .toList(),
        ),
        const SizedBox(height: 14),
        _FieldLabel('Incidencia *'),
        Column(
          children: _incidencias
              .map((inc) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _incidencia = inc),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 13, horizontal: 14),
                        decoration: BoxDecoration(
                          color: _incidencia == inc
                              ? AppColors.chipSelected
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: _incidencia == inc
                                  ? AppColors.chipSelected
                                  : AppColors.border),
                        ),
                        child: Text(inc,
                            style: TextStyle(
                                color: _incidencia == inc
                                    ? Colors.white
                                    : AppColors.textPrimary)),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  // PAGE 3 – Responsable / Beneficiario
  Widget _buildPage3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('3. Responsable(s)'),
        const SizedBox(height: 12),
        _FieldLabel('Responsable(s)'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          decoration: BoxDecoration(
              color: AppColors.accentBlue,
              borderRadius: BorderRadius.circular(8)),
          child: Text(_responsable,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        _FieldLabel('Cargo / Rol'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          decoration: BoxDecoration(
              color: AppColors.accentBlue,
              borderRadius: BorderRadius.circular(8)),
          child: Text(_cargo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 20),
        const _SectionTitle(
            '4. Beneficiario / Participantes (Para VTP: 1 productor. Para ECA/CTG: Adjuntar lista)'),
        const SizedBox(height: 12),
        _FieldLabel(
            'Organización de productores.\n(Ej.: Debe consignarse la AEO, sino SIN ORGANIZACIÓN)'),
        DropdownButtonFormField<String>(
          value: _organizacion,
          decoration: const InputDecoration(),
          items: [
            'ASOCIACION DE PROD...',
            'SIN ORGANIZACIÓN',
            'AEO CAFÉ DEL VALLE',
          ]
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) => setState(() => _organizacion = v),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  // PAGE 4 – Desarrollo, recomendaciones, firma, fotos
  Widget _buildPage4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
            '5. Desarrollo, resultados y acuerdos\n(Registre lo que realmente realizó: actividades, metodología, aprendizajes, compromisos, etc)'),
        const SizedBox(height: 12),
        _FieldLabel('Actividades realizadas (resumen)'),
        TextFormField(controller: _actividades, maxLines: 3),
        const SizedBox(height: 14),
        _FieldLabel(
            'Resultados / aprendizajes clave (Ej.: El productor identificó la plaga X y aplican manejo integrado)'),
        TextFormField(controller: _resultados, maxLines: 3),
        const SizedBox(height: 14),
        _FieldLabel(
            'Acuerdos y compromisos (Ej.: Realizar poda sanitaria antes de la próxima visita)'),
        TextFormField(controller: _acuerdos, maxLines: 3),
        const SizedBox(height: 20),
        const _SectionTitle(
            '6. Recomendaciones, próxima visita y observaciones'),
        const SizedBox(height: 12),
        _FieldLabel('Recomendaciones técnicas'),
        TextFormField(controller: _recomendaciones, maxLines: 2),
        const SizedBox(height: 14),
        _FieldLabel('Próxima visita *'),
        _DatePickerField(
            value: _proximaVisita,
            onChanged: (d) => setState(() => _proximaVisita = d)),
        const SizedBox(height: 14),
        _FieldLabel('Tema'),
        DropdownButtonFormField<String>(
          value: _temaProxima,
          decoration: const InputDecoration(),
          items: _temasProxima
              .map((t) => DropdownMenuItem(
                  value: t, child: Text(t, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) => setState(() => _temaProxima = v),
        ),
        const SizedBox(height: 14),
        _FieldLabel(
            'Observaciones (Ej.: Incidencias, retrasos, riesgos, acciones correctivas, etc)'),
        TextFormField(controller: _observaciones, maxLines: 3),
        const SizedBox(height: 20),
        const _SectionTitle('7. Firmas'),
        const SizedBox(height: 12),
        _FieldLabel('Productor / Representante *'),
        _SignaturePad(),
        const SizedBox(height: 20),
        const _SectionTitle(
            'ANEXO 1. Panel fotográfico\n(Mínimo 3 fotos (inicio, desarrollo, cierre) con breve descripción)'),
        const SizedBox(height: 12),
        _PhotoField(label: 'inicio *'),
        _FieldLabel('Descripción breve fotografía N°1'),
        const TextField(decoration: InputDecoration(border: OutlineInputBorder())),
        const SizedBox(height: 14),
        _PhotoField(label: 'desarrollo *'),
        _FieldLabel('Descripción breve fotografía N°2'),
        const TextField(decoration: InputDecoration(border: OutlineInputBorder())),
        const SizedBox(height: 14),
        _PhotoField(label: 'cierre *'),
        _FieldLabel('Descripción breve fotografía N°3'),
        const TextField(decoration: InputDecoration(border: OutlineInputBorder())),
        const SizedBox(height: 20),
        const _SectionTitle(
            'ANEXO 2. Lista de participantes (Obligatorio para ECA/CTG)'),
        const SizedBox(height: 8),
        _FieldLabel('Participantes'),
        GestureDetector(
          onTap: () {},
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Text('Nuevo',
                  style: TextStyle(
                      color: AppColors.accentBlue,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}

// ─── REUSABLE WIDGETS ─────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary)),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String value;
  const _ReadOnlyField(this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(value,
          style:
              const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.textPrimary));
  }
}

class _DatePickerField extends StatelessWidget {
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  const _DatePickerField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Expanded(child: Text(formatDate(value))),
            const Icon(Icons.calendar_today,
                size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _TimePickerField extends StatelessWidget {
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  const _TimePickerField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime:
              TimeOfDay(hour: value.hour, minute: value.minute),
        );
        if (picked != null) {
          onChanged(DateTime(value.year, value.month, value.day,
              picked.hour, picked.minute));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Expanded(child: Text(formatTime(value))),
            const Icon(Icons.access_time,
                size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _ChipSelector extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  const _ChipSelector(
      {required this.options,
      required this.selected,
      required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options
          .map((o) => Expanded(
                child: GestureDetector(
                  onTap: () => onSelected(o),
                  child: Container(
                    margin: EdgeInsets.only(
                        right: o == options.last ? 0 : 6),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: selected == o
                          ? AppColors.chipSelected
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: selected == o
                              ? AppColors.chipSelected
                              : AppColors.border),
                    ),
                    child: Center(
                      child: Text(o,
                          style: TextStyle(
                              color: selected == o
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                              fontSize: 12)),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _SelectableChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SelectableChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.chipSelected : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color:
                  selected ? AppColors.chipSelected : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                color:
                    selected ? Colors.white : AppColors.textPrimary,
                fontSize: 12)),
      ),
    );
  }
}

class _SociosField extends StatelessWidget {
  final List<String> socios;
  final TextEditingController controller;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final VoidCallback onClear;
  const _SociosField({
    required this.socios,
    required this.controller,
    required this.onAdd,
    required this.onRemove,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.chipSelected, width: 1.5),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          ...socios.asMap().entries.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e.value, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => onRemove(e.key),
                      child: const Icon(Icons.close,
                          size: 16, color: Colors.grey),
                    ),
                  ],
                ),
              )),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'Bus...',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 12),
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              GestureDetector(
                  onTap: onClear,
                  child: const Icon(Icons.close, size: 18)),
              const SizedBox(width: 6),
              GestureDetector(
                  onTap: onAdd,
                  child: const Icon(Icons.add,
                      size: 18, color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final int current;
  final int total;
  const _PageIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
              color: AppColors.chipSelected, shape: BoxShape.circle),
          child: Center(
            child: Text('$current',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 6),
        Text('Page $current',
            style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
        color: Colors.grey.shade200,
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 6),
                Text('Mapa / Coordenadas GPS',
                    style: TextStyle(color: Colors.grey.shade500)),
                Text('Lat: -13.0000  Long: -72.0000',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.my_location, size: 14),
              label: const Text('Obtener GPS', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignaturePad extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(icon: const Icon(Icons.lock_open, size: 18), onPressed: () {}),
              IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: () {}),
            ],
          ),
          Expanded(
            child: Center(
              child: Text('Área de firma',
                  style: TextStyle(color: Colors.grey.shade400)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoField extends StatelessWidget {
  final String label;
  const _PhotoField({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        GestureDetector(
          onTap: () {},
          child: Container(
            width: double.infinity,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt,
                    size: 36, color: Colors.grey.shade400),
                const SizedBox(height: 4),
                Text('Tomar foto',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
