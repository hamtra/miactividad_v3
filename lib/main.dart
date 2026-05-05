import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';

import 'core/app_colors.dart';
import 'providers/auth_provider.dart';
import 'providers/plan_provider.dart';
import 'providers/fat_provider.dart';
import 'screens/main_menu_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Inicializar sqflite según plataforma ──────────────────────────────────
  // Android / iOS → sqflite nativo, no requiere nada
  // Windows / Linux / macOS / Web → requiere sqflite_common_ffi
  if (kIsWeb) {
    // En Web: usar sqflite en modo FFI (base de datos en memoria para pruebas)
    // Para producción web real usa Hive o sembast_web
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  } else {
    final platform = defaultTargetPlatform;
    if (platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux ||
        platform == TargetPlatform.macOS) {
      // Desktop: inicializar FFI
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    // Android / iOS: sqflite funciona solo, no hacer nada
  }

  // ── Firebase (descomenta cuando tengas google-services.json configurado) ───
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MiActividadApp());
}

class MiActividadApp extends StatelessWidget {
  const MiActividadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..loginDev()),
        ChangeNotifierProvider(create: (_) => PlanProvider()),
        ChangeNotifierProvider(create: (_) => FatProvider()),
      ],
      child: MaterialApp(
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
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
        ),
        home: const MainMenuScreen(),
      ),
    );
  }
}
