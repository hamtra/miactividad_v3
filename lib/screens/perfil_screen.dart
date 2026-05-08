import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/app_colors.dart';
import '../models/usuario_model.dart';
import '../providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PERFIL SCREEN
// Muestra los datos del usuario autenticado obtenidos de Firestore.
// Solo lectura (excepto celular, que el técnico puede actualizar).
// ─────────────────────────────────────────────────────────────────────────────
class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<SesionProvider>().usuario;

    if (usuario == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _AvatarHeader(usuario: usuario),
            const SizedBox(height: 24),
            _SeccionDatos(usuario: usuario),
            const SizedBox(height: 16),
            _SeccionLaboral(usuario: usuario),
            const SizedBox(height: 24),
            _BotonCerrarSesion(),
          ],
        ),
      ),
    );
  }
}

// ── Avatar + nombre ───────────────────────────────────────────────────────────
class _AvatarHeader extends StatelessWidget {
  final UsuarioModel usuario;
  const _AvatarHeader({required this.usuario});

  @override
  Widget build(BuildContext context) {
    final iniciales = usuario.nombreCompleto
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0])
        .join()
        .toUpperCase();

    return Column(
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: AppColors.primary,
          child: Text(
            iniciales,
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          usuario.nombreCompleto,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        _RolBadge(rol: usuario.rol),
      ],
    );
  }
}

class _RolBadge extends StatelessWidget {
  final String rol;
  const _RolBadge({required this.rol});

  @override
  Widget build(BuildContext context) {
    final esAdmin = rol.toUpperCase() == 'ADMINISTRADOR';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: esAdmin
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.accentBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: esAdmin ? AppColors.primary : AppColors.accentBlue,
          width: 1,
        ),
      ),
      child: Text(
        rol.isEmpty ? 'Sin rol' : rol,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: esAdmin ? AppColors.primary : AppColors.accentBlue,
        ),
      ),
    );
  }
}

// ── Datos personales ──────────────────────────────────────────────────────────
class _SeccionDatos extends StatelessWidget {
  final UsuarioModel usuario;
  const _SeccionDatos({required this.usuario});

  @override
  Widget build(BuildContext context) {
    final fechaFmt = DateFormat('dd/MM/yyyy').format(usuario.fechaNacimiento);

    return _Tarjeta(
      titulo: 'Datos Personales',
      icono: Icons.person_outline,
      children: [
        _Campo(label: 'DNI', valor: usuario.dni),
        _Campo(label: 'Nombre completo', valor: usuario.nombreCompleto),
        _Campo(
          label: 'Sexo',
          valor: usuario.sexo == 'H' ? 'Hombre' : usuario.sexo == 'M' ? 'Mujer' : usuario.sexo,
        ),
        _Campo(label: 'Fecha de nacimiento', valor: fechaFmt),
        _Campo(label: 'Correo electrónico', valor: usuario.email),
        _CampoCelularEditable(usuario: usuario),
      ],
    );
  }
}

// ── Datos laborales ───────────────────────────────────────────────────────────
class _SeccionLaboral extends StatelessWidget {
  final UsuarioModel usuario;
  const _SeccionLaboral({required this.usuario});

  @override
  Widget build(BuildContext context) {
    return _Tarjeta(
      titulo: 'Información Laboral',
      icono: Icons.work_outline,
      children: [
        _Campo(label: 'Cargo', valor: usuario.cargo),
        _Campo(label: 'Actividad', valor: usuario.actividad),
        _Campo(label: 'Rol', valor: usuario.rol),
        _Campo(
          label: 'Estado',
          valor: usuario.estado ? 'Activo' : 'Inactivo',
          color: usuario.estado ? Colors.green.shade700 : Colors.red.shade600,
        ),
        if (usuario.idSuperior.isNotEmpty)
          _Campo(label: 'Superior', valor: usuario.idSuperior),
      ],
    );
  }
}

// ── Campo de celular editable ─────────────────────────────────────────────────
class _CampoCelularEditable extends StatefulWidget {
  final UsuarioModel usuario;
  const _CampoCelularEditable({required this.usuario});
  @override
  State<_CampoCelularEditable> createState() => _CampoCelularEditableState();
}

class _CampoCelularEditableState extends State<_CampoCelularEditable> {
  bool _editando = false;
  late final TextEditingController _ctrl;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.usuario.celular);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() => _guardando = true);
    try {
      // Actualiza el campo celular en Firestore a través del provider
      final prov = context.read<SesionProvider>();
      await prov.actualizarCelular(_ctrl.text.trim());
      if (mounted) setState(() => _editando = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_editando) {
      return _Campo(
        label: 'Celular',
        valor: widget.usuario.celular,
        trailing: IconButton(
          icon: const Icon(Icons.edit, size: 18, color: AppColors.accentBlue),
          onPressed: () => setState(() => _editando = true),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _ctrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Celular',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _guardando
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: const Icon(Icons.check_circle,
                      color: Colors.green, size: 26),
                  onPressed: _guardar,
                ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.grey, size: 26),
            onPressed: () => setState(() {
              _ctrl.text = widget.usuario.celular;
              _editando = false;
            }),
          ),
        ],
      ),
    );
  }
}

// ── Botón cerrar sesión ───────────────────────────────────────────────────────
class _BotonCerrarSesion extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red.shade600,
          side: BorderSide(color: Colors.red.shade300),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: const Icon(Icons.logout),
        label: const Text('Cerrar sesión',
            style: TextStyle(fontWeight: FontWeight.w600)),
        onPressed: () async {
          final confirmar = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Cerrar sesión'),
              content:
                  const Text('¿Estás seguro de que deseas cerrar sesión?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Cerrar sesión',
                      style: TextStyle(color: Colors.red.shade600)),
                ),
              ],
            ),
          );
          if (confirmar == true && context.mounted) {
            // Volver al root antes del logout para que _AuthGate redirija limpiamente
            Navigator.of(context).popUntil((route) => route.isFirst);
            await context.read<SesionProvider>().logout();
          }
        },
      ),
    );
  }
}

// ── Widgets reutilizables ─────────────────────────────────────────────────────
class _Tarjeta extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final List<Widget> children;

  const _Tarjeta({
    required this.titulo,
    required this.icono,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.textPrimary),
              ),
            ],
          ),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  final String label;
  final String valor;
  final Color? color;
  final Widget? trailing;

  const _Campo({
    required this.label,
    required this.valor,
    this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              valor.isEmpty ? '—' : valor,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: color ?? AppColors.textPrimary),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
