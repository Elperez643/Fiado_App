import 'package:flutter/foundation.dart';

import '../data/repositories/inventory_product_metrics_repository.dart';
import 'inventory_insight.dart';

class InventoryIntelligenceService {
  final InventoryProductMetricsRepository metricsRepository;

  InventoryIntelligenceService({
    InventoryProductMetricsRepository? metricsRepository,
  }) : metricsRepository =
           metricsRepository ?? InventoryProductMetricsRepository();

  Future<List<InventoryInsight>> calculateInsights({
    required int businessId,
    int batchSize = 200,
  }) async {
    final activeProducts = await metricsRepository.activeProductCount(
      businessId,
    );
    final cachedMetrics = await metricsRepository.metricsCount(businessId);
    final dirtyMetrics = await metricsRepository.dirtyCount(businessId);
    debugPrint(
      '[inventory-intelligence] businessId=$businessId '
      'activeProducts=$activeProducts cachedMetrics=$cachedMetrics '
      'dirtyMetrics=$dirtyMetrics',
    );

    if (activeProducts == 0) {
      return const <InventoryInsight>[];
    }

    if (cachedMetrics == 0 || cachedMetrics < activeProducts) {
      debugPrint(
        '[inventory-intelligence] recalculando cache inicial '
        'businessId=$businessId',
      );
      await metricsRepository.recalculateBusinessMetricsInBatches(
        negocioId: businessId,
        batchSize: batchSize,
      );
    } else if (dirtyMetrics > 0) {
      debugPrint(
        '[inventory-intelligence] recalculando dirty batch '
        'businessId=$businessId dirty=$dirtyMetrics',
      );
      await metricsRepository.recalculateDirtyProducts(
        negocioId: businessId,
        batchSize: batchSize,
      );
    }
    final insights = await metricsRepository.getMetricsByBusiness(businessId);
    debugPrint(
      '[inventory-intelligence] insights=${insights.length} '
      'businessId=$businessId',
    );
    return insights;
  }

  Future<List<InventoryInsight>> getCachedInsights({required int businessId}) {
    return metricsRepository.getMetricsByBusiness(businessId);
  }

  Future<int> recalculateDirtyProducts({
    required int businessId,
    int batchSize = 200,
  }) {
    return metricsRepository.recalculateDirtyProducts(
      negocioId: businessId,
      batchSize: batchSize,
    );
  }

  Future<int> recalculateBusinessMetricsInBatches({
    required int businessId,
    int batchSize = 200,
  }) {
    return metricsRepository.recalculateBusinessMetricsInBatches(
      negocioId: businessId,
      batchSize: batchSize,
    );
  }

  Future<void> markProductDirty({
    required int businessId,
    required int productId,
  }) {
    return metricsRepository.markProductDirty(
      negocioId: businessId,
      productoId: productId,
    );
  }

  Future<int> dirtyCount(int businessId) {
    return metricsRepository.dirtyCount(businessId);
  }

  Future<int> metricsCount(int businessId) {
    return metricsRepository.metricsCount(businessId);
  }

  Future<int> activeProductCount(int businessId) {
    return metricsRepository.activeProductCount(businessId);
  }

  List<InventoryInsight> criticalProducts(List<InventoryInsight> insights) {
    final result = insights.where((item) => item.isCritical).toList();
    result.sort((a, b) {
      final statusCompare = _statusPriority(
        a.status,
      ).compareTo(_statusPriority(b.status));
      if (statusCompare != 0) return statusCompare;
      return a.currentStock.compareTo(b.currentStock);
    });
    return result;
  }

  List<InventoryInsight> restockSuggestions(List<InventoryInsight> insights) {
    final result = insights
        .where((item) => item.recommendedRestockQuantity > 0)
        .toList();
    result.sort(
      (a, b) =>
          b.recommendedRestockQuantity.compareTo(a.recommendedRestockQuantity),
    );
    return result;
  }

  List<InventoryInsight> noMovementProducts(List<InventoryInsight> insights) {
    final result = insights
        .where((item) => item.status == InventoryInsight.statusNoMovement)
        .toList();
    result.sort((a, b) => b.inventoryCostValue.compareTo(a.inventoryCostValue));
    return result;
  }

  static int _statusPriority(String status) {
    return switch (status) {
      InventoryInsight.statusOutOfStock => 1,
      InventoryInsight.statusCritical => 2,
      InventoryInsight.statusLowStock => 3,
      InventoryInsight.statusNoMovement => 4,
      InventoryInsight.statusOverStock => 5,
      _ => 6,
    };
  }
}
