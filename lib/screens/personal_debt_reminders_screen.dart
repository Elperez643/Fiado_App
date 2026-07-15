import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/money_formatter.dart';
import '../personal_debt_guidance/personal_debt_reminder.dart';
import '../presentation/providers/fiado_data_providers.dart';
import '../widgets/dashboard_kpi_card.dart';
import '../widgets/dashboard_section_header.dart';
import 'widgets/personal_debt_reminder_detail.dart';

class PersonalDebtRemindersScreen extends ConsumerWidget {
  const PersonalDebtRemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(personalDebtRemindersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recordatorios de pago')),
      body: SafeArea(
        child: reminders.when(
          data: (items) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(personalDebtRemindersProvider);
              await ref.read(personalDebtRemindersProvider.future);
            },
            child: _ReminderContent(items: items),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No se pudieron cargar recordatorios: $error'),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReminderContent extends StatelessWidget {
  final List<PersonalDebtReminder> items;

  const _ReminderContent({required this.items});

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(
      0,
      (sum, item) => sum + item.totalPendingAmount,
    );
    final nextDue = _nextDueDate(items);
    final priority = items.isEmpty ? 'Sin datos' : items.first.priorityLabel;

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 760 ? 28.0 : 16.0;
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        return ListView(
          padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 28),
          children: [
            const DashboardSectionHeader(
              title: 'Tus recordatorios',
              subtitle:
                  'Consejos privados basados solo en tus deudas visibles.',
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: columns == 1 ? 1.9 : 1.25,
              children: [
                DashboardKpiCard(
                  title: 'Total pendiente',
                  value: MoneyFormatter.formatCurrency(total),
                  subtitle: 'Suma agrupada por negocio',
                  icon: Icons.account_balance_wallet_outlined,
                  color: const Color(0xFF1F7A6B),
                ),
                DashboardKpiCard(
                  title: 'Negocios con saldo',
                  value: '${items.length}',
                  subtitle: 'Separados para tu privacidad',
                  icon: Icons.storefront_outlined,
                  color: const Color(0xFF2F6F88),
                ),
                DashboardKpiCard(
                  title: 'Proximo vencimiento',
                  value: nextDue,
                  subtitle: 'Fecha mas cercana',
                  icon: Icons.event_available_outlined,
                  color: const Color(0xFFB54708),
                ),
                DashboardKpiCard(
                  title: 'Prioridad mayor',
                  value: priority,
                  subtitle: 'Para ordenar tus pagos',
                  icon: Icons.flag_outlined,
                  color: _priorityColor(items.isEmpty ? null : items.first),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const DashboardSectionHeader(
              title: 'Por negocio',
              subtitle: 'Fiado App recomienda, no prohibe ni juzga.',
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const _EmptyReminderState()
            else
              for (final item in items) ...[
                _ReminderCard(reminder: item),
                const SizedBox(height: 12),
              ],
          ],
        );
      },
    );
  }

  String _nextDueDate(List<PersonalDebtReminder> items) {
    final dates = items.map((item) => item.nextDueDate).whereType<DateTime>();
    if (dates.isEmpty) return 'Sin datos';
    final next = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    return '${next.day}/${next.month}/${next.year}';
  }
}

class _ReminderCard extends ConsumerWidget {
  final PersonalDebtReminder reminder;

  const _ReminderCard({required this.reminder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD9E8E3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _statusColor(reminder).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  _statusIcon(reminder.status),
                  color: _statusColor(reminder),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF17322C),
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${MoneyFormatter.formatCurrency(reminder.totalPendingAmount)} pendiente',
                      style: const TextStyle(
                        color: Color(0xFF66756D),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _PriorityChip(reminder: reminder),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _InfoPill(
                icon: Icons.calendar_today_outlined,
                label: reminder.nextDueDate == null
                    ? 'Sin fecha'
                    : 'Vence ${_formatDate(reminder.nextDueDate!)}',
              ),
              _InfoPill(
                icon: Icons.timer_outlined,
                label: reminder.daysOverdue != null && reminder.daysOverdue! > 0
                    ? '${reminder.daysOverdue} dias vencido'
                    : '${reminder.daysToDue ?? 0} dias restantes',
              ),
              if (reminder.lastPaymentDate != null)
                _InfoPill(
                  icon: Icons.payments_outlined,
                  label:
                      'Ultimo pago ${_formatDate(reminder.lastPaymentDate!)}',
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            reminder.recommendation,
            style: const TextStyle(color: Color(0xFF17322C), height: 1.35),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _openDetail(context, ref, reminder),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Ver detalle'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    WidgetRef ref,
    PersonalDebtReminder reminder,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.86,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return FutureBuilder<PersonalDebtReminderDetailData>(
              future: ref
                  .read(personalDebtGuidanceServiceProvider)
                  .getReminderDetail(reminder),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No se pudo cargar el detalle: ${snapshot.error}',
                      ),
                    ),
                  );
                }
                return PersonalDebtReminderDetail(
                  data: snapshot.data!,
                  scrollController: controller,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final PersonalDebtReminder reminder;

  const _PriorityChip({required this.reminder});

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(reminder);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        reminder.priorityLabel,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF1F7A6B)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF47645B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReminderState extends StatelessWidget {
  const _EmptyReminderState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD9E8E3)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 46,
            color: Color(0xFF1F7A6B),
          ),
          SizedBox(height: 12),
          Text(
            'No tienes recordatorios pendientes',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF17322C),
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Cuando un negocio registre una deuda vinculada a tu telefono, veras consejos aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF66756D)),
          ),
        ],
      ),
    );
  }
}

Color _priorityColor(PersonalDebtReminder? reminder) {
  return switch (reminder?.priority) {
    PersonalDebtPriority.critica => const Color(0xFFB42318),
    PersonalDebtPriority.alta => const Color(0xFFB54708),
    PersonalDebtPriority.media => const Color(0xFF2F6F88),
    _ => const Color(0xFF1F7A6B),
  };
}

Color _statusColor(PersonalDebtReminder reminder) {
  return switch (reminder.status) {
    PersonalDebtStatus.bloqueado60 => const Color(0xFFB42318),
    PersonalDebtStatus.mora45 => const Color(0xFFB54708),
    PersonalDebtStatus.vencido30 => const Color(0xFFB54708),
    PersonalDebtStatus.porVencer => const Color(0xFF2F6F88),
    _ => const Color(0xFF1F7A6B),
  };
}

IconData _statusIcon(String status) {
  return switch (status) {
    PersonalDebtStatus.bloqueado60 => Icons.block_outlined,
    PersonalDebtStatus.mora45 => Icons.warning_amber_rounded,
    PersonalDebtStatus.vencido30 => Icons.schedule_outlined,
    PersonalDebtStatus.porVencer => Icons.event_available_outlined,
    _ => Icons.account_balance_wallet_outlined,
  };
}

String _formatDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}
