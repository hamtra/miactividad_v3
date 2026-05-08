import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/app_colors.dart';
import '../../core/enums.dart';
import '../../models/usuario_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// USUARIOS SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class UsuariosScreen extends StatelessWidget {
  const UsuariosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionProvider>();
    if (!sesion.esAdmin) return _PantallaAccesoDenegado();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Gestión de Usuarios'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Colors.greenAccent, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text('En vivo',
                  style: TextStyle(fontSize: 12, color: Colors.white70)),
            ]),
          ),
        ],
      ),
      body: StreamBuilder<List<UsuarioModel>>(
        stream: AuthService().streamUsuarios(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.orange),
                  const SizedBox(height: 12),
                  Text('Error:\n${snapshot.error}',
                      textAlign: TextAlign.center),
                ]),
              ),
            );
          }
          final usuarios = snapshot.data ?? [];
          return Column(children: [
            _ResumenBanner(usuarios: usuarios),
            Expanded(
              child: usuarios.isEmpty
                  ? const Center(
                      child: Text('No hay usuarios registrados.',
                          style: TextStyle(color: AppColors.textSecondary)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                      itemCount: usuarios.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) =>
                          _UsuarioCard(usuario: usuarios[i]),
                    ),
            ),
          ]);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_outlined, color: Colors.white),
        label: const Text('Agregar',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => const _AgregarUsuarioSheet(),
        ),
      ),
    );
  }
}

class _PantallaAccesoDenegado extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Gestión de Usuarios')),
        body: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Acceso restringido',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Solo los administradores pueden ver esta pantalla.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary)),
          ]),
        ),
      );
}

// ── Banner de resumen ─────────────────────────────────────────────────────────
class _ResumenBanner extends StatelessWidget {
  final List<UsuarioModel> usuarios;
  const _ResumenBanner({required this.usuarios});

  @override
  Widget build(BuildContext context) {
    final total   = usuarios.length;
    final activos = usuarios.where((u) => u.estado).length;
    final admins  = usuarios
        .where((u) => u.rol.toUpperCase() == RolUsuario.administrador.valor)
        .length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.primary.withValues(alpha: 0.06),
      child: Row(children: [
        _Stat(label: 'Total',   valor: '$total',   color: AppColors.primary),
        _DivV(),
        _Stat(label: 'Activos', valor: '$activos', color: Colors.green.shade700),
        _DivV(),
        _Stat(label: 'Admins',  valor: '$admins',  color: AppColors.accentBlue),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, valor;
  final Color color;
  const _Stat({required this.label, required this.valor, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(valor,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ]),
      );
}

class _DivV extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 30, color: AppColors.border);
}

// ── Tarjeta de usuario ────────────────────────────────────────────────────────
class _UsuarioCard extends StatelessWidget {
  final UsuarioModel usuario;
  const _UsuarioCard({required this.usuario});

  @override
  Widget build(BuildContext context) {
    final iniciales = usuario.nombreCompleto
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0])
        .join()
        .toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: usuario.estado
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.15),
          child: Text(iniciales,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color:
                      usuario.estado ? AppColors.primary : Colors.grey)),
        ),
        title: Row(children: [
          Expanded(
            child: Text(usuario.nombreCompleto,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textPrimary)),
          ),
        ]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 2),
          Text(usuario.cargo,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Row(children: [
            _Chip(
              label: usuario.rol.isEmpty ? 'Sin rol' : usuario.rol,
              color: usuario.rol.toUpperCase() ==
                      RolUsuario.administrador.valor
                  ? AppColors.primary
                  : AppColors.accentBlue,
            ),
            const SizedBox(width: 6),
            _Chip(
              label: usuario.estado ? 'Activo' : 'Inactivo',
              color: usuario.estado
                  ? Colors.green.shade700
                  : Colors.red.shade400,
            ),
          ]),
        ]),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined,
              size: 20, color: AppColors.accentBlue),
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20))),
            builder: (_) => _EditarUsuarioSheet(usuario: usuario),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: color)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET: EDITAR USUARIO — edición completa de todos los campos
// ─────────────────────────────────────────────────────────────────────────────
class _EditarUsuarioSheet extends StatefulWidget {
  final UsuarioModel usuario;
  const _EditarUsuarioSheet({required this.usuario});
  @override
  State<_EditarUsuarioSheet> createState() => _EditarUsuarioSheetState();
}

