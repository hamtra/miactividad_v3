import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart'; // Aquí iría tu pantalla de login
import 'home_screen.dart';  // La pantalla a la que van si loguean

class AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Si el usuario ya está logueado, ve a la pantalla principal
        if (snapshot.hasData) {
          return HomeScreen(); 
        }
        // Si no, muestra la pantalla de login
        return LoginScreen();
      },
    );
  }
}