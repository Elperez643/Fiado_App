import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_gradients.dart';

class AppNavigationItem {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool destructive;

  const AppNavigationItem({
    required this.label,
    required this.icon,
    this.onTap,
    this.destructive = false,
  });
}

class AppNavigationDrawer extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<AppNavigationItem> items;

  const AppNavigationDrawer({
    super.key,
    required this.title,
    required this.subtitle,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.scaffold,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppGradients.executive,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.dashboard_customize_outlined,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFDCE9E5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final color = item.destructive
                      ? AppColors.danger
                      : AppColors.textPrimary;
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: Icon(item.icon, color: color),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: item.onTap == null
                        ? null
                        : () {
                            Navigator.pop(context);
                            item.onTap!();
                          },
                  );
                },
                separatorBuilder: (context, index) => const SizedBox(height: 2),
                itemCount: items.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
