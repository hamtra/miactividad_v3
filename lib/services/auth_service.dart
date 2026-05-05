import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AUTH SERVICE — Wrapper sobre FirebaseAuth
// Expone: registro, login, logout y stream del usuario actual
// ─────────────────────────────────────────────────────────────────────────────

class AuthService {
  // ── Instancia singleton de FirebaseAuth ───────────────────────────────────
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Usuario actual (puede ser null si no hay sesión) ──────────────────────
  User? get currentUser => _auth.currentUser;

  // ── Stream: emite cada vez que el estado de sesión cambia ─────────────────
  // Ideal para usar con StreamBuilder o en el Provider para redirigir pantallas
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─────────────────────────────────────────────────────────────────────────
  // REGISTRO con email y contraseña
  // Retorna el User creado, o lanza FirebaseAuthException si hay error
  // ─────────────────────────────────────────────────────────────────────────
  Future<User?> registerWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOGIN con email y contraseña
  // ─────────────────────────────────────────────────────────────────────────
  Future<User?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CERRAR SESIÓN
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _auth.signOut();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RECUPERAR CONTRASEÑA — envía email de restablecimiento
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPER: traduce códigos de error de Firebase a mensajes en español
  // Úsalo en el catch de cualquier pantalla de login/registro
  //
  // Ejemplo de uso:
  //   } on FirebaseAuthException catch (e) {
  //     final msg = AuthService.mensajeError(e.code);
  //     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  //   }
  // ─────────────────────────────────────────────────────────────────────────
  static String mensajeError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo electrónico.';
      case 'invalid-email':
        return 'El correo electrónico no es válido.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'user-not-found':
        return 'No existe una cuenta con ese correo electrónico.';
      case 'wrong-password':
        return 'Contraseña incorrecta.';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada.';
      case 'too-many-requests':
        return 'Demasiados intentos fallidos. Intenta más tarde.';
      case 'network-request-failed':
        return 'Sin conexión a internet. Verifica tu red.';
      default:
        return 'Error de autenticación ($code). Intenta nuevamente.';
    }
  }
}