class _EditarUsuarioSheetState extends State<_EditarUsuarioSheet> {
  final _formKey     = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _dniCtrl;
  late final TextEditingController _celularCtrl;

  late CargoUsuario  _cargo;
  late RolUsuario    _rol;
  late ActividadApp  _actividad;
  late String        _sexo;
  late bool          _estadoActivo;
  late DateTime      _fechaNacimiento;

  // ID Superior: guardamos uid del superior, mostramos nombreCompleto
  String  _idSuperior       = '';
  String  _nombreSuperior   = '';

  bool                _guardando         = false;
  bool                _eliminando        = false;
  bool                _cargandoUsuarios  = true;
  List<UsuarioModel>  _usuarios          = []; // todos menos el actual

  @override
  void initState() {
    super.initState();
    final u = widget.usuario;
    _nombreCtrl  = TextEditingController(text: u.nombreCompleto);
    _dniCtrl     = TextEditingController(text: u.dni);
    _celularCtrl = TextEditingController(text: u.celular);
    _cargo           = CargoUsuario.fromString(u.cargo);
    _rol             = RolUsuario.fromString(u.rol);
    _actividad       = ActividadApp.fromString(u.actividad);
    _sexo            = u.sexo.isEmpty ? 'H' : u.sexo;
    _estadoActivo    = u.estado;
    _fechaNacimiento = u.fechaNacimiento;
    _idSuperior      = u.idSuperior;
    _cargarUsuarios();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _dniCtrl.dispose();
    _celularCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarUsuarios() async {
    try {
      final todos = await AuthService().getUsuarios();
      // Excluir al usuario que se está editando
      final sinYo = todos.where((u) => u.uid != widget.usuario.uid).toList();
      // Resolver nombre del superior actual
      String nombreSup = '';
      if (_idSuperior.isNotEmpty) {
        final sup = sinYo.firstWhere(
          (u) => u.uid == _idSuperior,
          orElse: () => UsuarioModel(
            uid: '', nombreCompleto: _idSuperior,
            dni: '', celular: '', sexo: '', actividad: '',
            cargo: '', rol: '', idSuperior: '', estado: false,
            email: '', firmaUrl: '', fechaNacimiento: DateTime(2000),
          ),
        );
        nombreSup = sup.nombreCompleto;
      }
      if (mounted) {
        setState(() {
          _usuarios         = sinYo;
          _nombreSuperior   = nombreSup;
          _cargandoUsuarios = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoUsuarios = false);
    }
  }

  // ── Diálogo de confirmación ───────────────────────────────────────────────
  Future<bool?> _mostrarConfirmacion() => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Confirmar cambios'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_nombreCtrl.text,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _FilaConfirm('Cargo',       _cargo.valor),
              _FilaConfirm('Rol',         _rol.valor),
              _FilaConfirm('Actividad',   _actividad.valor),
              _FilaConfirm('Sexo',        _sexo == 'H' ? 'Hombre' : 'Mujer'),
              _FilaConfirm('Nacimiento',  DateFormat('dd/MM/yyyy').format(_fechaNacimiento)),
              _FilaConfirm('Celular',     _celularCtrl.text),
              _FilaConfirm('Superior',    _nombreSuperior.isEmpty ? '—' : _nombreSuperior),
              _FilaConfirm('Estado',      _estadoActivo ? 'Activo' : 'Inactivo'),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Guardar')),
          ],
        ),
      );

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final ok = await _mostrarConfirmacion();
    if (ok != true || !mounted) return;

