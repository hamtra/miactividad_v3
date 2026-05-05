import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../providers/auth_provider.dart';
import 'cafe/cafe_menu_screen.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthProvider>().usuario;

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
      appBar: AppBar(
        title: const Text('MiActividad',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (usuario != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  usuario.dni,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white70),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => _showUserDialog(context, usuario),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (usuario != null)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.primary.withOpacity(0.08),
              child: Text(
                usuario.nombreCompleto,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Text('ACTIVIDADES',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
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

  void _showUserDialog(BuildContext context, UsuarioSesion? usuario) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Usuario'),
        content: usuario == null
            ? const Text('Sin sesión')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(usuario.nombreCompleto,
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('DNI: ${usuario.dni}'),
                  Text('Cargo: ${usuario.cargo}'),
                ],
              ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar')),
        ],
      ),
    );
  }
}

class _MenuCategory {
  final String label;
  final String sub;
  final IconData icon;
  final Color iconColor;
  final Widget? route;
  const _MenuCategory(
      {required this.label,
      required this.sub,
      required this.icon,
      required this.iconColor,
      this.route});
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
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => cat.route!));
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
                  color: Colors.black.withOpacity(0.05),
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
                  color: cat.iconColor.withOpacity(0.07),
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
