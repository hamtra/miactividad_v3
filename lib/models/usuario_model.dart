import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// USUARIO MODEL
//
// Mapea la colección `usuarios` en Firestore.
//
// Campos en Firestore          │ Campo en Dart
// ─────────────────────────────┼─────────────────────────
// (doc.id)                     │ uid            — Firebase Auth UID
// uid_auth                     │ uidAuth        — UID de Firebase Auth (mismo valor)
// nombreCompleto               │ nombreCompleto
// dni                          │ dni
// celular                      │ celular
// sexo                         │ sexo           — "H" | "M"
// fechaNacimiento  (Timestamp) │ fechaNacimiento
// actividad                    │ actividad      — "CAFE" | "CACAO" …
// cargo                        │ cargo          — valor de CargoUsuario
// rol                          │ rol            — valor de RolUsuario
// idSuperior                   │ idSuperior     — uid del superior jerárquico
// estado           (bool)      │ estado
// email                        │ email
// firmaUrl                     │ firmaUrl
// fecha_creacion   (Timestamp) │ fechaCreacion  — nullable (docs antiguos)
// ─────────────────────────────────────────────────────────────────────────────
class UsuarioModel {
  /// ID del documento en Firestore = Firebase Auth UID.
  final String uid;

  /// UID de Firebase Auth (igual a uid).
  final String uidAuth;

  // ── Datos personales ──────────────────────────────────────────────────────
  final String nombreCompleto;
  final String dni;
  final String celular;
  final String sexo;            // "H" = Hombre | "M" = Mujer
  final DateTime fechaNacimiento;

  // ── Datos laborales ───────────────────────────────────────────────────────
  final String actividad;       // "CAFE" | "CACAO" | "APICOLA" …
  final String cargo;           // valor de CargoUsuario.valor
  final String rol;             // valor de RolUsuario.valor
  final String idSuperior;      // uid del superior jerárquico (vacío si no tiene)
  final bool estado;            // true = activo

  // ── Control ───────────────────────────────────────────────────────────────
  final String email;
  final String firmaUrl;
  final DateTime? fechaCreacion; // null en docs migrados sin este campo

  // ── Campos legacy AppSheet (usados en plan_trabajo y fat) ─────────────────
  final String idTecEspExt;
  final String idCargo;

  const UsuarioModel({
    required this.uid,
    this.uidAuth = '',
    required this.nombreCompleto,
    required this.dni,
    required this.celular,
    required this.sexo,
    required this.fechaNacimiento,
    required this.actividad,
    required this.cargo,
    required this.rol,
    required this.idSuperior,
    required this.estado,
    required this.email,
    required this.firmaUrl,
    this.fechaCreacion,
    this.idTecEspExt = '',
    this.idCargo = '',
  });

  // ── Helpers de parseo defensivo ───────────────────────────────────────────
  static DateTime _parseFecha(dynamic v) {
    if (v == null) return DateTime(2000);
    if (v is Timestamp) return v.toDate();
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v) ?? DateTime(2000);
    return DateTime(2000);
  }

  static bool _parseBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is int) return v != 0;
    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // fromFirestore
  // ─────────────────────────────────────────────────────────────────────────
  factory UsuarioModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};

    return UsuarioModel(
      uid:             doc.id,
      uidAuth:         (d['uid_auth']        as String?) ?? doc.id,
      nombreCompleto:  (d['nombreCompleto']  as String?) ?? '',
      dni:             (d['dni']             as String?) ?? '',
      celular:         (d['celular']         as String?) ?? '',
      sexo:            (d['sexo']            as String?) ?? '',
      fechaNacimiento: _parseFecha(d['fechaNacimiento']),
      actividad:       (d['actividad']       as String?) ?? '',
      cargo:           (d['cargo']           as String?) ?? '',
      rol:             (d['rol']             as String?) ?? '',
      idSuperior:      (d['idSuperior']      as String?) ?? '',
      estado:          _parseBool(d['estado']),
      email:           (d['email']           as String?) ?? '',
      firmaUrl:        (d['firmaUrl']        as String?) ?? '',
      fechaCreacion:   (d['fecha_creacion']  as Timestamp?)?.toDate(),
      idTecEspExt:     (d['idTecEspExt']     as String?) ?? '',
      idCargo:         (d['idCargo']         as String?) ?? '',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // toFirestore — no incluye fecha_creacion (se añade con serverTimestamp()
  // desde el servicio en el momento de creación).
  // ─────────────────────────────────────────────────────────────────────────
  Map<String, dynamic> toFirestore() {
    return {
      'uid_auth':        uidAuth,
      'nombreCompleto':  nombreCompleto,
      'dni':             dni,
      'celular':         celular,
      'sexo':            sexo,
      'fechaNacimiento': Timestamp.fromDate(fechaNacimiento),
      'actividad':       actividad,
      'cargo':           cargo,
      'rol':             rol,
      'idSuperior':      idSuperior,
      'estado':          estado,
      'email':           email,
      'firmaUrl':        firmaUrl,
      if (idTecEspExt.isNotEmpty) 'idTecEspExt': idTecEspExt,
      if (idCargo.isNotEmpty)     'idCargo':     idCargo,
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // copyWith
  // ─────────────────────────────────────────────────────────────────────────
  UsuarioModel copyWith({
    String? uidAuth,
    String? nombreCompleto,
    String? dni,
    String? celular,
    String? sexo,
    DateTime? fechaNacimiento,
    String? actividad,
    String? cargo,
    String? rol,
    String? idSuperior,
    bool? estado,
    String? email,
    String? firmaUrl,
    DateTime? fechaCreacion,
    String? idTecEspExt,
    String? idCargo,
  }) =>
      UsuarioModel(
        uid:             uid,
        uidAuth:         uidAuth         ?? this.uidAuth,
        nombreCompleto:  nombreCompleto  ?? this.nombreCompleto,
        dni:             dni             ?? this.dni,
        celular:         celular         ?? this.celular,
        sexo:            sexo            ?? this.sexo,
        fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
        actividad:       actividad       ?? this.actividad,
        cargo:           cargo           ?? this.cargo,
        rol:             rol             ?? this.rol,
        idSuperior:      idSuperior      ?? this.idSuperior,
        estado:          estado          ?? this.estado,
        email:           email           ?? this.email,
        firmaUrl:        firmaUrl        ?? this.firmaUrl,
        fechaCreacion:   fechaCreacion   ?? this.fechaCreacion,
        idTecEspExt:     idTecEspExt     ?? this.idTecEspExt,
        idCargo:         idCargo         ?? this.idCargo,
      );

  @override
  String toString() =>
      'UsuarioModel($uid | $nombreCompleto | $cargo | $rol)';
}
