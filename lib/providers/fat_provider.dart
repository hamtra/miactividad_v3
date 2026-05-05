import 'package:flutter/material.dart';
import '../models/fat.dart';
import '../database/db_helper.dart';

class FatProvider extends ChangeNotifier {
  final _db = DbHelper();
  List<Fat> _fats = [];
  bool _cargando = false;
  String? _error;

  List<Fat> get fats => _fats;
  bool get cargando => _cargando;
  String? get error => _error;

  Future<void> cargarFats({String? usuario, String? mes, String? estado}) async {
    _cargando = true;
    notifyListeners();
    try {
      _fats = await _db.getFats(usuario: usuario, mes: mes, estado: estado);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _cargando = false;
    notifyListeners();
  }

  Future<bool> guardarFat(Fat fat,
      {List<SocioParticipante> socios = const []}) async {
    try {
      await _db.insertFat(fat);
      for (final s in socios) {
        await _db.insertSocio(s);
      }
      _fats.insert(0, fat);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> actualizarFat(Fat fat,
      {List<SocioParticipante>? socios}) async {
    try {
      await _db.updateFat(fat);
      if (socios != null) {
        await _db.deleteSociosDeFat(fat.id);
        for (final s in socios) {
          await _db.insertSocio(s);
        }
      }
      final idx = _fats.indexWhere((f) => f.id == fat.id);
      if (idx >= 0) _fats[idx] = fat;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> cambiarEstado(String fatId, String estado,
      {String? observaciones}) async {
    try {
      await _db.updateFatEstado(fatId, estado,
          observaciones: observaciones);
      final idx = _fats.indexWhere((f) => f.id == fatId);
      if (idx >= 0) {
        _fats[idx].estado = estado;
        if (observaciones != null) {
          _fats[idx].estadoObservaciones = observaciones;
        }
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> eliminarFat(String id) async {
    try {
      await _db.deleteFat(id);
      _fats.removeWhere((f) => f.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<List<SocioParticipante>> getSociosDeFat(String idFat) {
    return _db.getSociosDeFat(idFat);
  }

  Map<String, int> countByEstado() {
    final counts = <String, int>{};
    for (final f in _fats) {
      counts[f.estado] = (counts[f.estado] ?? 0) + 1;
    }
    return counts;
  }
}
