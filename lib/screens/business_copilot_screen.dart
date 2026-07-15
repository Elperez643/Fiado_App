import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../business_copilot/business_recommendation.dart';
import '../presentation/providers/auth_providers.dart';
import '../presentation/providers/fiado_data_providers.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/dashboard_kpi_card.dart';
import '../widgets/dashboard_section_header.dart';
import 'auditoria_reportes_screen.dart';
import 'client_score_report_screen.dart';
import 'collections_intelligence_screen.dart';
import 'create_whatsapp_campaign_screen.dart';
import 'inventario_screen.dart';
import 'solicitudes_pendientes_screen.dart';
import 'subscription_screen.dart';

class BusinessCopilotScreen extends ConsumerStatefulWidget {
  const BusinessCopilotScreen({super.key});

  @override
  ConsumerState<BusinessCopilotScreen> createState() =>
      _BusinessCopilotScreenState();
}

class _BusinessCopilotScreenState extends ConsumerState<BusinessCopilotScreen> {
  String _selectedType = 'all';

  @override
  Widget build(BuildContext context) {
    final recommendationsAsync = ref.watch(businessRecommendationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Copilot'),
        actions: [
          IconButton(
            tooltip: 'Recalcular recomendaciones',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: recommendationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No se pudo cargar el centro inteligente: $error'),
            ),
          ),
          data: (recommendations) {
            final summary = BusinessCopilotSummary.fromRecommendations(
              recommendations,
            );
            final filtered = _filter(recommendations, _selectedType);

            return LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding = AdaptiveLayout.horizontalPadding(
                  constraints.maxWidth,
                );
                final columns = constraints.maxWidth >= 1000
                    ? 4
                    : constraints.maxWidth >= 680
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
                          title: 'Fiado App recomienda',
                          subtitle:
                              'Recomendaciones deterministicas y explicables con tus datos locales.',
                        ),
                        const SizedBox(height: 14),
                        _SummaryGrid(summary: summary, columns: columns),
                        const SizedBox(height: 22),
                        _TypeTabs(
                          selected: _selectedType,
                          onSelected: (type) =>
                              setState(() => _selectedType = type),
                        ),
                        const SizedBox(height: 18),
                        if (filtered.isEmpty)
                          const _EmptyRecommendations()
                        else
                          for (final recommendation in filtered) ...[
                            _RecommendationCard(
                              recommendation: recommendation,
                              onAction: () => _openRoute(recommendation),
                              onDismiss: () async {
                                await ref
                                    .read(businessCopilotProvider)
                                    .dismissRecommendation(recommendation.id);
                                ref.invalidate(businessRecommendationsProvider);
                              },
                            ),
                            const SizedBox(height: 10),
                          ],
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

  Future<void> _refresh() async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) return;
    await ref
        .read(businessCopilotProvider)
        .recalculateRecommendations(businessId: businessId);
    ref.invalidate(businessRecommendationsProvider);
  }

  List<BusinessRecommendation> _filter(
    List<BusinessRecommendation> recommendations,
    String type,
  ) {
    if (type == 'all') return recommendations;
    if (type == 'operations') {
      return recommendations
          .where(
            (item) =>
                item.type == BusinessRecommendationType.audit ||
                item.type == BusinessRecommendationType.authorization ||
                item.type == BusinessRecommendationType.subscription ||
                item.type == BusinessRecommendationType.general,
          )
          .toList();
    }
    if (type == 'clients') {
      return recommendations
          .where((item) => item.type == BusinessRecommendationType.credit)
          .toList();
    }
    return recommendations.where((item) => item.type == type).toList();
  }

