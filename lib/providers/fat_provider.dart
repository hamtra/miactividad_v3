import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/fat.dart';
import '../database/db_helper.dart';
import 'plan_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FAT PROVIDER — SQLite offline-first + Firestore sync automático
//
// Colección Firestore : 4Cafe.FAT
// Flujo de estados    : REGISTRADO → ENVIADO → APROBADO
//                                  ↓              ↓
//                               OBSERVADO ────────┘ (re-enviar)
//
// La sincronización con Firestore es fire-and-forget (igual que PlanProvider):
// cada mutación local dispara _syncFatFirestore() en background.
// ─────────────────────────────────────────────────────────────────────────────
class FatProvider extends ChangeNotifier {
  final _db  = DbHelper();
  final _fdb = FirebaseFirestore.instance;

  static const String _colFats = '4Cafe.FAT';

  List<Fat> _fats = [];
  bool _cargando = false;
  String? _error;
  StreamSubscription? _fatsSubscription;

  /// Provider hermano (PlanProvider) — opcional. Se inyecta para poder
  /// cerrar el ciclo "FAT guardada → socio del plan completado" sin
  /// necesidad de pasar context cada vez.
  PlanProvider? _planProvider;
  void attachPlanProvider(PlanProvider p) => _planProvider = p;

  List<Fat> get fats     => _fats;
  bool      get cargando => _cargando;
  String?   get error    => _error;

  List<Fat> _todasLasFats = [];
  List<Fat> get todasLasFats => _todasLasFats;

  // ── Cargar TODAS las FATs desde Firestore (solo admin) ────────────────────
  // No usamos orderBy para no omitir documentos sin el campo de ordenación.
  Future<void> cargarTodasLasFats() async {
    _cargando = true;
    notifyListeners();
    try {
      final snap = await _fdb.collection(_colFats).get();
      _todasLasFats = snap.docs.map(_fatFromDoc).toList()
        ..sort((a, b) => b.fechaAsistencia.compareTo(a.fechaAsistencia));
      _error = null;
    } catch (e) {
      _error = e.toString();
      // ignore: avoid_print
      print('⚠️ cargarTodasLasFats error: $e');
    }
    _cargando = false;
    notifyListeners();
  }

