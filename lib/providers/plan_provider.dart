import 'package:flutter/material.dart';
import '../models/plan_trabajo.dart';
import '../database/db_helper.dart';

class PlanProvider extends ChangeNotifier {
  final _db = DbHelper();
  List<PlanTrabajo> _planes = [];
  bool _cargando = false;
  String? _error;

  List<PlanTrabajo> get planes => _planes;
  bool get cargando => _cargando;
  String? get error => _error;

  Future<void> cargarPlanes({String? usuario, String? mes}) async {
    _cargando = true;
    notifyListeners();
    try {
      _planes = await _db.getPlanes(usuario: usuario, mes: mes);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _cargando = false;
    notifyListeners();
  }

  Future<bool> guardarPlan(PlanTrabajo plan) async {
    try {
      await _db.insertPlan(plan);
      for (final tarea in plan.tareas) {
        await _db.insertTarea(tarea);
      }
      await cargarPlanes(usuario: plan.usuario);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> actualizarPlan(PlanTrabajo plan) async {
    try {
      await _db.updatePlan(plan);
      // Borrar tareas antiguas y reinsertar
      for (final tarea in plan.tareas) {
        await _db.insertTarea(tarea);
      }
      await cargarPlanes(usuario: plan.usuario);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> agregarTarea(Tarea tarea) async {
    try {
      await _db.insertTarea(tarea);
      // Actualizar lista local
      final idx = _planes.indexWhere((p) => p.id == tarea.idPlanTrabajo);
      if (idx >= 0) {
        _planes[idx].tareas.add(tarea);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> eliminarTarea(Tarea tarea) async {
    try {
      await _db.deleteTarea(tarea.id);
      final idx = _planes.indexWhere((p) => p.id == tarea.idPlanTrabajo);
      if (idx >= 0) {
        _planes[idx].tareas.removeWhere((t) => t.id == tarea.id);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> cambiarEstado(String planId, String nuevoEstado) async {
    try {
      final idx = _planes.indexWhere((p) => p.id == planId);
      if (idx < 0) return false;
      final updated = _planes[idx].copyWith(estado: nuevoEstado);
      await _db.updatePlan(updated);
      _planes[idx] = updated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> eliminarPlan(String id) async {
    try {
      await _db.deletePlan(id);
      _planes.removeWhere((p) => p.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
