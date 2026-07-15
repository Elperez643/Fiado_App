import 'package:flutter/material.dart';

enum DashboardNewsLevel { info, alert, critical, success }

class DashboardNewsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final DashboardNewsLevel level;
  final String? actionLabel;
  final VoidCallback? onAction;

  const DashboardNewsCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.level = DashboardNewsLevel.info,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      DashboardNewsLevel.info => const Color(0xFF2F6F88),
      DashboardNewsLevel.alert => const Color(0xFFB54708),
      DashboardNewsLevel.critical => const Color(0xFFB42318),
      DashboardNewsLevel.success => const Color(0xFF1F7A6B),
    };
    final background = switch (level) {
      DashboardNewsLevel.info => const Color(0xFFEAF4F8),
      DashboardNewsLevel.alert => const Color(0xFFFFF4DB),
      DashboardNewsLevel.critical => const Color(0xFFFDEAE5),
      DashboardNewsLevel.success => const Color(0xFFE7F3EF),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF17322C),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF66756D),
                    fontSize: 13,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text(actionLabel!),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: color,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