    setState(() => _guardando = true);
    try {
      await AuthService().actualizarUsuario(widget.usuario.uid, {
        'nombreCompleto':  _nombreCtrl.text.trim().toUpperCase(),
        'dni':             _dniCtrl.text.trim(),
        'celular':         _celularCtrl.text.trim(),
        'sexo':            _sexo,
        'cargo':           _cargo.valor,
        'rol':             _rol.valor,
        'actividad':       _actividad.valor,
        'estado':          _estadoActivo,
        'idSuperior':      _idSuperior,
        'fechaNacimiento': Timestamp.fromDate(_fechaNacimiento),
        // uid NO se modifica
      });
      // El StreamBuilder en UsuariosScreen se refresca automáticamente
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '✅ ${_nombreCtrl.text.trim()} actualizado correctamente'),
          backgroundColor: Colors.green.shade700,
        ));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red.shade600));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('¿Eliminar a ${widget.usuario.nombreCompleto}?'),
          const SizedBox(height: 8),
          const Text(
            'Se eliminará su perfil de Firestore.\n'
            'La cuenta en Firebase Auth debe borrarse desde la consola.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Eliminar',
                  style: TextStyle(color: Colors.red.shade600))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _eliminando = true);
    try {
      await AuthService().eliminarUsuarioFirestore(widget.usuario.uid);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${widget.usuario.nombreCompleto} eliminado'),
          backgroundColor: Colors.orange.shade700,
        ));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade600));
    } finally {
      if (mounted) setState(() => _eliminando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Handle(),
              const SizedBox(height: 16),

              // ── Cabecera ─────────────────────────────────────────────
              Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.usuario.nombreCompleto,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(widget.usuario.email,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ]),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                  onPressed: _eliminando ? null : _eliminar,
                ),
              ]),
              const Divider(height: 24),

              // ── Nombre completo ──────────────────────────────────────
              const _Label('Nombre completo *'),
              TextFormField(
                controller: _nombreCtrl,
                textCapitalization: TextCapitalization.characters,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),

              // ── DNI + Sexo ───────────────────────────────────────────
              Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('DNI *'),
                        TextFormField(
                          controller: _dniCtrl,
                          keyboardType: TextInputType.number,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Requerido'
                                  : null,
                        ),
                      ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('Sexo'),
                        DropdownButtonFormField<String>(
                          value: _sexo,
                          decoration: const InputDecoration(isDense: true),
                          items: const [
                            DropdownMenuItem(
                                value: 'H', child: Text('Hombre')),
                            DropdownMenuItem(
                                value: 'M', child: Text('Mujer')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _sexo = v);
                          },
                        ),
                      ]),
                ),
              ]),
              const SizedBox(height: 12),

              // ── Fecha de nacimiento ──────────────────────────────────
              const SizedBox(height: 12),
              const _Label('Fecha de nacimiento *'),
              _DatePickerField(
                fecha: _fechaNacimiento,
                onChanged: (f) => setState(() => _fechaNacimiento = f),
              ),

              // ── Cargo (Enum) ─────────────────────────────────────────
              const _Label('Cargo *'),
              DropdownButtonFormField<CargoUsuario>(
                value: _cargo,
                decoration: const InputDecoration(isDense: true),
                isExpanded: true,
                items: CargoUsuario.values
                    .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.valor,
                            style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _cargo = v);
                },
              ),
              const SizedBox(height: 12),

              // ── Celular ──────────────────────────────────────────────
              const _Label('Celular'),
              TextFormField(
                controller: _celularCtrl,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),

              // ── ID Superior — selector con búsqueda ──────────────────
              const _Label('Superior jerárquico'),
              InkWell(
                onTap: _cargandoUsuarios
                    ? null
                    : () async {
                        final seleccionado =
                            await showDialog<UsuarioModel?>(
                          context: context,
                          builder: (_) => _DialogoBuscarSuperior(
                            usuarios: _usuarios,
                            seleccionActual: _idSuperior,
                          ),
                        );
                        if (seleccionado == null && mounted) {
                          // null = "Ninguno" seleccionado
                          setState(() {
                            _idSuperior     = '';
                            _nombreSuperior = '';
                          });
                        } else if (seleccionado != null && mounted) {
                          setState(() {
                            _idSuperior     = seleccionado.uid;
                            _nombreSuperior = seleccionado.nombreCompleto;
                          });
                        }
                      },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: Row(children: [
                    Expanded(
                      child: _cargandoUsuarios
                          ? const Row(children: [
                              SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                              SizedBox(width: 8),
                              Text('Cargando usuarios…',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13)),
                            ])
                          : Text(
                              _nombreSuperior.isEmpty
                                  ? '— Sin superior asignado —'
                                  : _nombreSuperior,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: _nombreSuperior.isEmpty
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary),
                            ),
                    ),
                    const Icon(Icons.arrow_drop_down,
                        color: AppColors.textSecondary),
                  ]),
                ),
              ),
              if (_idSuperior.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 4),
                  child: Text('ID: $_idSuperior',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary)),
                ),
              const SizedBox(height: 12),

              // ── Rol + Actividad ──────────────────────────────────────
              Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('Rol *'),
                        DropdownButtonFormField<RolUsuario>(
                          value: _rol,
                          decoration: const InputDecoration(isDense: true),
                          items: RolUsuario.values
                              .map((r) => DropdownMenuItem(
                                  value: r,
                                  child: Text(r.valor,
                                      style: const TextStyle(
                                          fontSize: 12))))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _rol = v);
                          },
                        ),
                      ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('Actividad'),
                        DropdownButtonFormField<ActividadApp>(
                          value: _actividad,
                          decoration: const InputDecoration(isDense: true),
                          items: ActividadApp.values
                              .map((a) => DropdownMenuItem(
                                  value: a,
                                  child: Text(a.valor,
                                      style: const TextStyle(
                                          fontSize: 12))))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _actividad = v);
                          },
                        ),
                      ]),
                ),
              ]),
              const SizedBox(height: 12),

              // ── Estado activo ────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Expanded(
                      child: Text('Estado activo',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13))),
                  Switch(
                    value: _estadoActivo,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => _estadoActivo = v),
                  ),
                ]),
              ),
              const SizedBox(height: 24),

              // ── Botón guardar ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _guardando ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  icon: _guardando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _guardando ? 'Guardando…' : 'Guardar cambios',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Fila de confirmación ──────────────────────────────────────────────────────
