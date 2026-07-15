import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/money_formatter.dart';
import '../data/models/producto_imagen_sqlite_model.dart';
import '../inventory_intelligence/inventory_insight.dart';
import '../presentation/providers/auth_providers.dart';
import '../presentation/providers/fiado_data_providers.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/dashboard_kpi_card.dart';
import '../widgets/dashboard_section_header.dart';
import '../widgets/product_image_thumbnail.dart';
import 'inventario_screen.dart';
import 'principal_screen.dart';

class InventoryIntelligenceScreen extends ConsumerStatefulWidget {
  const InventoryIntelligenceScreen({super.key});

  @override
  ConsumerState<InventoryIntelligenceScreen> createState() =>
      _InventoryIntelligenceScreenState();
}

class _InventoryIntelligenceScreenState
    extends ConsumerState<InventoryIntelligenceScreen> {
  Map<int, ProductoImagenSqliteModel> _imagesByProductId = const {};
  Set<int> _loadedProductIds = const {};
  bool _loadingImages = false;

  @override
  Widget build(BuildContext context) {
    final insightsAsync = ref.watch(inventoryInsightsProvider);
    final activeProductsAsync = ref.watch(inventoryActiveProductsCountProvider);
    final cachedMetricsAsync = ref.watch(inventoryCachedMetricsCountProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _goBack,
        ),
        title: const Text('Inventario inteligente'),
      ),
      body: SafeArea(
        child: insightsAsync.when(
          loading: () => const _InventoryStateCard(
            icon: Icons.auto_graph_rounded,
            title: 'Calculando metricas de inventario...',
            message:
                'Estamos preparando valores de costo, venta, cobertura y reposicion desde tus productos locales.',
          ),
          error: (error, _) {
            debugPrint('[inventory-intelligence] screen error: $error');
            return _InventoryStateCard(
              icon: Icons.error_outline_rounded,
              title: 'No pudimos cargar Inventario Inteligente.',
              message:
                  'Puedes reintentar el calculo. Tus productos no se borraron ni se modificaron.',
              primaryLabel: 'Reintentar',
              onPrimary: _retry,
              secondaryLabel: 'Volver',
              onSecondary: _goBack,
            );
          },
          data: (insights) {
            _scheduleImageLoad(insights);
            final dirtyCount =
                ref.watch(inventoryDirtyMetricsCountProvider).valueOrNull ?? 0;
            final activeProducts = activeProductsAsync.valueOrNull;
            final cachedMetrics = cachedMetricsAsync.valueOrNull;
            debugPrint(
              '[inventory-intelligence] screen businessId='
              '${ref.read(currentBusinessIdProvider)} activeProducts='
              '${activeProducts ?? -1} cachedMetrics=${cachedMetrics ?? -1} '
              'dirtyMetrics=$dirtyCount insights=${insights.length}',
            );
            if (insights.isEmpty) {
              return activeProductsAsync.when(
                loading: () => const _InventoryStateCard(
                  icon: Icons.auto_graph_rounded,
                  title: 'Revisando productos activos...',
                  message:
                      'Si ya tienes productos, Fiado App calculara las metricas iniciales automaticamente.',
                ),
                error: (error, _) => _InventoryStateCard(
                  icon: Icons.error_outline_rounded,
                  title: 'No pudimos revisar tus productos.',
                  message: '$error',
                  primaryLabel: 'Reintentar',
                  onPrimary: _retry,
                  secondaryLabel: 'Volver',
                  onSecondary: _goBack,
                ),
                data: (count) {
                  if (count == 0) {
                    return _InventoryStateCard(
                      icon: Icons.inventory_2_outlined,
                      title: 'Aun no tienes productos en inventario.',
                      message:
                          'Agrega tu primer articulo para calcular stock, valor de inventario y reposicion sugerida.',
                      primaryLabel: 'Agregar producto',
                      onPrimary: _openInventory,
                      secondaryLabel: 'Volver',
                      onSecondary: _goBack,
                    );
                  }
                  return _InventoryStateCard(
                    icon: Icons.auto_graph_rounded,
                    title: 'Tus productos aun no tienen metricas calculadas.',
                    message:
                        'Hay $count productos activos. Ejecuta el calculo inicial para llenar la cache local.',
                    primaryLabel: 'Calcular metricas',
                    onPrimary: () => _refreshMetrics(full: true),
                    secondaryLabel: 'Volver',
                    onSecondary: _goBack,
                  );
                },
              );
            }
            final summary = InventoryIntelligenceSummary.fromInsights(insights);
            final critical =
                ref.watch(inventoryCriticalProductsProvider).valueOrNull ??
                const <InventoryInsight>[];
            final restock =
                ref.watch(inventoryRestockSuggestionsProvider).valueOrNull ??
                const <InventoryInsight>[];
            final noMovement =
                ref.watch(inventoryNoMovementProvider).valueOrNull ??
                const <InventoryInsight>[];
            final outOfStock = insights
                .where(
                  (item) => item.status == InventoryInsight.statusOutOfStock,
                )
                .toList();
            final profit = [...insights]
              ..sort((a, b) => b.potentialProfit.compareTo(a.potentialProfit));
            final overStock = insights
                .where(
                  (item) => item.status == InventoryInsight.statusOverStock,
                )
                .toList();

            return LayoutBuilder(
              builder: (context, constraints) {
                final padding = AdaptiveLayout.horizontalPadding(
                  constraints.maxWidth,
                );
                final columns = constraints.maxWidth >= 1100
                    ? 4
                    : constraints.maxWidth >= 720
                    ? 3
                    : constraints.maxWidth >= 420
                    ? 2
                    : 1;
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(inventoryInsightsProvider);
                    await ref.read(inventoryInsightsProvider.future);
                  },
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(padding, 18, padding, 28),
                    child: AdaptiveWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DashboardSectionHeader(
                            title: 'Resumen inteligente',
                            subtitle: dirtyCount > 200
                                ? 'Actualizando metricas de inventario... $dirtyCount productos pendientes.'
                                : cachedMetrics == null
                                ? 'Calculo offline desde cache local.'
                                : 'Cache local: $cachedMetrics metricas. Productos activos: ${activeProducts ?? insights.length}.',
                            trailing: TextButton.icon(
                              onPressed: () => _refreshMetrics(full: true),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Actualizar metricas'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _KpiGrid(
                            columns: columns,
                            children: [
                              DashboardKpiCard(
                                title: 'Valor costo',
                                value: _money(summary.totalCostValue),
                                subtitle: 'Stock por costo unitario',
                                icon: Icons.savings_outlined,
                                color: const Color(0xFF1F7A6B),
                              ),
                              DashboardKpiCard(
                                title: 'Valor venta',
                                value: _money(summary.totalSaleValue),
                                subtitle: 'Stock por precio venta',
                                icon: Icons.sell_outlined,
                                color: const Color(0xFF2F6F88),
                              ),
                              DashboardKpiCard(
                                title: 'Ganancia potencial',
                                value: _money(summary.totalPotentialProfit),
                                subtitle: 'Venta menos costo',
                                icon: Icons.trending_up_rounded,
                                color: const Color(0xFF6D597A),
                              ),
                              DashboardKpiCard(
                                title: 'Agotados',
                                value: '${summary.outOfStockCount}',
                                subtitle: 'Stock en cero',
                                icon: Icons.remove_shopping_cart_outlined,
                                color: const Color(0xFFB42318),
                              ),
                              DashboardKpiCard(
                                title: 'Criticos',
                                value: '${summary.criticalCount}',
                                subtitle: 'Cobertura menor o igual a 3 dias',
                                icon: Icons.warning_amber_rounded,
                                color: const Color(0xFFB54708),
                              ),
                              DashboardKpiCard(
                                title: 'Stock bajo',
                                value: '${summary.lowStockCount}',
                                subtitle: 'Stock bajo minimo',
                                icon: Icons.inventory_2_outlined,
                                color: const Color(0xFFE7B04B),
                              ),
                              DashboardKpiCard(
                                title: 'Reposicion sugerida',
                                value: '${summary.totalRecommendedRestock}',
                                subtitle: 'Unidades para 15 dias',
                                icon: Icons.add_box_outlined,
                                color: const Color(0xFF1F7A6B),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _InsightSection(
                            title: 'Productos criticos',
                            insights: critical.take(8).toList(),
                            images: _imagesByProductId,
                          ),
                          _InsightSection(
                            title: 'Sugerencias de reposicion',
                            insights: restock.take(8).toList(),
                            images: _imagesByProductId,
                          ),
                          _InsightSection(
                            title: 'Sin movimiento',
                            insights: noMovement.take(8).toList(),
                            images: _imagesByProductId,
                          ),
                          _InsightSection(
                            title: 'Productos agotados',
                            insights: outOfStock.take(8).toList(),
                            images: _imagesByProductId,
                          ),
                          _InsightSection(
                            title: 'Mayor ganancia potencial',
                            insights: profit.take(8).toList(),
                            images: _imagesByProductId,
                          ),
                          _InsightSection(
                            title: 'Sobre stock',
                            insights: overStock.take(8).toList(),
                            images: _imagesByProductId,
                          ),
                        ],
                      ),
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

  void _scheduleImageLoad(List<InventoryInsight> insights) {
    final ids = insights
        .map((item) => item.sqliteProductId)
        .whereType<int>()
        .toSet();
    if (_loadingImages || _setsEqual(ids, _loadedProductIds)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadImages(ids);
    });
  }

  Future<void> _loadImages(Set<int> productIds) async {
    if (_loadingImages) return;
    final negocioId = ref.read(currentBusinessIdProvider);
    if (negocioId == null) return;
    setState(() => _loadingImages = true);
    try {
      final images = await ref
          .read(productoImagenRepositoryProvider)
          .obtenerPrimeraImagenPorProductos(
            productIds.toList(),
            negocioId: negocioId,
          );
      if (!mounted) return;
      setState(() {
        _imagesByProductId = images;
        _loadedProductIds = productIds;
      });
    } finally {
      if (mounted) setState(() => _loadingImages = false);
    }
  }

  bool _setsEqual(Set<int> a, Set<int> b) {
    if (a.length != b.length) return false;
    for (final item in a) {
      if (!b.contains(item)) return false;
    }
    return true;
  }

  Future<void> _refreshMetrics({required bool full}) async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Actualizando metricas de inventario...')),
    );
    try {
      if (full) {
        await ref
            .read(inventoryIntelligenceServiceProvider)
            .recalculateBusinessMetricsInBatches(businessId: businessId);
      } else {
        await ref
            .read(inventoryIntelligenceServiceProvider)
            .recalculateDirtyProducts(businessId: businessId);
      }
    } catch (error) {
      debugPrint('[inventory-intelligence] refresh error: $error');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudieron actualizar metricas: $error')),
      );
      return;
    }
    if (!mounted) return;
    ref.invalidate(inventoryInsightsProvider);
    ref.invalidate(inventoryDirtyMetricsCountProvider);
    ref.invalidate(inventoryActiveProductsCountProvider);
    ref.invalidate(inventoryCachedMetricsCountProvider);
  }

  void _retry() {
    ref.invalidate(inventoryInsightsProvider);
    ref.invalidate(inventoryDirtyMetricsCountProvider);
    ref.invalidate(inventoryActiveProductsCountProvider);
    ref.invalidate(inventoryCachedMetricsCountProvider);
  }

  void _openInventory() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const InventarioScreen()),
    );
  }

  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.maybePop();
      return;
    }
    navigator.pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const PrincipalScreen()),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final int columns;
  final List<Widget> children;

  const _KpiGrid({required this.columns, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children
              .map((child) => SizedBox(width: width, child: child))
              .toList(),
        );
      },
    );
  }
}

