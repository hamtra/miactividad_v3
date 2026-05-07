import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'core/app_colors.dart';
import 'providers/auth_provider.dart';
import 'providers/plan_provider.dart';
import 'providers/fat_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_menu_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  } else {
    final p = defaultTargetPlatform;
    if (p == TargetPlatform.windows ||
        p == TargetPlatform.linux ||
        p == TargetPlatform.macOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MiActividadApp());
}

class MiActividadApp extends StatelessWidget {
  const MiActividadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SesionProvider()),
        ChangeNotifierProvider(create: (_) => PlanProvider()),
        ChangeNotifierProvider(create: (_) => FatProvider()),
      ],
      child: MaterialApp(
        title: 'MiActividad',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const _AuthGate(),
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
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
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

// AuthGate: StreamBuilder sobre authStateChanges()
// null -> LoginScreen | User -> _HomeLoader -> MainMenuScreen
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }
        return _HomeLoader(uid: snapshot.data!.uid);
      },
    );
  }
}

// Carga el perfil de Firestore una sola vez y muestra MainMenuScreen
class _HomeLoader extends StatefulWidget {
  final String uid;
  const _HomeLoader({required this.uid});

  @override
  State<_HomeLoader> createState() => _HomeLoaderState();
}

class _HomeLoaderState extends State<_HomeLoader> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    final prov = context.read<SesionProvider>();
    if (prov.usuario == null) {
      await prov.cargarUsuario(widget.uid);
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<SesionProvider>();

    if (!_loaded || prov.cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (prov.error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.orange),
                const SizedBox(height: 16),
                Text(prov.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesion'),
                  onPressed: () => context.read<SesionProvider>().logout(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const MainMenuScreen();
  }
}
