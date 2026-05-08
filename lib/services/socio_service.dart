import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/socio_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SOCIO SERVICE
//
// Consulta la colección `mg.socios_ae` en Firestore.
// Filtros: por comunidad (nombre_lugar_intervencion) + estado ALTA.
// Subir datos: ejecutar `node subir_socios_ae.js` desde la raíz del proyecto.
// ─────────────────────────────────────────────────────────────────────────────
class SocioService {
  final _db = FirebaseFirestore.instance;
  static const _col = 'mg.socios_ae';

  // Caché en memoria para no repetir consultas durante la misma sesión
  final Map<String, List<SocioModel>> _cache = {};

  // ── Socios de una comunidad ────────────────────────────────────────────────
  // NOTA: Se usa solo un filtro `where` para evitar requerir índice compuesto
  // en Firestore. El segundo filtro (estado==ALTA) y el orden se aplican en Dart.
  Future<List<SocioModel>> getSociosPorComunidad(String comunidad) async {
    if (_cache.containsKey(comunidad)) return _cache[comunidad]!;
    try {
      final snap = await _db
          .collection(_col)
          .where('nombre_lugar_intervencion', isEqualTo: comunidad)
          .get();

      final lista = snap.docs
          .map((d) => SocioModel.fromFirestore(d))
          .where((s) => s.estado == 'activo') // filtro local (script usa 'activo'/'baja')
          .toList()
        ..sort((a, b) => a.nombreCompleto.compareTo(b.nombreCompleto));

      _cache[comunidad] = lista;
      // ignore: avoid_print
      print('✅ SocioService: ${lista.length} socios en "$comunidad"');
      return lista;
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ SocioService error ($comunidad): $e');
      rethrow;   // relanzar para que _SocioSelectorSheet muestre el error real
    }
  }

  // ── Búsqueda local dentro de la comunidad ─────────────────────────────────
  Future<List<SocioModel>> buscar(String comunidad, String query) async {
    final todos = await getSociosPorComunidad(comunidad);
    if (query.trim().isEmpty) return todos;
    final q = query.trim().toUpperCase();
    return todos
        .where((s) =>
            s.nombreCompleto.contains(q) ||
            s.dni.contains(q))
        .toList();
  }

  void limpiarCache() => _cache.clear();
}
