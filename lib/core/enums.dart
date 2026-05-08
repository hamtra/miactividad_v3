// ─────────────────────────────────────────────────────────────────────────────
// ENUMS — Valores exactos que se guardan en Firestore (case-sensitive)
// ─────────────────────────────────────────────────────────────────────────────

/// Roles de usuario en la aplicación
enum RolUsuario {
  administrador('ADMINISTRADOR'),
  usuario('USUARIO');

  const RolUsuario(this.valor);

  /// Valor exacto guardado en Firestore
  final String valor;

  /// Convierte un String de Firestore al enum correspondiente.
  /// Si no coincide, retorna [RolUsuario.usuario] por defecto.
  static RolUsuario fromString(String s) {
    return RolUsuario.values.firstWhere(
      (r) => r.valor == s.trim().toUpperCase(),
      orElse: () => RolUsuario.usuario,
    );
  }
}

/// Cargos disponibles en la organización
enum CargoUsuario {
  tecnicoDeCampo('TECNICO DE CAMPO'),
  extensionista('EXTENSIONISTA'),
  coordinador('COORDINADOR'),
  supervisor('SUPERVISOR'),
  jefeZonal('JEFE ZONAL'),
  gestorDeInformacion('GESTOR DE INFORMACION'),
  especialista('ESPECIALISTA'),
  especialistaAmbiental('ESPECIALISTA AMBIENTAL'),
  especialistaEnPoscosecha('ESPECIALISTA EN POSCOSECHA');

  const CargoUsuario(this.valor);

  /// Valor exacto guardado en Firestore
  final String valor;

  /// Convierte un String de Firestore al enum correspondiente.
  /// Si no coincide, retorna [CargoUsuario.tecnicoDeCampo] por defecto.
  static CargoUsuario fromString(String s) {
    return CargoUsuario.values.firstWhere(
      (c) => c.valor == s.trim().toUpperCase(),
      orElse: () => CargoUsuario.tecnicoDeCampo,
    );
  }
}

/// Actividades productivas disponibles
enum ActividadApp {
  cafe('CAFE'),
  cacao('CACAO'),
  apicola('APICOLA'),
  asociatividad('ASOCIATIVIDAD');

  const ActividadApp(this.valor);
  final String valor;

  static ActividadApp fromString(String s) {
    return ActividadApp.values.firstWhere(
      (a) => a.valor == s.trim().toUpperCase(),
      orElse: () => ActividadApp.cafe,
    );
  }
}