class _InventoryStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _InventoryStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFD9E8E3)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF6F2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(icon, color: const Color(0xFF1F7A6B), size: 30),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF17322C),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    height: 1.35,
                    color: Color(0xFF53635F),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (primaryLabel != null || secondaryLabel != null) ...[
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (secondaryLabel != null)
                        OutlinedButton(
                          onPressed: onSecondary,
                          child: Text(secondaryLabel!),
                        ),
                      if (primaryLabel != null)
                        FilledButton(
                          onPressed: onPrimary,
                          child: Text(primaryLabel!),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InsightSection extends StatelessWidget {
  final String title;
  final List<InventoryInsight> insights;
  final Map<int, ProductoImagenSqliteModel> images;

  const _InsightSection({
    required this.title,
    required this.insights,
    required this.images,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardSectionHeader(
            title: title,
            subtitle: insights.isEmpty
                ? 'Sin productos para esta categoria.'
                : '${insights.length} productos destacados.',
          ),
          const SizedBox(height: 10),
          if (insights.isEmpty)
            const _EmptyInsightCard()
          else
            ...insights.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _InsightCard(
                  insight: item,
                  image: images[item.sqliteProductId],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final InventoryInsight insight;
  final ProductoImagenSqliteModel? image;

  const _InsightCard({required this.insight, required this.image});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(insight.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.28)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductImageThumbnail(
            image: image,
            stockBajo: insight.currentStock <= insight.minimumStock,
            esClave: insight.status == InventoryInsight.statusCritical,
            size: 64,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        insight.productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: Color(0xFF17322C),
                        ),
                      ),
                    ),
                    _StatusChip(
                      label: _statusLabel(insight.status),
                      color: statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _MiniMetric(
                      icon: Icons.qr_code_2_rounded,
                      text: insight.codeReference ?? 'Sin codigo',
                    ),
                    _MiniMetric(
                      icon: Icons.place_outlined,
                      text: insight.location,
                    ),
                    _MiniMetric(
                      icon: Icons.inventory_2_outlined,
                      text: 'Stock ${insight.currentStock}',
                    ),
                    _MiniMetric(
                      icon: Icons.speed_rounded,
                      text:
                          'Prom. ${insight.averageDailyMovement.toStringAsFixed(2)}/dia',
                    ),
                    _MiniMetric(
                      icon: Icons.calendar_today_outlined,
                      text: insight.coverageDays == null
                          ? 'Sin ventas registradas todavia'
                          : '${insight.coverageDays!.toStringAsFixed(1)} dias',
                    ),
                    _MiniMetric(
                      icon: Icons.add_box_outlined,
                      text: 'Reponer ${insight.recommendedRestockQuantity}',
                    ),
                    _MiniMetric(
                      icon: Icons.trending_up_rounded,
                      text: _money(insight.potentialProfit),
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

class _MiniMetric extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniMetric({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF1F7A6B)),
            const SizedBox(width: 5),
            Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3C514B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _EmptyInsightCard extends StatelessWidget {
  const _EmptyInsightCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9E8E3)),
      ),
      child: const Text(
        'Sin datos relevantes por ahora.',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

String _money(num value) => MoneyFormatter.formatCurrency(value);

String _statusLabel(String status) {
  return switch (status) {
    InventoryInsight.statusOutOfStock => 'Agotado',
    InventoryInsight.statusCritical => 'Critico',
    InventoryInsight.statusLowStock => 'Bajo stock',
    InventoryInsight.statusNoMovement => 'Sin movimiento',
    InventoryInsight.statusOverStock => 'Sobre stock',
    _ => 'Normal',
  };
}

Color _statusColor(String status) {
  return switch (status) {
    InventoryInsight.statusOutOfStock => const Color(0xFFB42318),
    InventoryInsight.statusCritical => const Color(0xFFB54708),
    InventoryInsight.statusLowStock => const Color(0xFFE7B04B),
    InventoryInsight.statusNoMovement => const Color(0xFF6D597A),
    InventoryInsight.statusOverStock => const Color(0xFF2F6F88),
    _ => const Color(0xFF1F7A6B),
  };
}
