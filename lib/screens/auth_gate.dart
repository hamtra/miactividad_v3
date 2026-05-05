import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'main_menu_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AUTH GATE — Punto de entrada que decide si mostrar Login o la app
//
// Escucha authStateChanges() de Firebase en tiempo real:
//   • Usuario logueado  → MainMenuScreen
//   • Sin sesión        → LoginScreen
//
// Esto significa que cuando el usuario hace login desde LoginScreen,
// Firebase emite el nuevo estado y este widget redirige solo,
// sin necesidad de Navigator.push() manual.
// ─────────────────────────────────────────────────────────────────────────────
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Mientras Firebase verifica la sesión guardada, muestra un loader
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Si hay usuario activo, ir al menú principal
        if (snapshot.hasData) {
          return const MainMenuScreen();
        }

        // Sin sesión → pantalla de login
        return const LoginScreen();
      },
    );
  }
}