class _FilaConfirm extends StatelessWidget {
  final String campo, valor;
  const _FilaConfirm(this.campo, this.valor);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(
              width: 80,
              child: Text(campo,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary))),
          Expanded(
              child: Text(valor,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600))),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// DIÁLOGO: BUSCAR SUPERIOR — lista filtrable con búsqueda
// ─────────────────────────────────────────────────────────────────────────────
class _DialogoBuscarSuperior extends StatefulWidget {
  final List<UsuarioModel> usuarios;
  final String seleccionActual; // uid del superior
  const _DialogoBuscarSuperior({
    required this.usuarios,
    required this.seleccionActual,
  });
  @override
  State<_DialogoBuscarSuperior> createState() =>
      _DialogoBuscarSuperiorState();
}

class _DialogoBuscarSuperiorState extends State<_DialogoBuscarSuperior> {
  final _searchCtrl = TextEditingController();
  late List<UsuarioModel> _filtrados;

  @override
  void initState() {
    super.initState();
    _filtrados = widget.usuarios;
    _searchCtrl.addListener(_filtrar);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filtrar() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtrados = q.isEmpty
          ? widget.usuarios
          : widget.usuarios
              .where((u) =>
                  u.nombreCompleto.toLowerCase().contains(q))
              .toList();
    });
  }

  bool _esSeleccionado(UsuarioModel u) =>
      u.uid == widget.seleccionActual;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seleccionar Superior'),
      contentPadding:
          const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barra de búsqueda
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o ID…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Lista de usuarios
            SizedBox(
              height: 320,
              child: ListView.builder(
                itemCount: _filtrados.length + 1, // +1 para "Ninguno"
                itemBuilder: (ctx, i) {
                  // Primera opción: ninguno
                  if (i == 0) {
                    final esNinguno = widget.seleccionActual.isEmpty;
                    return ListTile(
                      dense: true,
                      title: const Text('— Sin superior asignado —',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic)),
                      selected: esNinguno,
                      selectedTileColor:
                          AppColors.primary.withValues(alpha: 0.08),
                      trailing: esNinguno
                          ? const Icon(Icons.check,
                              color: AppColors.primary, size: 18)
                          : null,
                      onTap: () => Navigator.pop(context, null),
                    );
                  }

                  final u = _filtrados[i - 1];
                  final seleccionado = _esSeleccionado(u);
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary
                          .withValues(alpha: 0.12),
                      child: Text(
                        u.nombreCompleto
                            .split(' ')
                            .where((p) => p.isNotEmpty)
                            .take(2)
                            .map((p) => p[0])
                            .join()
                            .toUpperCase(),
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary),
                      ),
                    ),
                    title: Text(u.nombreCompleto,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(
                      u.cargo,
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary),
                    ),
                    selected: seleccionado,
                    selectedTileColor:
                        AppColors.primary.withValues(alpha: 0.08),
                    trailing: seleccionado
                        ? const Icon(Icons.check,
                            color: AppColors.primary, size: 18)
                        : null,
                    onTap: () => Navigator.pop(context, u),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET: AGREGAR USUARIO
