import 'package:flutter/material.dart';

import '../../core/utils/money_formatter.dart';
import '../../personal_debt_guidance/personal_debt_reminder.dart';

class PersonalDebtReminderDetail extends StatelessWidget {
  final PersonalDebtReminderDetailData data;
  final ScrollController? scrollController;

  const PersonalDebtReminderDetail({
    super.key,
    required this.data,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final reminder = data.reminder;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(18),
      children: [
        _DetailHeader(reminder: reminder),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Que hacer ahora',
          icon: Icons.task_alt_outlined,
          children: [
            for (final step in data.nextSteps)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: Color(0xFF1F7A6B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(step)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Consejo de historial',
          icon: Icons.insights_outlined,
          children: [Text(reminder.scoreImpactAdvice)],
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Movimientos recientes',
          icon: Icons.history_rounded,
          children: data.recentMovements.isEmpty
              ? const [Text('No hay movimientos recientes para este negocio.')]
              : data.recentMovements
                    .map((item) => _MovementRow(item: item))
                    .toList(),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Tus comprobantes',
          icon: Icons.receipt_long_outlined,
          children: data.receipts.isEmpty
              ? const [Text('No hay comprobantes visibles para este negocio.')]
              : data.receipts.map((item) => _ReceiptRow(item: item)).toList(),
        ),
      ],
    );
  }
}

class _DetailHeader extends StatelessWidget {
  final PersonalDebtReminder reminder;

  const _DetailHeader({required this.reminder});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF103D4A),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reminder.businessName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Pendiente: ${MoneyFormatter.formatCurrency(reminder.totalPendingAmount)}',
            style: const TextStyle(
              color: Color(0xFFDCE9E5),
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            reminder.recommendation,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD9E8E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF1F7A6B)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF17322C),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  final PersonalDebtMovementSummary item;

  const _MovementRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final isPayment = item.type == 'pago';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            isPayment ? Icons.payments_outlined : Icons.add_card_outlined,
            color: isPayment
                ? const Color(0xFF1F7A6B)
                : const Color(0xFFB54708),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${_formatDate(item.date)} - ${item.concept ?? item.type}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(MoneyFormatter.formatCurrency(item.amount)),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final PersonalDebtReceiptSummary item;

  const _ReceiptRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.receipt_outlined, color: Color(0xFF2F6F88)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${item.code} - ${_formatDate(item.date)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(MoneyFormatter.formatCurrency(item.total)),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}
