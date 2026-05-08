import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SOCIO MODEL
//
// Mapea un documento de la colección `mg.socios_ae` en Firestore.
// Cargado con el script subir_socios_ae.js desde PadronSocios_2025.csv/xlsx
// Campo estado: 'activo' | 'baja'  (el script usa estos valores)
// ─────────────────────────────────────────────────────────────────────────────
class SocioModel {
  final String idSocio;           // doc.id  = "id_so_000001"
  final String nombreCompleto;    // ap_nombres_t
  final String dni;               // dni_t
  final String comunidad;         // nombre_lugar_intervencion
  final String distrito;
  final String provincia;
  final String sexo;              // "M" | "F"
  final String celular;
  final String estado;            // "ALTA" | "BAJA"
  final String cultivo;           // cultivo_asistido
  final double totalHa;

  const SocioModel({
    required this.idSocio,
    required this.nombreCompleto,
    required this.dni,
    required this.comunidad,
    required this.distrito,
    required this.provincia,
    this.sexo      = '',
    this.celular   = '',
    this.estado    = 'ALTA',
    this.cultivo   = '',
    this.totalHa   = 0,
  });

  factory SocioModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return SocioModel(
      idSocio:        doc.id,
      nombreCompleto: (d['ap_nombres_t']              as String?) ?? '',
      dni:            (d['dni_t']                     as String?) ?? '',
      comunidad:      (d['nombre_lugar_intervencion'] as String?) ?? '',
      distrito:       (d['distrito']                  as String?) ?? '',
      provincia:      (d['provincia']                 as String?) ?? '',
      sexo:           (d['sexo_t']                    as String?) ?? '',
      celular:        (d['celular']                   as String?) ?? '',
      estado:         (d['estado']                    as String?) ?? 'ALTA',
      cultivo:        (d['cultivo_asistido']           as String?) ?? '',
      totalHa:        ((d['total_ha'] as num?)?.toDouble()) ?? 0,
    );
  }

  /// Referencia compacta para guardar en SQLite / Firestore
  Map<String, String> toRef() => {
        'id':     idSocio,
        'nombre': nombreCompleto,
        'dni':    dni,
      };

  /// Reconstruye un SocioModel mínimo desde una referencia guardada
  /// (solo id + nombre + dni — útil al editar una tarea ya guardada)
  factory SocioModel.fromRef(Map<String, dynamic> ref) => SocioModel(
        idSocio:        (ref['id']     as String?) ?? '',
        nombreCompleto: (ref['nombre'] as String?) ?? '',
        dni:            (ref['dni']    as String?) ?? '',
        comunidad: '', distrito: '', provincia: '',
        sexo: '', celular: '', estado: 'ALTA', cultivo: '', totalHa: 0,
      );

  @override
  String toString() => '$nombreCompleto ($dni)';
}
