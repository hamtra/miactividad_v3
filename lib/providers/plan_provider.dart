import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  StreamSubscription? _planesSubscription;

  List<PlanTrabajo> get planes            => _planes;
  List<PlanTrabajo> get planesParaAprobar => _planesParaAprobar;
  List<PlanTrabajo> get todosLosPlanes    => _todosLosPlanes;
  bool              get cargando          => _cargando;
  bool              get sincronizando     => _sincronizando;
  String?           get error             => _error;

  // ── Cargar planes (con listener real-time Firestore) ──────────────────────────
  Future<void> cargarPlanes({String? usuario, String? mes}) async {
    _cargando = true;
    notifyListeners();
    await _planesSubscription?.cancel();

    try {
      if (!kIsWeb) {
        // Mobile: pintar desde SQLite inmediatamente
        _planes = await _db.getPlanes(usuario: usuario, mes: mes);
        _error  = null;
        _cargando = false;
        notifyListeners();
      }

      // Query Firestore con listener
      Query<Map<String, dynamic>> q = _fdb.collection(_colPlanes);
      if (usuario != null) q = q.where('usuario', isEqualTo: usuario);
      if (mes     != null) q = q.where('mes',     isEqualTo: mes);

      _planesSubscription = q.snapshots().listen((snap) async {
        if (kIsWeb) {
          _planes = snap.docs.map(_planFromFirestore).toList()
            ..sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
          _error    = null;
          _cargando = false;
        } else {
          // Mobile: actualizar/insertar en SQLite
          bool cambios = false;
          for (final doc in snap.docs) {
            final remoto = _planFromFirestore(doc);
            final idx    = _planes.indexWhere((p) => p.id == doc.id);
            if (idx < 0) {
              await _db.insertPlan(remoto);
              for (final t in remoto.tareas) await _db.insertTarea(t);
              await _db.markPlanSynced(remoto.id);
              _planes.add(remoto);
              cambios = true;
            } else {
              final local = _planes[idx];
              final data  = doc.data();
              final remEst = (data['estado'] as String?) ?? '';
              final remObs = data['observaciones'] as String?;
              if (local.estado != remEst || local.observaciones != remObs) {
                final updated = local.copyWith(
                    estado: remEst,
                    observaciones: remObs,
                    clearObservaciones: remObs == null);
                _planes[idx] = updated;
                await _db.updatePlan(updated);
                cambios = true;
              }
            }
          }
          if (!cambios) return; // sin cambios, no notificar
          _planes.sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
        }
        notifyListeners();
      }, onError: (e) {
        _error    = e.toString();
        _cargando = false;
        notifyListeners();
      });
    } catch (e) {
      _error    = e.toString();
      _cargando = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _planesSubscription?.cancel();
    super.dispose();
  }

  /// Baja desde Firestore todos los planes del usuario y los inserta/actualiza
  /// en SQLite. Útil cuando el técnico instala la app en otro dispositivo o
  /// cuando admins/coordinadores ven planes que ellos no crearon localmente.
  Future<void> _bajarPlanesDeFirestore(String usuarioDni,
      {String? mes}) async {
    try {
      Query<Map<String, dynamic>> q =
          _fdb.collection(_colPlanes).where('usuario', isEqualTo: usuarioDni);
      if (mes != null) q = q.where('mes', isEqualTo: mes);
      final snap = await q.get();
      bool huboCambios = false;
      for (final doc in snap.docs) {
        final remoto = _planFromFirestore(doc);
        // Inserta en SQLite (REPLACE) — gana el más reciente por updatedAt
        await _db.insertPlan(remoto);
        for (final t in remoto.tareas) {
          await _db.insertTarea(t);
        }
        await _db.markPlanSynced(remoto.id);
        huboCambios = true;
      }
      if (huboCambios) {
        // Releer desde SQLite para mostrar lo bajado
        _planes = await _db.getPlanes(usuario: usuarioDni, mes: mes);
        notifyListeners();
      }
    } catch (e) {
      // Sin internet — la app sigue mostrando lo local, no es error
      // ignore: avoid_print
      print('ℹ️ Sin internet o sin permisos Firestore: $e');
    }
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
  // IMPORTANTE: No usamos orderBy en Firestore porque documentos que no tienen
  // el campo 'fechaCreacion' quedan excluidos de la consulta. Ordenamos en memoria.
  Future<void> cargarTodosLosPlanes() async {
    _cargando = true;
    notifyListeners();
    try {
      final snap = await _fdb.collection(_colPlanes).get();
      _todosLosPlanes = snap.docs
          .map((doc) => _planFromFirestore(doc))
          .toList()
        ..sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
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
      String completadosJson = '';
      final completadosRaw = m['sociosCompletados'];
      if (completadosRaw is Map && completadosRaw.isNotEmpty) {
        final entries = completadosRaw.entries
            .map((e) => '"${e.key}":"${e.value}"')
            .join(',');
        completadosJson = '{$entries}';
      }
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
        sociosCompletadosJson: completadosJson,
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
      if (!kIsWeb) {
        await _db.insertPlan(plan);
        for (final tarea in plan.tareas) {
          await _db.insertTarea(tarea);
        }
      }
      // Firestore siempre (web: único storage; mobile: sync inmediato)
      await _doSync(plan);
      await cargarPlanes(usuario: plan.usuario);
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
      if (!kIsWeb) {
        await _db.updatePlan(plan);
        for (final tarea in plan.tareas) {
          await _db.insertTarea(tarea);
        }
      }
      await _doSync(plan);
      await cargarPlanes(usuario: plan.usuario);
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
      if (!kIsWeb) await _db.deleteTarea(tarea.id);
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
        if (!kIsWeb) await _db.updatePlan(updated);
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
        if (!kIsWeb) await _db.updatePlan(updated);
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
      if (!kIsWeb) await _db.updatePlan(updated);
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

  // ─────────────────────────────────────────────────────────────────────────────
  // SOCIOS COMPLETADOS  (cierre del ciclo Plan ↔ FAT)
  // ─────────────────────────────────────────────────────────────────────────────

  /// Marca un socio de una tarea como completado y dispara la sincronización
  /// del plan completo a Firestore.
  Future<void> marcarSocioCompletado({
    required String idTarea,
    required String idSocio,
    required String idFat,
    String? idPlanTrabajo,
  }) async {
    // SQLite solo en mobile
    if (!kIsWeb) {
      await _db.marcarSocioCompletado(
        idTarea: idTarea,
        idSocio: idSocio,
        idFat:   idFat,
      );
    }

    // Actualizar memoria si el plan ya está cargado
    bool encontrado = false;
    for (final plan in _planes) {
      final idx = plan.tareas.indexWhere((t) => t.id == idTarea);
      if (idx >= 0) {
        encontrado = true;
        if (!kIsWeb) {
          plan.tareas[idx] = (await _db.getTareasDePlan(plan.id))
              .firstWhere((t) => t.id == idTarea, orElse: () => plan.tareas[idx]);
        } else {
          // Actualizar en memoria directamente
          final tarea = plan.tareas[idx];
          final mapa = Map<String, String>.from(tarea.sociosCompletadosMap);
          mapa[idSocio] = idFat;
          plan.tareas[idx] = Tarea(
            id:                    tarea.id,
            idPlanTrabajo:         tarea.idPlanTrabajo,
            fecha:                 tarea.fecha,
            horaInicio:            tarea.horaInicio,
            horaFinal:             tarea.horaFinal,
            idPta:                 tarea.idPta,
            provincia:             tarea.provincia,
            distrito:              tarea.distrito,
            comunidad:             tarea.comunidad,
            detallePta:            tarea.detallePta,
            usuario:               tarea.usuario,
            sociosJson:            tarea.sociosJson,
            sociosCompletadosJson: '{${mapa.entries.map((e) => '"${e.key}":"${e.value}"').join(',')}}',
          );
        }
        notifyListeners();
        if (!kIsWeb) _syncPlanFirestore(plan);
        break;
      }
    }

    // Firestore directo: siempre en web; en mobile cuando el plan no estaba cargado
    final planId = idPlanTrabajo;
    if (planId != null && planId.isNotEmpty && (kIsWeb || !encontrado)) {
      await _sincronizarSocioFirestore(planId, idTarea, idSocio, idFat);
    }
  }

  Future<void> desmarcarSocioCompletado({
    required String idTarea,
    required String idSocio,
  }) async {
    if (!kIsWeb) {
      await _db.desmarcarSocioCompletado(idTarea: idTarea, idSocio: idSocio);
    }
    for (final plan in _planes) {
      final idx = plan.tareas.indexWhere((t) => t.id == idTarea);
      if (idx >= 0) {
        if (!kIsWeb) {
          plan.tareas[idx] = (await _db.getTareasDePlan(plan.id))
              .firstWhere((t) => t.id == idTarea, orElse: () => plan.tareas[idx]);
        }
        notifyListeners();
        if (!kIsWeb) _syncPlanFirestore(plan);
        break;
      }
    }
  }

  /// Actualiza directamente en Firestore el mapa sociosCompletados de una tarea.
  /// Se usa en web (SQLite vacío) y en mobile cuando el plan no está en _planes.
  Future<void> _sincronizarSocioFirestore(
      String idPlanTrabajo, String idTarea, String idSocio, String idFat) async {
    try {
      final ref = _fdb.collection(_colPlanes).doc(idPlanTrabajo);
      final doc = await ref.get();
      if (!doc.exists) return;
      final data = doc.data()!;
      final tareas = List<Map<String, dynamic>>.from(
          (data['tareas'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map)));
      for (int i = 0; i < tareas.length; i++) {
        if (tareas[i]['id'] == idTarea) {
          final completados = Map<String, dynamic>.from(
              (tareas[i]['sociosCompletados'] as Map?) ?? {});
          completados[idSocio] = idFat;
          tareas[i]['sociosCompletados'] = completados;
          break;
        }
      }
      await ref.update({'tareas': tareas, 'updatedAt': DateTime.now().toIso8601String()});
      // ignore: avoid_print
      print('✅ sociosCompletados sincronizado en Firestore: plan=$idPlanTrabajo tarea=$idTarea');
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ _sincronizarSocioFirestore error: $e');
    }
  }

  /// Tareas del usuario en una fecha específica (vista "Mi día").
  /// En web usa Firestore directamente (SQLite local está vacío en browser);
  /// en móvil/escritorio usa SQLite (offline-first).
  Future<List<Tarea>> tareasDelDia(String usuario, DateTime fecha) {
    if (kIsWeb) return _tareasDelDiaDesdeFirestore(usuario, fecha);
    return _db.getTareasDelDia(usuario, fecha);
  }

  /// Consulta Firestore para obtener las tareas de un usuario en una fecha dada.
  /// Descarga todos los planes del usuario y filtra en memoria por día.
  Future<List<Tarea>> _tareasDelDiaDesdeFirestore(
      String usuario, DateTime fecha) async {
    try {
      final snap = await _fdb
          .collection(_colPlanes)
          .where('usuario', isEqualTo: usuario)
          .get();

      final tareas = <Tarea>[];
      for (final doc in snap.docs) {
        final plan = _planFromFirestore(doc);
        for (final t in plan.tareas) {
          if (_mismoDia(t.fecha, fecha)) tareas.add(t);
        }
      }
      tareas.sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
      return tareas;
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ tareasDelDia Firestore error: $e');
      return [];
    }
  }

  bool _mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── Eliminar plan ─────────────────────────────────────────────────────────────
  Future<bool> eliminarPlan(String id) async {
    try {
      if (!kIsWeb) await _db.deletePlan(id);
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
    if (!kIsWeb) await _db.markPlanSynced(plan.id);
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
