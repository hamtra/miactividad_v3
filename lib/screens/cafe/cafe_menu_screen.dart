import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import 'plan_trabajo_screen.dart';
import 'fat_screen.dart';

class CafeMenuScreen extends StatelessWidget {
  const CafeMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _CafeItem(
        label: 'PLAN DE TRABAJO',
        sub: 'Plan mensual de actividades',
        icon: Icons.assignment,
        route: const PlanTrabajoScreen(),
      ),
      _CafeItem(
        label: 'FAT',
        sub: 'Ficha de Asistencia Técnica',
        icon: Icons.people,
        route: const FatListScreen(),
      ),
      _CafeItem(
          label: 'TRAZABILIDAD',
          sub: 'Seguimiento de parcelas',
          icon: Icons.track_changes),
      _CafeItem(
          label: 'SUPERVISIÓN',
          sub: 'FAT Supervisión',
          icon: Icons.supervisor_account),
      _CafeItem(
          label: 'A7',
          sub: 'Prospección',
          icon: Icons.map_outlined),
      _CafeItem(label: 'FSAM', sub: 'Ficha SAM', icon: Icons.search),
      _CafeItem(
          label: 'SENASA',
          sub: 'Registro SENASA',
          icon: Icons.verified_outlined),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Text('Menú General',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
            Icon(Icons.chevron_right, size: 16, color: Colors.white54),
            Text('CAFÉ',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.05,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemBuilder: (ctx, i) => _CafeCard(item: items[i]),
      ),
    );
  }
}

class _CafeItem {
  final String label;
  final String sub;
  final IconData icon;
  final Widget? route;
  const _CafeItem(
      {required this.label,
      required this.sub,
      required this.icon,
      this.route});
}

class _CafeCard extends StatelessWidget {
  final _CafeItem item;
  const _CafeCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final enabled = item.route != null;
    return GestureDetector(
      onTap: () {
        if (enabled) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => item.route!));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${item.label} — próximamente')));
        }
      },
      child: Opacity(
        opacity: enabled ? 1.0 : 0.55,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
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
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.primary, width: 2.5),
                  color: AppColors.primary.withOpacity(0.07),
                ),
                child: Icon(item.icon,
                    size: 32, color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              Text(item.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(item.sub,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}
