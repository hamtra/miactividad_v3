import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/plan_trabajo.dart';
import '../database/db_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PLAN PROVIDER — SQLite offline-first + Firestore sync
//
// Colección Firestore : 4Cafe.PlanTrabajo
// Flujo de estados    : REGISTRADO → ENVIADO → APROBADO
//                                  ↓              ↓
//                               OBSERVADO ────────┘ (re-enviar)
//
// Reglas:
//   • Técnico puede enviar desde REGISTRADO u OBSERVADO.
//   • Coordinador puede aprobar u observar desde ENVIADO.
//   • Solo en estado APROBADO se permite generar el PDF.
//   • Admin puede ejecutar TODAS las acciones.
// ─────────────────────────────────────────────────────────────────────────────
class PlanProvider extends ChangeNotifier {
  final _db  = DbHelper();
  final _fdb = FirebaseFirestore.instance;

  static const String _colPlanes = '4Cafe.PlanTrabajo';

  List<PlanTrabajo> _planes            = [];
  List<PlanTrabajo> _planesParaAprobar = [];
  List<PlanTrabajo> _todosLosPlanes    = [];   // solo admin
  bool              _cargando          = false;
  bool              _sincronizando     = false;
  String?           _error;

  List<PlanTrabajo> get planes            => _planes;
  List<PlanTrabajo> get planesParaAprobar => _planesParaAprobar;
  List<PlanTrabajo> get todosLosPlanes    => _todosLosPlanes;
  bool              get cargando          => _cargando;
  bool              get sincronizando     => _sincronizando;
  String?           get error             => _error;

  // ── Cargar planes del técnico desde SQLite ──────────────────────────────────
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

