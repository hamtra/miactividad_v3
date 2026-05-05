import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AUTH PROVIDER — Sesión del usuario logueado
// En producción: conectar con firebase_auth para autenticación real.
// ─────────────────────────────────────────────────────────────────────────────
class UsuarioSesion {
  final String dni;
  final String nombreCompleto;
  final String idRol;          // idrol001=admin, idrol002=técnico
  final String idCargo;        // idcarg001=TECNICO, idcarg002=EXTENSIONISTA...
  final String cargo;
  final String idTecEspExt;    // idus33, idus11, etc.

  const UsuarioSesion({
    required this.dni,
    required this.nombreCompleto,
    required this.idRol,
    required this.idCargo,
    required this.cargo,
    required this.idTecEspExt,
  });
}

class AuthProvider extends ChangeNotifier {
  UsuarioSesion? _usuario;
  bool _cargando = false;

  UsuarioSesion? get usuario => _usuario;
  bool get cargando => _cargando;
  bool get isLoggedIn => _usuario != null;

  // ── Login simulado (reemplazar con firebase_auth en producción) ────────────
  Future<bool> login(String dni, String password) async {
    _cargando = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 500));
    // TODO: autenticar con Firebase Auth
    // final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(...)
    // Por ahora usamos el DNI del técnico actual
    _usuario = _usuariosPorDni[dni];
    _cargando = false;
    notifyListeners();
    return _usuario != null;
  }

  void logout() {
    _usuario = null;
    notifyListeners();
  }

  /// Auto-login para desarrollo (eliminar en producción)
  void loginDev() {
    _usuario = _usuariosPorDni['74471141'];
    notifyListeners();
  }

  // ── Usuarios registrados en el sistema ────────────────────────────────────
  // FUENTE: hoja 4Cafe.Fat campo 'usuario' y 'cargo' del Excel
  static final Map<String, UsuarioSesion> _usuariosPorDni = {
    '74471141': const UsuarioSesion(
      dni: '74471141',
      nombreCompleto: 'TORRES CUADROS HAMILTON MARLON',
      idRol: 'idrol002',
      idCargo: 'idcarg006',
      cargo: 'GESTOR DE INFORMACIÓN',
      idTecEspExt: 'idus33',
    ),
    '42576438': const UsuarioSesion(
      dni: '42576438',
      nombreCompleto: 'MAMANI APAZA ALI',
      idRol: 'idrol002',
      idCargo: 'idcarg001',
      cargo: 'TECNICO DE CAMPO',
      idTecEspExt: 'idus11',
    ),
    '72506830': const UsuarioSesion(
      dni: '72506830',
      nombreCompleto: 'HUAMANI MIRANDA EDIT',
      idRol: 'idrol002',
      idCargo: 'idcarg002',
      cargo: 'EXTENSIONISTA',
      idTecEspExt: 'idus02',
    ),
    '73974543': const UsuarioSesion(
      dni: '73974543',
      nombreCompleto: 'QUISPE APAZA GREGORIO',
      idRol: 'idrol002',
      idCargo: 'idcarg001',
      cargo: 'TECNICO DE CAMPO',
      idTecEspExt: 'idus09',
    ),
    '74875632': const UsuarioSesion(
      dni: '74875632',
      nombreCompleto: 'USUARIO TÉCNICO 43',
      idRol: 'idrol002',
      idCargo: 'idcarg001',
      cargo: 'TECNICO DE CAMPO',
      idTecEspExt: 'idus43',
    ),
    // Agregar más técnicos según sea necesario
  };
}
