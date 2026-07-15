import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/money_formatter.dart';
import '../collections_intelligence/collection_insight.dart';
import '../models/cliente.dart';
import '../models/movimiento.dart';
import '../presentation/providers/fiado_data_providers.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/dashboard_kpi_card.dart';
import '../widgets/dashboard_section_header.dart';
import 'detalle_cliente_screen.dart';

class CollectionsIntelligenceScreen extends ConsumerWidget {
  const CollectionsIntelligenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(collectionInsightsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cobranza Inteligente')),
      body: SafeArea(
        child: insightsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No se pudo calcular cobranza: $error'),
            ),
          ),
          data: (insights) {
            final summary = CollectionsIntelligenceSummary.fromInsights(
              insights,
            );
            final service = ref.read(collectionsIntelligenceServiceProvider);
            final cobrarHoy = service.collectToday(insights);
            final vencenPronto = service.dueSoon(insights);
            final mora45 = service.overdue45(insights);
            final bloqueados60 = service.blocked60(insights);
            final alDia = service.upToDateWithBalance(insights);
            final sinAccion = service.noUrgentAction(insights);

            return LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding = AdaptiveLayout.horizontalPadding(
                  constraints.maxWidth,
                );
                final columns = constraints.maxWidth >= 1100
                    ? 3
                    : constraints.maxWidth >= 700
                    ? 2
                    : 1;

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    18,
                    horizontalPadding,
                    28,
                  ),
                  child: AdaptiveWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const DashboardSectionHeader(
                          title: 'Cartera de cobro',
                          subtitle:
                              'Prioriza a quien contactar segun ciclos 30/45/60 y score local.',
                        ),
                        const SizedBox(height: 14),
                        _SummaryGrid(columns: columns, summary: summary),
                        const SizedBox(height: 24),
                        _InsightSection(
                          title: 'Cobrar hoy',
                          subtitle: 'Clientes de prioridad alta o critica.',
                          insights: cobrarHoy,
                          emptyText: 'No hay cobros urgentes para hoy.',
                          ref: ref,
                        ),
                        _InsightSection(
                          title: 'Vencen pronto',
                          subtitle:
                              'Ciclos con fecha limite en 3 dias o menos.',
                          insights: vencenPronto,
                          emptyText: 'No hay clientes venciendo pronto.',
                          ref: ref,
                        ),
                        _InsightSection(
                          title: 'Mora 45',
                          subtitle: 'Clientes que requieren seguimiento firme.',
                          insights: mora45,
                          emptyText: 'No hay clientes en mora 45.',
                          ref: ref,
                        ),
                        _InsightSection(
                          title: 'Bloqueados 60',
                          subtitle: 'No fiar mas sin autorizacion.',
                          insights: bloqueados60,
                          emptyText: 'No hay clientes bloqueados.',
                          ref: ref,
                        ),
                        _InsightSection(
                          title: 'Clientes al dia con saldo',
                          subtitle:
                              'Saldo pendiente reciente o dentro de plazo.',
                          insights: alDia,
                          emptyText: 'No hay saldos al dia.',
                          ref: ref,
                        ),
                        _InsightSection(
                          title: 'Sin accion urgente',
                          subtitle: 'Seguimiento normal de cartera.',
                          insights: sinAccion,
                          emptyText: 'No hay elementos de baja prioridad.',
                          ref: ref,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final int columns;
  final CollectionsIntelligenceSummary summary;

  const _SummaryGrid({required this.columns, required this.summary});

  @override
  Widget build(BuildContext context) {
    final cards = [
      DashboardKpiCard(
        title: 'Total por cobrar',
        value: _money(summary.totalReceivable),
        subtitle: 'Saldo pendiente local',
        icon: Icons.account_balance_wallet_outlined,
        color: const Color(0xFF1F7A6B),
      ),
      DashboardKpiCard(
        title: 'Monto critico',
        value: _money(summary.criticalReceivable),
        subtitle: 'Prioridad critica',
        icon: Icons.priority_high_rounded,
        color: const Color(0xFFB42318),
      ),
      DashboardKpiCard(
        title: 'Vencen pronto',
        value: '${summary.dueSoonCount}',
        subtitle: 'Proximos 3 dias',
        icon: Icons.event_outlined,
        color: const Color(0xFFB54708),
      ),
      DashboardKpiCard(
        title: 'Mora 45',
        value: '${summary.overdue45Count}',
        subtitle: 'Seguimiento firme',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFB54708),
      ),
      DashboardKpiCard(
        title: 'Bloqueados',
        value: '${summary.blocked60Count}',
        subtitle: 'Ciclo 60 dias',
        icon: Icons.block_outlined,
        color: const Color(0xFFB42318),
      ),
      DashboardKpiCard(
        title: 'Recuperacion sugerida',
        value: _money(summary.suggestedRecoveryToday),
        subtitle: 'Alta + critica',
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF2F6F88),
      ),
    ];

    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: columns == 1 ? 1.85 : 1.35,
      children: cards,
    );
  }
}

