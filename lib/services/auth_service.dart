import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/usuario_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AUTH SERVICE
//
// Estructura real en Firestore:
//   Colección : 'usuarios'  (minúsculas)
//   ID doc    : 'idus0001', 'idus0002' … (NO es el UID de Firebase Auth)
//   Búsqueda  : where('email', == email autenticado).limit(1)
// ─────────────────────────────────────────────────────────────────────────────
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Nombre EXACTO de la colección en Firestore (minúsculas — case-sensitive)
  static const String _col = 'usuarios';

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─────────────────────────────────────────────────────────────────────────
  // LOGIN
  // 1. Firebase Auth  → obtiene el email verificado del usuario
  // 2. Firestore      → busca el documento donde campo 'email' == ese email
  // ─────────────────────────────────────────────────────────────────────────
  Future<UsuarioModel> login({
    required String email,
    required String password,
  }) async {
    // Paso 1: Autenticar
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // Paso 2: Buscar perfil por email en Firestore
    return _fetchPorEmail(email.trim());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RECARGAR PERFIL (p.ej. al reabrir la app con sesión guardada)
  // El parámetro uid es el UID de Firebase Auth; lo ignoramos porque los
  // documentos de Firestore usan IDs propios. Usamos el email del usuario
  // autenticado actualmente para la búsqueda.
  // ─────────────────────────────────────────────────────────────────────────
  Future<UsuarioModel> fetchUsuarioPorUid(String uid) async {
    final email = _auth.currentUser?.email ?? '';
    if (email.isEmpty) {
      throw Exception('No hay sesión activa. Inicia sesión nuevamente.');
    }
    return _fetchPorEmail(email);
  }

  // ── Búsqueda interna por email ────────────────────────────────────────────
  Future<UsuarioModel> _fetchPorEmail(String email) async {
    // LOG DE DEPURACIÓN — muestra exactamente qué se busca en la consola
    // ignore: avoid_print
    print('🔍 Buscando en colección "$_col" donde email == "$email"');

    try {
      final query = await _db
          .collection(_col)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        // ignore: avoid_print
        print('❌ No se encontró ningún documento con email "$email" en "$_col"');
        throw Exception(
          'Usuario no registrado. No existe un perfil con el correo "$email".',
        );
      }

      final doc = query.docs.first;
      // ignore: avoid_print
      print('✅ Documento encontrado: ${doc.id}');
      return UsuarioModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      // ignore: avoid_print
      print('🚨 Firestore error [${e.code}] al buscar por email: ${e.message}');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOGOUT
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _auth.signOut();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REGISTRO
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
  // RECUPERAR CONTRASEÑA
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTUALIZAR FIRMA
  // uid aquí es el doc.id de Firestore (ej: "idus0001"), que se obtiene
  // del UsuarioModel.uid después del login exitoso.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> actualizarFirmaUrl(String uid, String firmaUrl) async {
    await _db.collection(_col).doc(uid).update({'firmaUrl': firmaUrl});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MENSAJES DE ERROR en español
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
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'wrong-password':
        return 'Contraseña incorrecta.';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada. Contacta al administrador.';
      case 'too-many-requests':
        return 'Demasiados intentos fallidos. Intenta más tarde.';
      case 'network-request-failed':
        return 'Sin conexión a internet. Verifica tu red.';
      case 'permission-denied':
        return 'Sin permiso para acceder a los datos. Revisa las reglas de Firestore.';
      case 'operation-not-allowed':
        return 'Método de acceso no habilitado. Contacta al administrador.';
      default:
        return 'Error ($code). Intenta nuevamente.';
    }
  }
}
