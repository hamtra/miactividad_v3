import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// USUARIO MODEL
// Colección Firestore: 'USUARIOS'  (mayúsculas, case-sensitive)
// ID de documento    : Firebase Auth UID  (uid)
// ─────────────────────────────────────────────────────────────────────────────
class UsuarioModel {
  final String uid;            // doc.id = Firebase Auth UID
  final String nombreCompleto;
  final String dni;
  final String sexo;           // "M" | "F" | "H" etc.
  final DateTime fechaNacimiento;
  final String rol;
  final String cargo;
  final String celular;
  final String email;
  final bool estado;           // true = activo
  final String idSuperior;
  final String firmaUrl;
  final String actividad;      // "CAFE" | "CACAO" | …

  // Campos opcionales heredados del modelo AppSheet
  final String idTecEspExt;
  final String idCargo;

  const UsuarioModel({
    required this.uid,
    required this.nombreCompleto,
    required this.dni,
    required this.sexo,
    required this.fechaNacimiento,
    required this.rol,
    required this.cargo,
    required this.celular,
    required this.email,
    required this.estado,
    required this.idSuperior,
    required this.firmaUrl,
    required this.actividad,
    this.idTecEspExt = '',
    this.idCargo = '',
  });

  // ── Construir desde DocumentSnapshot de Firestore ─────────────────────────
  // Usa operadores ?? en todos los campos para evitar null-check errors.
  factory UsuarioModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};

    // fechaNacimiento puede ser Timestamp o String — manejamos ambos casos
    DateTime parseFecha(dynamic v) {
      if (v == null) return DateTime(2000);
      if (v is Timestamp) return v.toDate();
      if (v is String && v.isNotEmpty) {
        return DateTime.tryParse(v) ?? DateTime(2000);
      }
      return DateTime(2000);
    }

    // estado puede ser bool o int (0/1) dependiendo de cómo se guardó
    bool parseEstado(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is int) return v != 0;
      return false;
    }

    return UsuarioModel(
      uid:             doc.id,
      nombreCompleto:  (d['nombreCompleto'] as String?) ?? '',
      dni:             (d['dni']            as String?) ?? '',
      sexo:            (d['sexo']           as String?) ?? '',
      fechaNacimiento: parseFecha(d['fechaNacimiento']),
      rol:             (d['rol']            as String?) ?? '',
      cargo:           (d['cargo']          as String?) ?? '',
      celular:         (d['celular']        as String?) ?? '',
      email:           (d['email']          as String?) ?? '',
      estado:          parseEstado(d['estado']),
      idSuperior:      (d['idSuperior']     as String?) ?? '',
      firmaUrl:        (d['firmaUrl']       as String?) ?? '',
      actividad:       (d['actividad']      as String?) ?? '',
      idTecEspExt:     (d['idTecEspExt']    as String?) ?? '',
      idCargo:         (d['idCargo']        as String?) ?? '',
    );
  }

  // ── Serializar para escribir en Firestore ─────────────────────────────────
  Map<String, dynamic> toFirestore() => {
        'nombreCompleto':  nombreCompleto,
        'dni':             dni,
        'sexo':            sexo,
        'fechaNacimiento': Timestamp.fromDate(fechaNacimiento),
        'rol':             rol,
        'cargo':           cargo,
        'celular':         celular,
        'email':           email,
        'estado':          estado,
        'idSuperior':      idSuperior,
        'firmaUrl':        firmaUrl,
        'actividad':       actividad,
        if (idTecEspExt.isNotEmpty) 'idTecEspExt': idTecEspExt,
        if (idCargo.isNotEmpty)     'idCargo':     idCargo,
      };

  // ── Copia con campos modificados ─────────────────────────────────────────
  UsuarioModel copyWith({
    String? nombreCompleto,
    String? dni,
    String? sexo,
    DateTime? fechaNacimiento,
    String? rol,
    String? cargo,
    String? celular,
    String? email,
    bool? estado,
    String? idSuperior,
    String? firmaUrl,
    String? actividad,
    String? idTecEspExt,
    String? idCargo,
  }) =>
      UsuarioModel(
        uid:             uid,
        nombreCompleto:  nombreCompleto  ?? this.nombreCompleto,
        dni:             dni             ?? this.dni,
        sexo:            sexo            ?? this.sexo,
        fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
        rol:             rol             ?? this.rol,
        cargo:           cargo           ?? this.cargo,
        celular:         celular         ?? this.celular,
        email:           email           ?? this.email,
        estado:          estado          ?? this.estado,
        idSuperior:      idSuperior      ?? this.idSuperior,
        firmaUrl:        firmaUrl        ?? this.firmaUrl,
        actividad:       actividad       ?? this.actividad,
        idTecEspExt:     idTecEspExt     ?? this.idTecEspExt,
        idCargo:         idCargo         ?? this.idCargo,
      );

  @override
  String toString() =>
      'UsuarioModel($uid | $nombreCompleto | $cargo | $actividad)';
}
