import 'package:flutter/material.dart';

import 'executive_kpi_card.dart';

class DashboardKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? status;
  final VoidCallback? onTap;

  const DashboardKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ExecutiveKpiCard(
      title: title,
      value: value,
      subtitle: subtitle,
      icon: icon,
      color: color,
      status: status,
      onTap: onTap,
    );
  }
}
