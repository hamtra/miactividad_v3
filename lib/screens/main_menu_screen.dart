import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../providers/auth_provider.dart';
import '../models/usuario_model.dart';
import 'cafe/cafe_menu_screen.dart';
import 'perfil_screen.dart';
import 'admin/usuarios_screen.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionProvider>();
    final usuario = sesion.usuario;

    final categories = [
      _MenuCategory(
        label: 'CAFÉ',
        sub: '4Cafe',
        icon: Icons.eco,
        iconColor: AppColors.primary,
        route: const CafeMenuScreen(),
      ),
      _MenuCategory(
        label: 'CACAO',
        sub: 'Próximamente',
        icon: Icons.spa,
        iconColor: const Color(0xFF795548),
      ),
      _MenuCategory(
        label: 'APÍCOLA',
        sub: 'Próximamente',
        icon: Icons.hive,
        iconColor: const Color(0xFFFFA000),
      ),
      _MenuCategory(
        label: 'ASOCIATIVIDAD',
        sub: 'Próximamente',
        icon: Icons.people_alt,
        iconColor: const Color(0xFF1565C0),
      ),
      _MenuCategory(
        label: 'ALMACÉN',
        sub: 'Próximamente',
        icon: Icons.warehouse,
        iconColor: const Color(0xFF546E7A),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      // ── Drawer lateral ───────────────────────────────────────────────────
      drawer: _AppDrawer(usuario: usuario, esAdmin: sesion.esAdmin),
      appBar: AppBar(
        title: const Text('MiActividad',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // Acceso rápido al perfil desde la AppBar
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Mi perfil',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PerfilScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Bienvenida ──────────────────────────────────────────────────
          if (usuario != null)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.primary.withValues(alpha: 0.08),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          usuario.nombreCompleto,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                        ),
                        Text(
                          usuario.cargo,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  // Badge de rol
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: sesion.esAdmin
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.accentBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sesion.esAdmin
                            ? AppColors.primary
                            : AppColors.accentBlue,
                      ),
                    ),
                    child: Text(
                      usuario.rol,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: sesion.esAdmin
                              ? AppColors.primary
                              : AppColors.accentBlue),
                    ),
                  ),
                ],
              ),
            ),
          // ── Sección actividades ─────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Text('ACTIVIDADES',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8)),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: categories.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (ctx, i) =>
                  _CategoryCard(cat: categories[i]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Drawer lateral ────────────────────────────────────────────────────────────
class _AppDrawer extends StatelessWidget {
  final UsuarioModel? usuario;
  final bool esAdmin;
  const _AppDrawer({required this.usuario, required this.esAdmin});

  @override
  Widget build(BuildContext context) {
    final iniciales = usuario == null
        ? '?'
        : usuario!.nombreCompleto
            .split(' ')
            .where((p) => p.isNotEmpty)
            .take(2)
            .map((p) => p[0])
            .join()
            .toUpperCase();

    return Drawer(
      child: Column(
        children: [
          // ── Cabecera ────────────────────────────────────────────────────
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            accountName: Text(
              usuario?.nombreCompleto ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(usuario?.email ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                iniciales,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary),
              ),
            ),
          ),
          // ── Ítems de navegación ─────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Inicio'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Mi Perfil'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PerfilScreen()),
              );
            },
          ),
          // ── Solo visible para ADMINISTRADOR ─────────────────────────────
          if (esAdmin) ...[
            const Divider(),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'ADMINISTRACIÓN',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8),
              ),
            ),
            ListTile(
              leading:
                  const Icon(Icons.manage_accounts_outlined),
              title: const Text('Gestión de Usuarios'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const UsuariosScreen()),
                );
              },
            ),
          ],
          const Divider(),
          const Spacer(),
          // ── Cerrar sesión ────────────────────────────────────────────────
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red.shade400),
            title: Text('Cerrar sesión',
                style: TextStyle(color: Colors.red.shade600)),
            onTap: () => _confirmarLogout(context),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _confirmarLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que deseas salir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // cierra diálogo
              Navigator.pop(context); // cierra drawer
              // logout() + _AuthGate redirige automáticamente a LoginScreen
              await context.read<SesionProvider>().logout();
            },
            child: Text('Salir',
                style: TextStyle(color: Colors.red.shade600)),
          ),
        ],
      ),
    );
  }
}

// ── Modelos y widgets internos ────────────────────────────────────────────────
class _MenuCategory {
  final String label;
  final String sub;
  final IconData icon;
  final Color iconColor;
  final Widget? route;
  const _MenuCategory({
    required this.label,
    required this.sub,
    required this.icon,
    required this.iconColor,
    this.route,
  });
}

class _CategoryCard extends StatelessWidget {
  final _MenuCategory cat;
  const _CategoryCard({required this.cat});

  @override
  Widget build(BuildContext context) {
    final enabled = cat.route != null;
    return GestureDetector(
      onTap: () {
        if (enabled) {
          Navigator.push(
              context, MaterialPageRoute(builder: (_) => cat.route!));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${cat.label} — próximamente')));
        }
      },
      child: Opacity(
        opacity: enabled ? 1.0 : 0.55,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: cat.iconColor, width: 2.5),
                  color: cat.iconColor.withValues(alpha: 0.07),
                ),
                child: Icon(cat.icon, size: 36, color: cat.iconColor),
              ),
              const SizedBox(height: 10),
              Text(cat.label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(cat.sub,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
