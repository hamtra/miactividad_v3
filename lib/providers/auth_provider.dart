import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/usuario_model.dart';
import '../services/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SESION PROVIDER — gestión de estado del usuario autenticado
// Registrado como ChangeNotifierProvider en main.dart.
// Expone UsuarioModel (datos de Firestore) a toda la app.
// ─────────────────────────────────────────────────────────────────────────────
class SesionProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UsuarioModel? _usuario;
  bool _cargando = false;
  String? _error;

  UsuarioModel? get usuario    => _usuario;
  bool          get cargando   => _cargando;
  bool          get isLoggedIn => _usuario != null;
  String?       get error      => _error;

  // ── Cargar perfil desde Firestore (usado al reabrir la app con sesión guardada)
  Future<void> cargarUsuario(String uid) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      _usuario = await _authService.fetchUsuarioPorUid(uid);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _usuario = null;
    }

    _cargando = false;
    notifyListeners();
  }

  // ── Login: autentica con Firebase Auth + carga perfil de Firestore
  Future<bool> login(String email, String password) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      _usuario = await _authService.login(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      _error = AuthService.mensajeError(e.code);
      _usuario = null;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _usuario = null;
      // Si Firestore falló pero Auth autenticó → logout para evitar estado roto
      await _authService.logout();
    }

    _cargando = false;
    notifyListeners();
    return _usuario != null;
  }

  // ── Logout: cierra sesión en Firebase y limpia estado local
  Future<void> logout() async {
    await _authService.logout();
    _usuario = null;
    _error = null;
    _cargando = false;
    notifyListeners();
  }

  // ── Actualizar URL de firma digital en Firestore y en el estado local
  Future<void> actualizarFirma(String firmaUrl) async {
    if (_usuario == null) return;
    await _authService.actualizarFirmaUrl(_usuario!.uid, firmaUrl);
    _usuario = _usuario!.copyWith(firmaUrl: firmaUrl);
    notifyListeners();
  }

  // ── Limpia el mensaje de error después de mostrarlo en la UI
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
