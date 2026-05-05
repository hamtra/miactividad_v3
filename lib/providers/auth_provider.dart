import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AUTH PROVIDER — Sesión del usuario
// Combina Firebase Auth (autenticación real) con el perfil local del técnico
// (nombre, cargo, DNI) que viene de la base de datos del proyecto.
// ─────────────────────────────────────────────────────────────────────────────

class UsuarioSesion {
  final String dni;
  final String nombreCompleto;
  final String idRol;       // idrol001=admin, idrol002=técnico
  final String idCargo;     // idcarg001=TECNICO, idcarg002=EXTENSIONISTA...
  final String cargo;
  final String idTecEspExt; // idus33, idus11, etc.
  final String? email;      // email de Firebase Auth (puede ser null en dev)

  const UsuarioSesion({
    required this.dni,
    required this.nombreCompleto,
    required this.idRol,
    required this.idCargo,
    required this.cargo,
    required this.idTecEspExt,
    this.email,
  });
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UsuarioSesion? _usuario;
  bool _cargando = false;
  String? _error;

  UsuarioSesion? get usuario => _usuario;
  bool get cargando => _cargando;
  bool get isLoggedIn => _usuario != null;
  String? get error => _error;

  // ─────────────────────────────────────────────────────────────────────────
  // LOGIN con Firebase Auth
  // Convención de email: DNI@miactividad.pe → carga perfil local del técnico
  // ─────────────────────────────────────────────────────────────────────────
  Future<bool> login(String email, String password) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final firebaseUser = await _authService.loginWithEmail(
        email: email,
        password: password,
      );
      if (firebaseUser != null) {
        _usuario = _perfilDesdeEmail(firebaseUser.email ?? '');
        // Si el email no tiene perfil local aún, crea uno mínimo
        _usuario ??= UsuarioSesion(
          dni: '',
          nombreCompleto:
              firebaseUser.displayName ?? firebaseUser.email ?? 'Usuario',
          idRol: 'idrol002',
          idCargo: 'idcarg001',
          cargo: 'TÉCNICO',
          idTecEspExt: '',
          email: firebaseUser.email,
        );
      }
    } on FirebaseAuthException catch (e) {
      _error = AuthService.mensajeError(e.code);
    } catch (e) {
      _error = 'Error inesperado. Intenta nuevamente.';
    }

    _cargando = false;
    notifyListeners();
    return _usuario != null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REGISTRO — crea cuenta en Firebase Auth y asigna perfil local
  // ─────────────────────────────────────────────────────────────────────────
  Future<bool> register(String email, String password) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final firebaseUser = await _authService.registerWithEmail(
        email: email,
        password: password,
      );
      if (firebaseUser != null) {
        _usuario = _perfilDesdeEmail(firebaseUser.email ?? '');
        _usuario ??= UsuarioSesion(
          dni: '',
          nombreCompleto: firebaseUser.email ?? 'Usuario',
          idRol: 'idrol002',
          idCargo: 'idcarg001',
          cargo: 'TÉCNICO',
          idTecEspExt: '',
          email: firebaseUser.email,
        );
      }
    } on FirebaseAuthException catch (e) {
      _error = AuthService.mensajeError(e.code);
    } catch (e) {
      _error = 'Error inesperado. Intenta nuevamente.';
    }

    _cargando = false;
    notifyListeners();
    return _usuario != null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOGOUT — cierra sesión en Firebase y limpia estado local
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _authService.logout();
    _usuario = null;
    _error = null;
    notifyListeners();
  }

  /// Auto-login para desarrollo — usa perfil de Hamilton sin Firebase Auth
  void loginDev() {
    _usuario = _perfilesPorDni['74471141'];
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPER: extrae el DNI del email y busca el perfil local
  // Ejemplo: "74471141@miactividad.pe" → DNI "74471141"
  // ─────────────────────────────────────────────────────────────────────────
  UsuarioSesion? _perfilDesdeEmail(String email) {
    final posibleDni = email.split('@').first;
    return _perfilesPorDni[posibleDni];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CATÁLOGO DE TÉCNICOS — fuente: hoja 4Cafe.Fat del Excel
  // ─────────────────────────────────────────────────────────────────────────
  static final Map<String, UsuarioSesion> _perfilesPorDni = {
    '74471141': const UsuarioSesion(
      dni: '74471141',
      nombreCompleto: 'TORRES CUADROS HAMILTON MARLON',
      idRol: 'idrol002',
      idCargo: 'idcarg006',
      cargo: 'GESTOR DE INFORMACIÓN',
      idTecEspExt: 'idus33',
      email: '74471141@miactividad.pe',
    ),
    '42576438': const UsuarioSesion(
      dni: '42576438',
      nombreCompleto: 'MAMANI APAZA ALI',
      idRol: 'idrol002',
      idCargo: 'idcarg001',
      cargo: 'TECNICO DE CAMPO',
      idTecEspExt: 'idus11',
      email: '42576438@miactividad.pe',
    ),
    '72506830': const UsuarioSesion(
      dni: '72506830',
      nombreCompleto: 'HUAMANI MIRANDA EDIT',
      idRol: 'idrol002',
      idCargo: 'idcarg002',
      cargo: 'EXTENSIONISTA',
      idTecEspExt: 'idus02',
      email: '72506830@miactividad.pe',
    ),
    '73974543': const UsuarioSesion(
      dni: '73974543',
      nombreCompleto: 'QUISPE APAZA GREGORIO',
      idRol: 'idrol002',
      idCargo: 'idcarg001',
      cargo: 'TECNICO DE CAMPO',
      idTecEspExt: 'idus09',
      email: '73974543@miactividad.pe',
    ),
    '74875632': const UsuarioSesion(
      dni: '74875632',
      nombreCompleto: 'USUARIO TÉCNICO 43',
      idRol: 'idrol002',
      idCargo: 'idcarg001',
      cargo: 'TECNICO DE CAMPO',
      idTecEspExt: 'idus43',
      email: '74875632@miactividad.pe',
    ),
  };
}