  void _openRoute(BusinessRecommendation recommendation) {
    final screen = switch (recommendation.actionRoute) {
      BusinessRecommendationRoute.inventory => const InventarioScreen(),
      BusinessRecommendationRoute.collections =>
        const CollectionsIntelligenceScreen(),
      BusinessRecommendationRoute.campaign =>
        const CreateWhatsappCampaignScreen(),
      BusinessRecommendationRoute.audit => const AuditoriaReportesScreen(),
      BusinessRecommendationRoute.authorization =>
        const SolicitudesPendientesScreen(),
      BusinessRecommendationRoute.subscription => const SubscriptionScreen(),
      BusinessRecommendationRoute.score => const ClientScoreReportScreen(),
      _ => const CollectionsIntelligenceScreen(),
    };
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _SummaryGrid extends StatelessWidget {
  final BusinessCopilotSummary summary;
  final int columns;

  const _SummaryGrid({required this.summary, required this.columns});

  @override
  Widget build(BuildContext context) {
    final cards = [
      DashboardKpiCard(
        title: 'Criticas',
        value: '${summary.criticalCount}',
        subtitle: 'Requieren accion prioritaria',
        icon: Icons.priority_high_rounded,
        color: const Color(0xFFB42318),
      ),
      DashboardKpiCard(
        title: 'Cobranza hoy',
        value: '${summary.collectionTodayCount}',
        subtitle: 'Clientes para seguimiento',
        icon: Icons.today_outlined,
        color: const Color(0xFFB54708),
      ),
      DashboardKpiCard(
        title: 'Productos criticos',
        value: '${summary.criticalProductCount}',
        subtitle: 'Stock/cobertura sensible',
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFF2F6F88),
      ),
      DashboardKpiCard(
        title: 'Promociones',
        value: '${summary.promotionCount}',
        subtitle: 'Productos sugeridos',
        icon: Icons.campaign_outlined,
        color: const Color(0xFF1F7A6B),
      ),
    ];

    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: columns == 1 ? 1.9 : 1.25,
      children: cards,
    );
  }
}

class _TypeTabs extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _TypeTabs({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    const tabs = [
      ('all', 'Todo'),
      (BusinessRecommendationType.collection, 'Cobranza'),
      (BusinessRecommendationType.inventory, 'Inventario'),
      (BusinessRecommendationType.promotion, 'Promociones'),
      ('clients', 'Clientes'),
      ('operations', 'Operaciones'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in tabs) ...[
            ChoiceChip(
              label: Text(tab.$2),
              selected: selected == tab.$1,
              onSelected: (_) => onSelected(tab.$1),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final BusinessRecommendation recommendation;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  const _RecommendationCard({
    required this.recommendation,
    required this.onAction,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(recommendation.priority);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(_iconForType(recommendation.type), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Chip(
                      text: recommendation.priority.toUpperCase(),
                      color: color,
                    ),
                    _Chip(
                      text: 'Score ${recommendation.score}',
                      color: const Color(0xFF2F6F88),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  recommendation.title,
                  style: const TextStyle(
                    color: Color(0xFF17322C),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  recommendation.description,
                  style: const TextStyle(color: Color(0xFF66756D)),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: onAction,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(recommendation.actionLabel),
                    ),
                    TextButton.icon(
                      onPressed: onDismiss,
                      icon: const Icon(Icons.done_rounded),
                      label: const Text('Descartar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;

  const _Chip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyRecommendations extends StatelessWidget {
  const _EmptyRecommendations();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD9E8E3)),
      ),
      child: const Text(
        'No hay recomendaciones para esta seccion. Tu operacion se ve estable con los datos locales actuales.',
        style: TextStyle(color: Color(0xFF66756D), fontWeight: FontWeight.w700),
      ),
    );
  }
}

Color _priorityColor(String priority) {
  return switch (priority) {
    BusinessRecommendationPriority.critical => const Color(0xFFB42318),
    BusinessRecommendationPriority.high => const Color(0xFFB54708),
    BusinessRecommendationPriority.medium => const Color(0xFF2F6F88),
    _ => const Color(0xFF1F7A6B),
  };
}

IconData _iconForType(String type) {
  return switch (type) {
    BusinessRecommendationType.collection => Icons.request_quote_outlined,
    BusinessRecommendationType.inventory => Icons.inventory_2_outlined,
    BusinessRecommendationType.promotion => Icons.campaign_outlined,
    BusinessRecommendationType.credit => Icons.report_problem_outlined,
    BusinessRecommendationType.audit => Icons.assignment_turned_in_outlined,
    BusinessRecommendationType.authorization => Icons.fact_check_outlined,
    BusinessRecommendationType.subscription => Icons.workspace_premium_outlined,
    _ => Icons.lightbulb_outline_rounded,
  };
}
