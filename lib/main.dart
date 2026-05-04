import 'package:flutter/material.dart';

void main() {
  runApp(const MiActividadApp());
}

class MiActividadApp extends StatelessWidget {
  const MiActividadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Miactividad',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF1B5E20), // Verde oscuro de tus capturas
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MenuGeneral(),
    );
  }
}

// --- 1. MENÚ GENERAL ---
class MenuGeneral extends StatelessWidget {
  const MenuGeneral({super.key});

  @override
  Widget build(BuildContext context) {
    final actividades = [
      {'nombre': 'CAFÉ', 'icon': Icons.coffee_rounded},
      {'nombre': 'CACAO', 'icon': Icons.bento_outlined},
      {'nombre': 'APÍCOLA', 'icon': Icons.hive_rounded},
      {'nombre': 'ASOCIATIVIDAD', 'icon': Icons.groups_rounded},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('menu general'), centerTitle: true),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
        ),
        itemCount: actividades.length,
        itemBuilder: (context, i) {
          return InkWell(
            onTap: () {
              if (actividades[i]['nombre'] == 'CAFÉ') {
                Navigator.push(context, MaterialPageRoute(builder: (c) => const MenuCafe()));
              }
            },
            child: Card(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(actividades[i]['icon'] as IconData, size: 50, color: Colors.green),
                  const SizedBox(height: 10),
                  Text(actividades[i]['nombre'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- 2. SUBMENÚ CAFÉ ---
class MenuCafe extends StatelessWidget {
  const MenuCafe({super.key});

  @override
  Widget build(BuildContext context) {
    final opciones = [
      {'n': 'PLAN DE TRABAJO', 'i': Icons.assignment},
      {'n': 'FAT', 'i': Icons.people_alt},
      {'n': 'TRAZABILIDAD', 'i': Icons.alt_route},
      {'n': 'A7 (Prospección)', 'i': Icons.search},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('menu general > Cafe'), backgroundColor: const Color(0xFF1B5E20)),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.8),
        itemCount: opciones.length,
        itemBuilder: (context, i) {
          return InkWell(
            onTap: () {
              if (opciones[i]['n'] == 'FAT') {
                Navigator.push(context, MaterialPageRoute(builder: (c) => const FormularioFAT()));
              }
            },
            child: Card(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(opciones[i]['i'] as IconData, color: Colors.green, size: 40),
                  Text(opciones[i]['n'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- 3. FORMULARIO FAT (FICHA ASISTENCIA TÉCNICA) ---
class FormularioFAT extends StatefulWidget {
  const FormularioFAT({super.key});

  @override
  State<FormularioFAT> createState() => _FormularioFATState();
}

class _FormularioFATState extends State<FormularioFAT> {
  final idController = TextEditingController(text: "59F61A11-AB97-435A..."); // ID como en tu imagen
  String modalidad = 'b. Asistencia técnica';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('4Cafe.Fat_filtro'), actions: [TextButton(onPressed: (){}, child: const Text('Siguiente', style: TextStyle(color: Colors.white)))],),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("FICHA DE ASISTENCIA TÉCNICA", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text("Registro de capacitación y asistencia a productores", style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 20),
            // Campo Coordenadas
            const TextField(decoration: InputDecoration(labelText: 'Coordenadas (latitud y longitud)*', border: OutlineInputBorder(), hintText: '-12.863820, -72.693280')),
            const SizedBox(height: 15),
            // Campo ID
            TextField(controller: idController, decoration: const InputDecoration(labelText: 'idFat*', border: OutlineInputBorder())),
            const SizedBox(height: 15),
            // Modalidad Dropdown
            const Text("Modalidad: ECA / CTG / VTP*"),
            DropdownButton<String>(
              isExpanded: true,
              value: modalidad,
              items: <String>['b. Asistencia técnica', 'ECA', 'CTG', 'VTP'].map((String value) {
                return DropdownMenuItem<String>(value: value, child: Text(value));
              }).toList(),
              onChanged: (val) => setState(() => modalidad = val!),
            ),
            const SizedBox(height: 30),
            Center(child: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), child: const Text("GUARDAR FICHA")))
          ],
        ),
      ),
    );
  }
}