class _InsightSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<CollectionInsight> insights;
  final String emptyText;
  final WidgetRef ref;

  const _InsightSection({
    required this.title,
    required this.subtitle,
    required this.insights,
    required this.emptyText,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardSectionHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 12),
          if (insights.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFD9E8E3)),
              ),
              child: Text(
                emptyText,
                style: const TextStyle(
                  color: Color(0xFF66756D),
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            for (final insight in insights.take(8)) ...[
              _CollectionInsightCard(insight: insight, ref: ref),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _CollectionInsightCard extends StatelessWidget {
  final CollectionInsight insight;
  final WidgetRef ref;

  const _CollectionInsightCard({required this.insight, required this.ref});

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(insight.priorityLevel);
    final fallbackCliente = Cliente(
      id: insight.clientId,
      nombre: insight.clientName,
      telefono: insight.clientPhone,
      deuda: insight.totalPendingAmount,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.person_search_outlined, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insight.clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF17322C),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      insight.clientPhone.isEmpty
                          ? 'Sin telefono'
                          : insight.clientPhone,
                      style: const TextStyle(color: Color(0xFF66756D)),
                    ),
                  ],
                ),
              ),
              _PriorityChip(priority: insight.priorityLevel, color: color),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MiniMetric(
                label: 'Pendiente',
                value: _money(insight.totalPendingAmount),
              ),
              _MiniMetric(
                label: 'Fecha limite',
                value: _date(insight.nextDueDate),
              ),
              _MiniMetric(label: 'Dias', value: _daysLabel(insight)),
              _MiniMetric(
                label: 'Score',
                value: insight.clientScore == null
                    ? 'Sin datos'
                    : '${insight.clientScore} - ${insight.riskLevel ?? ''}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insight.recommendedAction,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  final movimientos =
                      ref.read(movimientosProvider).valueOrNull ??
                      const <Movimiento>[];
                  final clientes =
                      ref.read(clientesProvider).valueOrNull?.clientes ??
                      <Cliente>[fallbackCliente];
                  var cliente = fallbackCliente;
                  for (final item in clientes) {
                    if (item.id == insight.clientId) {
                      cliente = item;
                      break;
                    }
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetalleClienteScreen(
                        cliente: cliente,
                        historial: movimientos,
                        clientes: clientes,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Ver cliente'),
              ),
              FilledButton.icon(
                onPressed: insight.clientPhone.trim().isEmpty
                    ? null
                    : () async {
                        final result = await ref
                            .read(collectionMessageServiceProvider)
                            .openWhatsAppMessage(insight);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              result.opened
                                  ? 'WhatsApp abierto con mensaje preparado.'
                                  : 'No se pudo abrir WhatsApp. Mensaje copiado.',
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Mensaje WhatsApp'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final String priority;
  final Color color;

  const _PriorityChip({required this.priority, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;

  const _MiniMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FAF8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF66756D), fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF17322C),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

Color _priorityColor(String priority) {
  return switch (priority) {
    CollectionPriority.critical => const Color(0xFFB42318),
    CollectionPriority.high => const Color(0xFFB54708),
    CollectionPriority.medium => const Color(0xFF2F6F88),
    _ => const Color(0xFF1F7A6B),
  };
}

String _money(num value) => MoneyFormatter.formatCurrency(value);

String _date(DateTime? value) {
  if (value == null) return 'Sin datos';
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String _daysLabel(CollectionInsight insight) {
  if (insight.daysOverdue != null) {
    return '${insight.daysOverdue} vencidos';
  }
  if (insight.daysToDue == null) return 'Sin datos';
  if (insight.daysToDue == 0) return 'Vence hoy';
  return '${insight.daysToDue} restantes';
}