// ─────────────────────────────────────────────────────────────────────────────
class _AgregarUsuarioSheet extends StatefulWidget {
  const _AgregarUsuarioSheet();
  @override
  State<_AgregarUsuarioSheet> createState() => _AgregarUsuarioSheetState();
}

class _AgregarUsuarioSheetState extends State<_AgregarUsuarioSheet> {
  final _formKey      = GlobalKey<FormState>();
  final _nombreCtrl   = TextEditingController();
  final _dniCtrl      = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _celularCtrl  = TextEditingController();

  RolUsuario   _rol            = RolUsuario.usuario;
  CargoUsuario _cargo          = CargoUsuario.tecnicoDeCampo;
  ActividadApp _actividad      = ActividadApp.cafe;
  String       _sexo           = 'H';
  DateTime?    _fechaNacimiento;       // null hasta que el usuario elija

  // ID Superior
  String _idSuperior     = '';
  String _nombreSuperior = '';

  bool               _passwordVisible  = false;
  bool               _guardando        = false;
  bool               _cargandoUsuarios = true;
  List<UsuarioModel> _usuarios         = [];


  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _dniCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _celularCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    final usuarios = await AuthService().getUsuarios();
    if (!mounted) return;
    setState(() {
      _usuarios         = usuarios;
      _cargandoUsuarios = false;
    });
  }

  Future<void> _crear() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fechaNacimiento == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecciona la fecha de nacimiento'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    setState(() => _guardando = true);
    try {
      final datosParciales = UsuarioModel(
        uid:             '',
        nombreCompleto:  _nombreCtrl.text.trim().toUpperCase(),
        dni:             _dniCtrl.text.trim(),
        celular:         _celularCtrl.text.trim(),
        sexo:            _sexo,
        fechaNacimiento: _fechaNacimiento!,
        actividad:       _actividad.valor,
        cargo:           _cargo.valor,
        rol:             _rol.valor,
        idSuperior:      _idSuperior,
        estado:          true,
        email:           _emailCtrl.text.trim(),
        firmaUrl:        '',
      );
      final nuevo = await AuthService().crearUsuarioCompleto(
        email:          _emailCtrl.text.trim(),
        password:       _passwordCtrl.text,
        datosParciales: datosParciales,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '✅ ${nuevo.nombreCompleto} creado correctamente'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 4),
        ));
      }
    } on Exception catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade600,
        ));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Handle(),
              const SizedBox(height: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nuevo Usuario',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                  Text('Crea la cuenta de acceso y el perfil.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              const Divider(height: 24),

              const _Label('Nombre completo *'),
              TextFormField(
                controller: _nombreCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                    hintText: 'JUAN PEREZ LOPEZ'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),

              Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('DNI *'),
                        TextFormField(
                          controller: _dniCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              hintText: '12345678'),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Requerido'
                                  : null,
                        ),
                      ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('Sexo'),
                        DropdownButtonFormField<String>(
                          value: _sexo,
                          decoration:
                              const InputDecoration(isDense: true),
                          items: const [
                            DropdownMenuItem(
                                value: 'H', child: Text('Hombre')),
                            DropdownMenuItem(
                                value: 'M', child: Text('Mujer')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _sexo = v);
                          },
                        ),
                      ]),
                ),
              ]),
              const SizedBox(height: 12),

              // ── Fecha de nacimiento ──────────────────────────────────
              const SizedBox(height: 12),
              const _Label('Fecha de nacimiento *'),
              _DatePickerField(
                fecha: _fechaNacimiento,
                onChanged: (f) => setState(() => _fechaNacimiento = f),
              ),
              const SizedBox(height: 12),

              const _Label('Correo electrónico *'),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    hintText: 'usuario@gmail.com'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requerido';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                      .hasMatch(v.trim())) return 'Correo inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              const _Label('Contraseña temporal *'),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: !_passwordVisible,
                decoration: InputDecoration(
                  hintText: 'Mínimo 6 caracteres',
                  suffixIcon: IconButton(
                    icon: Icon(_passwordVisible
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => setState(
                        () => _passwordVisible = !_passwordVisible),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if (v.length < 6) return 'Mínimo 6 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              const _Label('Cargo *'),
              DropdownButtonFormField<CargoUsuario>(
                value: _cargo,
                decoration: const InputDecoration(isDense: true),
                isExpanded: true,
                items: CargoUsuario.values
                    .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.valor,
                            style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _cargo = v);
                },
              ),
              const SizedBox(height: 12),

              const _Label('Celular'),
              TextFormField(
                controller: _celularCtrl,
                keyboardType: TextInputType.phone,
                decoration:
                    const InputDecoration(hintText: '9XXXXXXXX'),
              ),
              const SizedBox(height: 12),

              // Superior jerárquico con selector
              const _Label('Superior jerárquico'),
              InkWell(
                onTap: _cargandoUsuarios
                    ? null
                    : () async {
                        final sel = await showDialog<UsuarioModel?>(
                          context: context,
                          builder: (_) => _DialogoBuscarSuperior(
                            usuarios: _usuarios,
                            seleccionActual: _idSuperior,
                          ),
                        );
                        if (!mounted) return;
                        if (sel == null) {
                          setState(() {
                            _idSuperior     = '';
                            _nombreSuperior = '';
                          });
                        } else {
                          setState(() {
                            _idSuperior = sel.uid;
                            _nombreSuperior = sel.nombreCompleto;
                          });
                        }
                      },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        _nombreSuperior.isEmpty
                            ? '— Sin superior asignado —'
                            : _nombreSuperior,
                        style: TextStyle(
                            fontSize: 13,
                            color: _nombreSuperior.isEmpty
                                ? AppColors.textSecondary
                                : AppColors.textPrimary),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down,
                        color: AppColors.textSecondary),
                  ]),
                ),
              ),
              const SizedBox(height: 12),

              Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('Rol *'),
                        DropdownButtonFormField<RolUsuario>(
                          value: _rol,
                          decoration:
                              const InputDecoration(isDense: true),
                          items: RolUsuario.values
                              .map((r) => DropdownMenuItem(
                                  value: r,
                                  child: Text(r.valor,
                                      style: const TextStyle(
                                          fontSize: 12))))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _rol = v);
                          },
                        ),
                      ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('Actividad'),
                        DropdownButtonFormField<ActividadApp>(
                          value: _actividad,
                          decoration:
                              const InputDecoration(isDense: true),
                          items: ActividadApp.values
                              .map((a) => DropdownMenuItem(
                                  value: a,
                                  child: Text(a.valor,
                                      style: const TextStyle(
                                          fontSize: 12))))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _actividad = v);
                          },
                        ),
                      ]),
                ),
              ]),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _guardando ? null : _crear,
                  style: ElevatedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14)),
                  icon: _guardando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.person_add_outlined),
                  label: Text(
                    _guardando ? 'Creando usuario…' : 'Crear usuario',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widgets reutilizables ─────────────────────────────────────────────────────
class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
        ),
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
      );
}

// ── Selector de fecha reutilizable ────────────────────────────────────────────
class _DatePickerField extends StatelessWidget {
  final DateTime? fecha;
  final ValueChanged<DateTime> onChanged;

  const _DatePickerField({required this.fecha, required this.onChanged});

  Future<void> _pick(BuildContext context) async {
    final initial = fecha ?? DateTime(1990);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      helpText: 'Fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final label = fecha == null
        ? 'Seleccionar fecha…'
        : DateFormat('dd/MM/yyyy').format(fecha!);
    final isEmpty = fecha == null;

    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(
            color: isEmpty ? Colors.orange.shade300 : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Row(children: [
          Icon(
            Icons.cake_outlined,
            size: 16,
            color: isEmpty ? Colors.orange.shade400 : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isEmpty ? Colors.orange.shade700 : AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Icon(Icons.edit_calendar_outlined,
              size: 16, color: AppColors.textSecondary),
        ]),
      ),
    );
  }
}