  // ── Helper: Fat desde DocumentSnapshot ───────────────────────────────────────
  Fat _fatFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Fat(
      id:                      doc.id,
      nroFat:                  d['nroFat']               ?? '',
      fechaCreacion:           DateTime.tryParse(d['fechaCreacion']   ?? '') ?? DateTime.now(),
      fechaAsistencia:         DateTime.tryParse(d['fechaAsistencia'] ?? '') ?? DateTime.now(),
      modalidad:               d['modalidad']             ?? '',
      etapaCrianza:            d['etapaCrianza']          ?? 'Producción',
      idPta:                   d['idPta']                 ?? '',
      idTema:                  d['idTema']                ?? '',
      provincia:               d['provincia']             ?? '',
      distrito:                d['distrito']              ?? '',
      comunidad:               d['comunidad']             ?? '',
      ubicacion:               d['ubicacion'],
      horaInicio:              d['horaInicio']            ?? '08:00',
      horaFinal:               d['horaFinal']             ?? '17:00',
      clima:                   d['clima']                 ?? '',
      incidencia:              d['incidencia']            ?? '',
      idTecEspExt:             d['idTecEspExt']           ?? '',
      nombreTecnico:           d['nombreTecnico']         ?? '',
      idCargo:                 d['idCargo']               ?? '',
      cargo:                   d['cargo']                 ?? '',
      organizacionProductores: d['organizacionProductores'] ?? 'SIN ORGANIZACIÓN',
      idSocio:                 '',
      nroSociosParticipantes:  (d['nroSociosParticipantes'] as int?) ?? 0,
      actividadesRealizadas:   d['actividadesRealizadas'] ?? '',
      resultados:              d['resultados']            ?? '',
      acuerdosCompromisos:     d['acuerdosCompromisos']   ?? '',
      recomendaciones:         d['recomendaciones']       ?? '',
      proximaVisita:           DateTime.tryParse(d['proximaVisita'] ?? '')
          ?? DateTime.now().add(const Duration(days: 30)),
      proximaVisitaTema:       d['proximaVisitaTema']     ?? '',
      estado:                  d['estado']                ?? 'REGISTRADO',
      estadoObservaciones:     d['estadoObservaciones'],
      usuario:                 d['usuario']               ?? '',
      mes:                     d['mes']                   ?? '',
      synced:                  true,
      idTarea:                 d['idTarea'],
      idSocioPlan:             d['idSocioPlan'],
      // Fotos (URLs de Firebase Storage)
      fotografia1:         d['fotografia1'],
      foto1Descripcion:    d['foto1Descripcion'] ?? '',
      fotografia2:         d['fotografia2'],
      foto2Descripcion:    d['foto2Descripcion'] ?? '',
      fotografia3:         d['fotografia3'],
      foto3Descripcion:    d['foto3Descripcion'] ?? '',
      firmaSocio:          d['firmaSocio'],
    );
  }

  // ── Subir foto a Firebase Storage ────────────────────────────────────────────
  Future<String?> _subirFoto(String fatId, String campo, String? path) async {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;   // ya está en Storage
    if (path.startsWith('data:image')) return path; // base64 web (fallback)
    try {
      final ref = FirebaseStorage.instance.ref('fats/$fatId/$campo.jpg');
      await ref.putFile(File(path));
      final url = await ref.getDownloadURL();
      // ignore: avoid_print
      print('✅ Foto subida: $campo → $url');
      return url;
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ Upload $campo error: $e');
      return path; // fallback: path local
    }
  }

  // ── Cargar FATs del usuario (con listener real-time Firestore) ───────────────
  Future<void> cargarFats({String? usuario, String? mes, String? estado}) async {
    _cargando = true;
    notifyListeners();

    // Cancelar listener anterior
    await _fatsSubscription?.cancel();

    try {
      if (!kIsWeb) {
        // Mobile: cargar SQLite inmediatamente (offline-first)
        _fats = await _db.getFats(usuario: usuario, mes: mes, estado: estado);
        _error = null;
        _cargando = false;
        notifyListeners();
      }

      // Construir query Firestore
      Query<Map<String, dynamic>> q = _fdb.collection(_colFats);
      if (usuario != null) q = q.where('usuario', isEqualTo: usuario);
      if (mes     != null) q = q.where('mes',     isEqualTo: mes);
      if (estado  != null) q = q.where('estado',  isEqualTo: estado);

      // Listener en tiempo real (web + mobile)
      _fatsSubscription = q.snapshots().listen((snap) async {
        if (kIsWeb) {
          _fats = snap.docs.map(_fatFromDoc).toList()
            ..sort((a, b) => b.fechaAsistencia.compareTo(a.fechaAsistencia));
          _error = null;
          _cargando = false;
        } else {
          // Mobile: sincronizar cambios remotos a SQLite
          for (final doc in snap.docs) {
            final fat = _fatFromDoc(doc);
            final idx = _fats.indexWhere((f) => f.id == doc.id);
            if (idx < 0) {
              await _db.insertFat(fat);
              _fats.add(fat);
            } else {
              final local = _fats[idx];
              if (local.estado != fat.estado ||
                  local.estadoObservaciones != fat.estadoObservaciones) {
                local.estado = fat.estado;
                local.estadoObservaciones = fat.estadoObservaciones;
                await _db.updateFatEstado(local.id, fat.estado,
                    observaciones: fat.estadoObservaciones);
              }
            }
          }
          _fats.sort((a, b) => b.fechaAsistencia.compareTo(a.fechaAsistencia));
        }
        notifyListeners();
      }, onError: (e) {
        _error = e.toString();
        _cargando = false;
        notifyListeners();
      });
    } catch (e) {
      _error = e.toString();
      _cargando = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _fatsSubscription?.cancel();
    super.dispose();
  }

  /// Baja las FATs del usuario desde Firestore: inserta las nuevas en SQLite
  /// y actualiza estados de las existentes (aprobadas/observadas).
  Future<void> _bajarFatsDeFirestore(String usuario, {String? mes}) async {
    try {
      Query<Map<String, dynamic>> q =
          _fdb.collection(_colFats).where('usuario', isEqualTo: usuario);
      if (mes != null) q = q.where('mes', isEqualTo: mes);
      final snap = await q.get();

      bool huboCambios = false;
      for (final doc in snap.docs) {
        final data         = doc.data();
        final remotoEstado = (data['estado'] as String?) ?? 'REGISTRADO';
        final remotoObs    = data['estadoObservaciones'] as String?;
        final idx          = _fats.indexWhere((f) => f.id == doc.id);

        if (idx >= 0) {
          // Ya existe localmente — actualizar estado si cambió
          final local = _fats[idx];
          if (local.estado != remotoEstado ||
              local.estadoObservaciones != remotoObs) {
            local.estado              = remotoEstado;
            local.estadoObservaciones = remotoObs;
            await _db.updateFatEstado(local.id, remotoEstado,
                observaciones: remotoObs);
            huboCambios = true;
          }
        } else {
          // No existe localmente → insertar desde Firestore
          final fat = _fatFromDoc(doc);
          await _db.insertFat(fat);
          _fats.add(fat);
          // Insertar socios si vienen embebidos
          final sociosList = (data['socios'] as List? ?? []);
          for (final s in sociosList) {
            final m = Map<String, dynamic>.from(s as Map);
            await _db.insertSocio(SocioParticipante(
              id:             m['id']      ?? doc.id,
              idFat:          doc.id,
              idSocio:        m['idSocio'] ?? '',
              dni:            m['dni']     ?? '',
              nombreCompleto: m['nombre']  ?? '',
              mes:            data['mes']  ?? '',
              usuario:        data['usuario'] ?? '',
            ));
          }
          huboCambios = true;
        }
      }
      if (huboCambios) {
        _fats.sort((a, b) => b.fechaAsistencia.compareTo(a.fechaAsistencia));
        notifyListeners();
      }
    } catch (e) {
      // Sin internet — la app sigue mostrando los datos locales
      // ignore: avoid_print
      print('ℹ️ Sin internet al bajar FATs de Firestore: $e');
    }
  }

  // ── Guardar nueva FAT ─────────────────────────────────────────────────────────
  Future<bool> guardarFat(Fat fat,
      {List<SocioParticipante> socios = const [],
      String? idPlanTrabajo}) async {
    try {
      if (kIsWeb) {
        // Web: escribe directo a Firestore (SQLite local no funciona en browser)
        await _doSyncFat(fat, socios: socios);
      } else {
        await _db.insertFat(fat);
        for (final s in socios) {
          await _db.insertSocio(s);
        }
      }
      _fats.insert(0, fat);
      notifyListeners();
      // Cerrar ciclo plan ↔ FAT (best-effort en ambas plataformas)
      try { await _sincronizarConPlan(fat, idPlanTrabajo: idPlanTrabajo); } catch (_) {}
      // Mobile: sync Firestore en background (web ya lo hizo arriba)
      if (!kIsWeb) _syncFatFirestore(fat, socios: socios);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Actualizar FAT existente ──────────────────────────────────────────────────
  Future<bool> actualizarFat(Fat fat,
      {List<SocioParticipante>? socios,
      String? idPlanTrabajo}) async {
    try {
      if (kIsWeb) {
        await _doSyncFat(fat, socios: socios);
      } else {
        await _db.updateFat(fat);
        if (socios != null) {
          await _db.deleteSociosDeFat(fat.id);
          for (final s in socios) {
            await _db.insertSocio(s);
          }
        }
      }
      final idx = _fats.indexWhere((f) => f.id == fat.id);
      if (idx >= 0) _fats[idx] = fat;
      notifyListeners();
      try { await _sincronizarConPlan(fat, idPlanTrabajo: idPlanTrabajo); } catch (_) {}
      if (!kIsWeb) _syncFatFirestore(fat, socios: socios);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Cambiar estado (genérico) ──────────────────────────────────────────────────
  Future<bool> cambiarEstado(String fatId, String estado,
      {String? observaciones}) async {
    try {
      // Web: solo actualiza en memoria + Firestore (sin SQLite)
      if (!kIsWeb) {
        await _db.updateFatEstado(fatId, estado, observaciones: observaciones);
      }
      final idx = _fats.indexWhere((f) => f.id == fatId);
      if (idx >= 0) {
        _fats[idx].estado = estado;
        if (observaciones != null) {
          _fats[idx].estadoObservaciones = observaciones;
        }
        notifyListeners();
        _syncEstadoFirestore(fatId, estado, observaciones: observaciones);
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Enviar para aprobación (REGISTRADO/OBSERVADO → ENVIADO) ───────────────────
  Future<bool> enviarFat(String fatId) async {
    return cambiarEstado(fatId, 'ENVIADO');
  }

  // ── Aprobar FAT (ENVIADO → APROBADO) — acción del coordinador/admin ─────────
  Future<bool> aprobarFat(String fatId) async {
    return cambiarEstado(fatId, 'APROBADO');
  }

  // ── Observar FAT (ENVIADO → OBSERVADO) — acción del coordinador/admin ────────
  Future<bool> observarFat(String fatId, String observaciones) async {
    return cambiarEstado(fatId, 'OBSERVADO', observaciones: observaciones);
  }

  // ── Eliminar FAT ──────────────────────────────────────────────────────────────
  Future<bool> eliminarFat(String id) async {
    try {
      // Capturamos el vínculo antes de borrar
      Fat? fat;
      final idx = _fats.indexWhere((f) => f.id == id);
      if (idx >= 0) fat = _fats[idx];
      if (!kIsWeb) {
        fat ??= await _db.getFatById(id);
        await _db.deleteFat(id);
      }
      _fats.removeWhere((f) => f.id == id);
      notifyListeners();
      // Desmarcar en el plan si estaba vinculada
      if (fat != null && fat.idTarea != null && fat.idSocioPlan != null) {
        try {
          if (_planProvider != null) {
            await _planProvider!.desmarcarSocioCompletado(
              idTarea: fat.idTarea!,
              idSocio: fat.idSocioPlan!,
            );
          } else {
            await _db.desmarcarSocioCompletado(
              idTarea: fat.idTarea!,
              idSocio: fat.idSocioPlan!,
            );
          }
        } catch (_) {}
      }
      // Eliminar también en Firestore (best-effort)
      _fdb.collection(_colFats).doc(id).delete().catchError((_) {});
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Helpers de estado ──────────────────────────────────────────────────────────
  Future<List<SocioParticipante>> getSociosDeFat(String idFat) async {
    if (kIsWeb) {
      try {
        final doc = await _fdb.collection(_colFats).doc(idFat).get();
        if (!doc.exists) return [];
        final data = doc.data()!;
        final lista = (data['socios'] as List? ?? []);
        return List<SocioParticipante>.from(lista.map((s) {
          final m = Map<String, dynamic>.from(s as Map);
          return SocioParticipante(
            id:             m['id']      ?? '',
            idFat:          idFat,
            idSocio:        m['idSocio'] ?? '',
            dni:            m['dni']     ?? '',
            nombreCompleto: m['nombre']  ?? '',
            mes:            m['mes']     ?? '',
            usuario:        m['usuario'] ?? '',
          );
        }));
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ getSociosDeFat web error: $e');
        return [];
      }
    }
    return _db.getSociosDeFat(idFat);
  }

  Map<String, int> countByEstado() {
    final counts = <String, int>{};
    for (final f in _fats) {
      counts[f.estado] = (counts[f.estado] ?? 0) + 1;
    }
    return counts;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SYNC CON PLAN  (cierre del ciclo Plan ↔ FAT)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Si la FAT está vinculada a una tarea/socio del plan, marca ese socio
  /// como completado en el plan_trabajo. Silencioso si no hay vínculo.
  Future<void> _sincronizarConPlan(Fat fat, {String? idPlanTrabajo}) async {
    final idTarea = fat.idTarea;
    final idSocio = fat.idSocioPlan;
    if (idTarea == null || idTarea.isEmpty) return;
    if (idSocio == null || idSocio.isEmpty) return;
    try {
      if (_planProvider != null) {
        await _planProvider!.marcarSocioCompletado(
          idTarea:       idTarea,
          idSocio:       idSocio,
          idFat:         fat.id,
          idPlanTrabajo: idPlanTrabajo,
        );
      } else if (!kIsWeb) {
        await _db.marcarSocioCompletado(
          idTarea: idTarea,
          idSocio: idSocio,
          idFat:   fat.id,
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ Sync con plan falló: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SYNC FIRESTORE (fire-and-forget)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Sube la FAT completa a Firestore (fat + lista de socios embebida).
  void _syncFatFirestore(Fat fat, {List<SocioParticipante>? socios}) {
    _doSyncFat(fat, socios: socios).catchError((e) {
      // ignore: avoid_print
      print('⚠️ FAT Sync falló (${fat.id}): $e');
    });
  }

  Future<void> _doSyncFat(Fat fat, {List<SocioParticipante>? socios}) async {
    // En mobile: subir fotos locales a Firebase Storage antes de guardar URL
    String? url1 = fat.fotografia1;
    String? url2 = fat.fotografia2;
    String? url3 = fat.fotografia3;
    String? urlFirma = fat.firmaSocio;
    if (!kIsWeb) {
      url1    = await _subirFoto(fat.id, 'foto1',  fat.fotografia1);
      url2    = await _subirFoto(fat.id, 'foto2',  fat.fotografia2);
      url3    = await _subirFoto(fat.id, 'foto3',  fat.fotografia3);
      urlFirma = await _subirFoto(fat.id, 'firma', fat.firmaSocio);
    }

    final data = {
      ...fat.toFirestore(),
      // Sobreescribir con URLs de Storage (si se subieron)
      if (url1     != null && url1.isNotEmpty)     'fotografia1': url1,
      if (url2     != null && url2.isNotEmpty)     'fotografia2': url2,
      if (url3     != null && url3.isNotEmpty)     'fotografia3': url3,
      if (urlFirma != null && urlFirma.isNotEmpty) 'firmaSocio':  urlFirma,
      if (socios != null)
        'socios': socios
            .map((s) => {
                  'id': s.id,
                  'idSocio': s.idSocio,
                  'dni': s.dni,
                  'nombre': s.nombreCompleto,
                })
            .toList(),
    };
    await _fdb.collection(_colFats).doc(fat.id).set(data);
    if (!kIsWeb) await _db.markFatSynced(fat.id);
    // ignore: avoid_print
    print('✅ FAT sincronizada: ${fat.id}');
  }

  /// Actualiza solo el estado en Firestore (más ligero que subir todo).
  void _syncEstadoFirestore(String fatId, String estado,
      {String? observaciones}) {
    _fdb.collection(_colFats).doc(fatId).update({
      'estado': estado,
      if (observaciones != null) 'estadoObservaciones': observaciones,
      'updatedAt': DateTime.now().toIso8601String(),
    }).catchError((e) {
      // ignore: avoid_print
      print('⚠️ FAT estado sync falló ($fatId): $e');
    });
  }

  /// Sync masivo de FATs pendientes (synced = 0). Útil al recuperar conexión.
  Future<void> syncPendientes() async {
    try {
      final pendientes = await _db.getFatsNoSynced();
      for (final fat in pendientes) {
        final socios = await _db.getSociosDeFat(fat.id);
        await _doSyncFat(fat, socios: socios);
      }
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ FAT syncPendientes error: $e');
    }
  }
}
