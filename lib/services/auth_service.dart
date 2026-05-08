import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_options.dart';
import '../models/usuario_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AUTH SERVICE
//
// Colección usuarios : 'usuarios'
// Colección metadata : 'metadata'  /  doc : 'users_counter'  /  campo: last_id
//
// IDs de documentos:
//   • Docs migrados  → "idus0001", "idus0002" (ID propio, no UID de Auth)
//   • Docs nuevos    → Firebase Auth UID  (dentro del doc se guarda id_correlativo)
// ─────────────────────────────────────────────────────────────────────────────
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String colUsuarios = 'usuarios';

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─────────────────────────────────────────────────────────────────────────
  // LOGIN
  // ─────────────────────────────────────────────────────────────────────────
  Future<UsuarioModel> login({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return _fetchPorEmail(email.trim());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RECARGAR PERFIL (al reabrir app con sesión guardada)
  // ─────────────────────────────────────────────────────────────────────────
  Future<UsuarioModel> fetchUsuarioPorUid(String uid) async {
    final email = _auth.currentUser?.email ?? '';
    if (email.isEmpty) {
      throw Exception('No hay sesión activa. Inicia sesión nuevamente.');
    }
    return _fetchPorEmail(email);
  }

  Future<UsuarioModel> _fetchPorEmail(String email) async {
    // ignore: avoid_print
    print('🔍 Buscando en "$colUsuarios" donde email == "$email"');
    try {
      final query = await _db
          .collection(colUsuarios)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        // ignore: avoid_print
        print('❌ Sin documento para email "$email"');
        throw Exception(
          'Usuario no registrado. No existe un perfil con el correo "$email".',
        );
      }
      // ignore: avoid_print
      print('✅ Documento encontrado: ${query.docs.first.id}');
      return UsuarioModel.fromFirestore(query.docs.first);
    } on FirebaseException catch (e) {
      // ignore: avoid_print
      print('🚨 Firestore [${e.code}]: ${e.message}');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CREAR USUARIO COMPLETO
  //
  // 1. Crea cuenta en Firebase Auth usando instancia secundaria
  //    (NO desloguea al administrador).
  // 2. Escribe el documento en 'usuarios':
  //      • doc.id    = Firebase Auth UID del nuevo usuario
  //      • uid_auth  = mismo UID
  //      • fecha_creacion = FieldValue.serverTimestamp()
  // ─────────────────────────────────────────────────────────────────────────
  Future<UsuarioModel> crearUsuarioCompleto({
    required String email,
    required String password,
    required UsuarioModel datosParciales,
  }) async {
    // ── Paso 1: Crear cuenta Auth sin desloguear al admin ─────────────────
    final uid = await _crearAuthSecundario(email, password);

    // ── Paso 2: Escribir perfil en Firestore ──────────────────────────────
    final userRef = _db.collection(colUsuarios).doc(uid);
    final userData = {
      ...datosParciales.toFirestore(),
      'uid_auth':       uid,
      'fecha_creacion': FieldValue.serverTimestamp(),
    };
    await userRef.set(userData);

    // ignore: avoid_print
    print('✅ Usuario creado: $uid');

    return UsuarioModel(
      uid:             uid,
      uidAuth:         uid,
      nombreCompleto:  datosParciales.nombreCompleto,
      dni:             datosParciales.dni,
      celular:         datosParciales.celular,
      sexo:            datosParciales.sexo,
      fechaNacimiento: datosParciales.fechaNacimiento,
      actividad:       datosParciales.actividad,
      cargo:           datosParciales.cargo,
      rol:             datosParciales.rol,
      idSuperior:      datosParciales.idSuperior,
      estado:          datosParciales.estado,
      email:           datosParciales.email,
      firmaUrl:        datosParciales.firmaUrl,
      fechaCreacion:   DateTime.now(),
    );
  }

    // ── Crea cuenta Auth en instancia secundaria (sin desloguear al admin) ────
  Future<String> _crearAuthSecundario(String email, String password) async {
    FirebaseApp? appTemp;
    try {
      // Reutiliza la instancia si ya existe (fallo anterior)
      try {
        appTemp = Firebase.app('_tmp_crear_usuario');
      } catch (_) {
        appTemp = await Firebase.initializeApp(
          name: '_tmp_crear_usuario',
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      final authTemp = FirebaseAuth.instanceFor(app: appTemp);
      final credential = await authTemp.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential.user!.uid;
    } on FirebaseAuthException {
      rethrow;
    } finally {
      // Limpiar la instancia temporal
      await appTemp?.delete().catchError((_) {});
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // OBTENER TODOS LOS USUARIOS — consulta única (para selectores)
  // ─────────────────────────────────────────────────────────────────────────
  Future<List<UsuarioModel>> getUsuarios() async {
    final snap = await _db
        .collection(colUsuarios)
        .orderBy('nombreCompleto')
        .get();
    return snap.docs.map((d) => UsuarioModel.fromFirestore(d)).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STREAM DE UN USUARIO ESPECÍFICO — sincronización en tiempo real
  // Usado por SesionProvider para que el usuario vea cambios del admin
  // sin necesidad de cerrar sesión y volver a entrar.
  // ─────────────────────────────────────────────────────────────────────────
  Stream<UsuarioModel?> streamUsuarioPorDocId(String docId) {
    return _db.collection(colUsuarios).doc(docId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UsuarioModel.fromFirestore(snap);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LISTAR TODOS LOS USUARIOS — Stream en tiempo real (solo admin)
  // ─────────────────────────────────────────────────────────────────────────
  Stream<List<UsuarioModel>> streamUsuarios() {
    return _db
        .collection(colUsuarios)
        .orderBy('nombreCompleto')
        .snapshots()
        .map((s) => s.docs.map((d) => UsuarioModel.fromFirestore(d)).toList());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTUALIZAR CAMPOS DE UN USUARIO
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> actualizarUsuario(
      String docId, Map<String, dynamic> campos) async {
    await _db.collection(colUsuarios).doc(docId).update(campos);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ELIMINAR USUARIO DE FIRESTORE
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> eliminarUsuarioFirestore(String docId) async {
    await _db.collection(colUsuarios).doc(docId).delete();
    // ignore: avoid_print
    print('🗑️ Usuario $docId eliminado de Firestore');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GUARDAR PERFIL MANUALMENTE (para docs nuevos con UID como ID)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> createUserProfile(String uid, UsuarioModel modelo) async {
    await _db.collection(colUsuarios).doc(uid).set(modelo.toFirestore());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTUALIZAR FIRMA
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> actualizarFirmaUrl(String docId, String firmaUrl) async {
    await _db.collection(colUsuarios).doc(docId).update({'firmaUrl': firmaUrl});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOGOUT
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> logout() async => _auth.signOut();

  // ─────────────────────────────────────────────────────────────────────────
  // RECUPERAR CONTRASEÑA
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
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
        return 'Sin permiso. Revisa las reglas de Firestore.';
      default:
        return 'Error ($code). Intenta nuevamente.';
    }
  }
}