    // Sincroniza estados desde Firestore en background (sin bloquear la UI)
    if (usuario != null) _sincronizarEstados(usuario);
  }

  // ── Sincronizar estados Firestore → SQLite (fire-and-forget) ─────────────────
  // Compara cada plan en _planes con su estado en Firestore.
  // Si difiere (coordinador aprobó/observó), actualiza _planes y SQLite.
  Future<void> _sincronizarEstados(String usuarioDni) async {
    try {
      final snap = await _fdb
          .collection(_colPlanes)
          .where('usuario', isEqualTo: usuarioDni)
          .get();

      bool cambio = false;
      for (final doc in snap.docs) {
        final data             = doc.data();
        final firestoreEstado  = (data['estado'] as String?) ?? '';
        final firestoreObs     = data['observaciones'] as String?;

        final idx = _planes.indexWhere((p) => p.id == doc.id);
        if (idx >= 0) {
          final local = _planes[idx];
          final estadoDistinto = local.estado != firestoreEstado;
          final obsDistinta    = local.observaciones != firestoreObs;

          if (estadoDistinto || obsDistinta) {
            final updated = firestoreObs == null
                ? local.copyWith(
                    estado: firestoreEstado,
                    clearObservaciones: true)
                : local.copyWith(
                    estado: firestoreEstado,
                    observaciones: firestoreObs);
            _planes[idx] = updated;
            await _db.updatePlan(updated);
            cambio = true;
          }
        }
      }
      if (cambio) notifyListeners();
    } catch (_) {
      // Sin internet → se usan los datos de SQLite tal cual
    }
  }

  // ── Cargar planes que el coordinador/admin debe aprobar (desde Firestore) ─────
  Future<void> cargarPlanesParaAprobar(String coordinadorUid,
      {bool esAdmin = false}) async {
    _cargando = true;
    notifyListeners();
    try {
      QuerySnapshot<Map<String, dynamic>> snap;
      if (esAdmin) {
        snap = await _fdb
            .collection(_colPlanes)
            .where('estado', isEqualTo: 'ENVIADO')
            .get();
      } else {
        snap = await _fdb
            .collection(_colPlanes)
            .where('idCoordinador', isEqualTo: coordinadorUid)
            .where('estado', isEqualTo: 'ENVIADO')
            .get();
      }

      _planesParaAprobar = snap.docs
          .map((doc) => _planFromFirestore(doc))
          .toList();
      _error = null;
    } catch (e) {
      _error = e.toString();
      // ignore: avoid_print
      print('⚠️ cargarPlanesParaAprobar error: $e');
    }
    _cargando = false;
    notifyListeners();
  }

  String _listToJson(List list) {
    return '[${list.map((e) => '{"id":"${e['id']}","nombre":"${e['nombre']}","dni":"${e['dni'] ?? ''}"}').join(',')}]';
  }

  // ── Cargar TODOS los planes desde Firestore (solo admin) ─────────────────────
  Future<void> cargarTodosLosPlanes() async {
    _cargando = true;
    notifyListeners();
    try {
      final snap = await _fdb
          .collection(_colPlanes)
          .orderBy('fechaCreacion', descending: true)
          .get();
      _todosLosPlanes = snap.docs.map((doc) => _planFromFirestore(doc)).toList();
      _error = null;
    } catch (e) {
      _error = e.toString();
      // ignore: avoid_print
      print('⚠️ cargarTodosLosPlanes error: $e');
    }
    _cargando = false;
    notifyListeners();
  }

  /// Volver un plan al estado REGISTRADO (solo admin, desde cualquier estado)
  Future<bool> registrarPlan(String planId) async {
    try {
      await _fdb.collection(_colPlanes).doc(planId).update({
        'estado':        'REGISTRADO',
        'observaciones': null,
        'updatedAt':     DateTime.now().toIso8601String(),
      });

      // Actualizar _todosLosPlanes si existe
      final idx1 = _todosLosPlanes.indexWhere((p) => p.id == planId);
      if (idx1 >= 0) {
        _todosLosPlanes[idx1] = _todosLosPlanes[idx1].copyWith(
          estado: 'REGISTRADO',
          clearObservaciones: true,
        );
      }

      // Actualizar _planes (SQLite) si existe
      final idx2 = _planes.indexWhere((p) => p.id == planId);
      if (idx2 >= 0) {
        final updated = _planes[idx2].copyWith(
          estado: 'REGISTRADO',
          clearObservaciones: true,
        );
        _planes[idx2] = updated;
        await _db.updatePlan(updated);
      }

      // Sacar de Para Aprobar si estaba
      _planesParaAprobar.removeWhere((p) => p.id == planId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Helper: construir PlanTrabajo desde DocumentSnapshot ────────────────────
  PlanTrabajo _planFromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final tareasDocs = (d['tareas'] as List? ?? []);
    final tareas = tareasDocs.map((t) {
      final m = Map<String, dynamic>.from(t as Map);
      return Tarea(
        id:            m['id']         ?? '',
        idPlanTrabajo: doc.id,
        fecha:         DateTime.tryParse(m['fecha'] ?? '') ?? DateTime.now(),
        horaInicio:    m['horaInicio'] ?? '',
        horaFinal:     m['horaFinal']  ?? '',
        idPta:         m['idPta']      ?? '',
        provincia:     m['provincia']  ?? '',
        distrito:      m['distrito']   ?? '',
        comunidad:     m['comunidad']  ?? '',
        detallePta:    m['detallePta'] ?? '',
        usuario:       m['usuario']    ?? '',
        sociosJson: m['socios'] is List
            ? (m['socios'] as List).isEmpty
                ? ''
                : _listToJson(m['socios'] as List)
            : '',
      );
    }).toList();
    return PlanTrabajo(
      id:                doc.id,
      mes:               d['mes']               ?? '',
      idTecEspExt:       d['idTecEspExt']        ?? '',
      nombreTecnico:     d['nombreTecnico']       ?? '',
      nombreActividad:   d['nombreActividad']     ?? '',
      fechaCreacion:     DateTime.tryParse(d['fechaCreacion'] ?? '') ?? DateTime.now(),
      idCoordinador:     d['idCoordinador']       ?? '',
      nombreCoordinador: d['nombreCoordinador']   ?? '',
      estado:            d['estado']              ?? 'REGISTRADO',
      usuario:           d['usuario']             ?? '',
      observaciones:     d['observaciones'],
      tareas:            tareas,
      synced:            true,
    );
  }

  // ── Guardar nuevo plan ───────────────────────────────────────────────────────
  Future<bool> guardarPlan(PlanTrabajo plan) async {
    try {
      await _db.insertPlan(plan);
      for (final tarea in plan.tareas) {
        await _db.insertTarea(tarea);
      }
      await cargarPlanes(usuario: plan.usuario);
      _syncPlanFirestore(plan);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Actualizar plan existente ────────────────────────────────────────────────
  Future<bool> actualizarPlan(PlanTrabajo plan) async {
    try {
      await _db.updatePlan(plan);
      for (final tarea in plan.tareas) {
        await _db.insertTarea(tarea);
      }
      await cargarPlanes(usuario: plan.usuario);
      _syncPlanFirestore(plan);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Agregar tarea ─────────────────────────────────────────────────────────────
  Future<bool> agregarTarea(Tarea tarea) async {
    try {
      await _db.insertTarea(tarea);
      final idx = _planes.indexWhere((p) => p.id == tarea.idPlanTrabajo);
      if (idx >= 0) {
        _planes[idx].tareas.add(tarea);
        notifyListeners();
        _syncPlanFirestore(_planes[idx]);
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Eliminar tarea ────────────────────────────────────────────────────────────
  Future<bool> eliminarTarea(Tarea tarea) async {
    try {
      await _db.deleteTarea(tarea.id);
      final idx = _planes.indexWhere((p) => p.id == tarea.idPlanTrabajo);
      if (idx >= 0) {
        _planes[idx].tareas.removeWhere((t) => t.id == tarea.id);
        notifyListeners();
        _syncPlanFirestore(_planes[idx]);
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // GESTIÓN DE ESTADOS
  // ─────────────────────────────────────────────────────────────────────────────

  /// REGISTRADO / OBSERVADO → ENVIADO  (acción del técnico o admin)
  Future<bool> enviarPlan(String planId) async {
    return _cambiarEstadoLocal(planId, 'ENVIADO');
  }

  /// ENVIADO → APROBADO  (acción del coordinador o admin)
  Future<bool> aprobarPlan(String planId) async {
    try {
      await _fdb.collection(_colPlanes).doc(planId).update({
        'estado':    'APROBADO',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Actualizar _planes + SQLite si el plan está en la lista local
      final idx = _planes.indexWhere((p) => p.id == planId);
      if (idx >= 0) {
        final updated = _planes[idx].copyWith(estado: 'APROBADO');
        _planes[idx] = updated;
        await _db.updatePlan(updated);
      }

      // Actualizar _todosLosPlanes si está ahí
      final idx2 = _todosLosPlanes.indexWhere((p) => p.id == planId);
      if (idx2 >= 0) {
        _todosLosPlanes[idx2] = _todosLosPlanes[idx2].copyWith(estado: 'APROBADO');
      }

      _planesParaAprobar.removeWhere((p) => p.id == planId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// ENVIADO → OBSERVADO  (acción del coordinador o admin, requiere texto)
  Future<bool> observarPlan(String planId, String observaciones) async {
    try {
      await _fdb.collection(_colPlanes).doc(planId).update({
        'estado':        'OBSERVADO',
        'observaciones': observaciones,
        'updatedAt':     DateTime.now().toIso8601String(),
      });

      // Actualizar _planes + SQLite si el plan está en la lista local
      final idx = _planes.indexWhere((p) => p.id == planId);
      if (idx >= 0) {
        final updated = _planes[idx].copyWith(
          estado: 'OBSERVADO',
          observaciones: observaciones,
        );
        _planes[idx] = updated;
        await _db.updatePlan(updated);
      }

      // Actualizar _todosLosPlanes si está ahí
      final idx2 = _todosLosPlanes.indexWhere((p) => p.id == planId);
      if (idx2 >= 0) {
        _todosLosPlanes[idx2] = _todosLosPlanes[idx2].copyWith(
          estado: 'OBSERVADO',
          observaciones: observaciones,
        );
      }

      _planesParaAprobar.removeWhere((p) => p.id == planId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> _cambiarEstadoLocal(String planId, String nuevoEstado,
      {String? observaciones}) async {
    try {
      final idx = _planes.indexWhere((p) => p.id == planId);
      if (idx < 0) {
        _error = 'Plan no encontrado en caché. Recarga la pantalla.';
        notifyListeners();
        return false;
      }
      final updated = _planes[idx].copyWith(
        estado:       nuevoEstado,
        observaciones: observaciones,
      );
      await _db.updatePlan(updated);
      _planes[idx] = updated;
      notifyListeners();
      _syncPlanFirestore(updated);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Eliminar plan ─────────────────────────────────────────────────────────────
  Future<bool> eliminarPlan(String id) async {
    try {
      await _db.deletePlan(id);
      _planes.removeWhere((p) => p.id == id);
      _todosLosPlanes.removeWhere((p) => p.id == id);
      notifyListeners();
      _fdb.collection(_colPlanes).doc(id).delete().catchError((_) {});
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // SYNC FIRESTORE (fire-and-forget)
  // ─────────────────────────────────────────────────────────────────────────────
  void _syncPlanFirestore(PlanTrabajo plan) {
    _doSync(plan).catchError((e) {
      // ignore: avoid_print
      print('⚠️ Sync falló (${plan.id}): $e');
    });
  }

  Future<void> _doSync(PlanTrabajo plan) async {
    await _fdb.collection(_colPlanes).doc(plan.id).set({
      ...plan.toFirestore(),
      'tareas': plan.tareas.map((t) => t.toFirestoreMap()).toList(),
    });
    await _db.markPlanSynced(plan.id);
    // ignore: avoid_print
    print('✅ Plan sincronizado: ${plan.id}');
  }

  // ── Sync masivo (synced = 0) ──────────────────────────────────────────────────
  Future<void> syncPendientes() async {
    if (_sincronizando) return;
    _sincronizando = true;
    notifyListeners();
    try {
      final pendientes = await _db.getPlanesNoSynced();
      for (final plan in pendientes) {
        plan.tareas = await _db.getTareasDePlan(plan.id);
        await _doSync(plan);
      }
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ syncPendientes error: $e');
    }
    _sincronizando = false;
    notifyListeners();
  }
}
