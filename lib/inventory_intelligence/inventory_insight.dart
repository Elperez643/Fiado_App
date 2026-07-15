class InventoryInsight {
  static const String statusNormal = 'normal';
  static const String statusLowStock = 'bajo_stock';
  static const String statusOutOfStock = 'agotado';
  static const String statusOverStock = 'sobre_stock';
  static const String statusNoMovement = 'sin_movimiento';
  static const String statusCritical = 'critico';

  final String productId;
  final int? sqliteProductId;
  final int businessId;
  final String productName;
  final String? codeReference;
  final String? category;
  final String location;
  final int currentStock;
  final int minimumStock;
  final double unitCost;
  final double salePrice;
  final double profitMarginPercent;
  final double inventoryCostValue;
  final double inventorySaleValue;
  final double potentialProfit;
  final double averageDailyMovement;
  final double? coverageDays;
  final int recommendedRestockQuantity;
  final String status;
  final DateTime? lastMovementAt;
  final DateTime lastCalculatedAt;

  const InventoryInsight({
    required this.productId,
    required this.sqliteProductId,
    required this.businessId,
    required this.productName,
    this.codeReference,
    this.category,
    required this.location,
    required this.currentStock,
    required this.minimumStock,
    required this.unitCost,
    required this.salePrice,
    required this.profitMarginPercent,
    required this.inventoryCostValue,
    required this.inventorySaleValue,
    required this.potentialProfit,
    required this.averageDailyMovement,
    required this.coverageDays,
    required this.recommendedRestockQuantity,
    required this.status,
    required this.lastMovementAt,
    required this.lastCalculatedAt,
  });

  bool get isCritical =>
      status == statusCritical ||
      status == statusOutOfStock ||
      status == statusLowStock;
}

class InventoryIntelligenceSummary {
  final double totalCostValue;
  final double totalSaleValue;
  final double totalPotentialProfit;
  final int outOfStockCount;
  final int criticalCount;
  final int lowStockCount;
  final int totalRecommendedRestock;
  final int noMovementCount;
  final int overStockCount;

  const InventoryIntelligenceSummary({
    required this.totalCostValue,
    required this.totalSaleValue,
    required this.totalPotentialProfit,
    required this.outOfStockCount,
    required this.criticalCount,
    required this.lowStockCount,
    required this.totalRecommendedRestock,
    required this.noMovementCount,
    required this.overStockCount,
  });

  factory InventoryIntelligenceSummary.fromInsights(
    List<InventoryInsight> insights,
  ) {
    return InventoryIntelligenceSummary(
      totalCostValue: insights.fold(
        0,
        (sum, item) => sum + item.inventoryCostValue,
      ),
      totalSaleValue: insights.fold(
        0,
        (sum, item) => sum + item.inventorySaleValue,
      ),
      totalPotentialProfit: insights.fold(
        0,
        (sum, item) => sum + item.potentialProfit,
      ),
      outOfStockCount: insights
          .where((item) => item.status == InventoryInsight.statusOutOfStock)
          .length,
      criticalCount: insights
          .where((item) => item.status == InventoryInsight.statusCritical)
          .length,
      lowStockCount: insights
          .where((item) => item.status == InventoryInsight.statusLowStock)
          .length,
      totalRecommendedRestock: insights.fold(
        0,
        (sum, item) => sum + item.recommendedRestockQuantity,
      ),
      noMovementCount: insights
          .where((item) => item.status == InventoryInsight.statusNoMovement)
          .length,
      overStockCount: insights
          .where((item) => item.status == InventoryInsight.statusOverStock)
          .length,
    );
  }
}
