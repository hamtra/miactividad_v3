import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/usuario_model.dart';
import '../services/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SESION PROVIDER — gestión de estado del usuario autenticado
//
// Tras el login (o al recargar sesión), abre un Stream al documento Firestore
// del usuario. Cualquier cambio que un admin haga en ese perfil se refleja
// automáticamente en la app sin necesidad de re-login.
// ─────────────────────────────────────────────────────────────────────────────
class SesionProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UsuarioModel?                    _usuario;
  bool                             _cargando = false;
  String?                          _error;
  StreamSubscription<UsuarioModel?>? _perfilSub;

  UsuarioModel? get usuario    => _usuario;
  bool          get cargando   => _cargando;
  bool          get isLoggedIn => _usuario != null;
  bool          get esAdmin    =>
      _usuario?.rol.toUpperCase() == 'ADMINISTRADOR';
  String?       get error      => _error;

  // ── Suscripción al documento Firestore del usuario logueado ───────────────
  // Llama a este método después de cada login/reload para que cualquier
  // cambio en Firestore (ej. el admin cambia el género) se propague de
  // inmediato a la UI sin cerrar sesión.
  void _suscribirAlPerfil(String docId) {
    _perfilSub?.cancel();
    _perfilSub = _authService.streamUsuarioPorDocId(docId).listen((u) {
      if (u != null) {
        _usuario = u;
        notifyListeners();
      }
    });
  }

  // ── Cargar perfil desde Firestore (al reabrir app con sesión guardada) ────
  Future<void> cargarUsuario(String uid) async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      _usuario = await _authService.fetchUsuarioPorUid(uid);
      if (_usuario != null) _suscribirAlPerfil(_usuario!.uid);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _usuario = null;
    }
    _cargando = false;
    notifyListeners();
  }

  // ── Login: Firebase Auth + perfil de Firestore ────────────────────────────
  Future<bool> login(String email, String password) async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      _usuario = await _authService.login(email: email, password: password);
      if (_usuario != null) _suscribirAlPerfil(_usuario!.uid);
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

  // ── Logout: cierra sesión Firebase + limpia estado local ──────────────────
  Future<void> logout() async {
    _perfilSub?.cancel();
    _perfilSub = null;
    await _authService.logout();
    _usuario = null;
    _error = null;
    _cargando = false;
    notifyListeners();
  }

  // ── Actualizar celular ────────────────────────────────────────────────────
  Future<void> actualizarCelular(String celular) async {
    if (_usuario == null) return;
    await _authService.actualizarUsuario(
      _usuario!.uid,
      {'celular': celular},
    );
    // El stream _perfilSub actualizará _usuario automáticamente,
    // pero también lo hacemos localmente para respuesta inmediata en UI.
    _usuario = _usuario!.copyWith(celular: celular);
    notifyListeners();
  }

  // ── Actualizar firma digital ──────────────────────────────────────────────
  Future<void> actualizarFirma(String firmaUrl) async {
    if (_usuario == null) return;
    await _authService.actualizarFirmaUrl(_usuario!.uid, firmaUrl);
    _usuario = _usuario!.copyWith(firmaUrl: firmaUrl);
    notifyListeners();
  }

  // ── Limpia mensaje de error ───────────────────────────────────────────────
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _perfilSub?.cancel();
    super.dispose();
  }
}
