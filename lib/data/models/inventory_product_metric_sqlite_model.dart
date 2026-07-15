import '../../inventory_intelligence/inventory_insight.dart';

class InventoryProductMetricSqliteModel {
  final int? id;
  final int negocioId;
  final int productoId;
  final String? productName;
  final String? codeReference;
  final String? category;
  final String? location;
  final int currentStock;
  final int minimumStock;
  final double unitCost;
  final double salePrice;
  final double profitMarginPercent;
  final double inventoryCostValue;
  final double inventorySaleValue;
  final double potentialProfit;
  final double soldQuantity30Days;
  final double averageDailyMovement;
  final double? coverageDays;
  final double recommendedRestockQuantity;
  final String status;
  final DateTime? lastMovementAt;
  final DateTime? lastCalculatedAt;
  final bool dirty;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const InventoryProductMetricSqliteModel({
    this.id,
    required this.negocioId,
    required this.productoId,
    this.productName,
    this.codeReference,
    this.category,
    this.location,
    this.currentStock = 0,
    this.minimumStock = 0,
    this.unitCost = 0,
    this.salePrice = 0,
    this.profitMarginPercent = 0,
    this.inventoryCostValue = 0,
    this.inventorySaleValue = 0,
    this.potentialProfit = 0,
    this.soldQuantity30Days = 0,
    this.averageDailyMovement = 0,
    this.coverageDays,
    this.recommendedRestockQuantity = 0,
    required this.status,
    this.lastMovementAt,
    this.lastCalculatedAt,
    this.dirty = true,
    this.createdAt,
    this.updatedAt,
  });

  factory InventoryProductMetricSqliteModel.fromMap(Map<String, Object?> map) {
    return InventoryProductMetricSqliteModel(
      id: (map['id'] as num?)?.toInt(),
      negocioId: (map['negocio_id'] as num).toInt(),
      productoId: (map['producto_id'] as num).toInt(),
      productName: map['product_name'] as String?,
      codeReference: map['code_reference'] as String?,
      category: map['category'] as String?,
      location: map['location'] as String?,
      currentStock: (map['current_stock'] as num? ?? 0).toInt(),
      minimumStock: (map['minimum_stock'] as num? ?? 0).toInt(),
      unitCost: (map['unit_cost'] as num? ?? 0).toDouble(),
      salePrice: (map['sale_price'] as num? ?? 0).toDouble(),
      profitMarginPercent: (map['profit_margin_percent'] as num? ?? 0)
          .toDouble(),
      inventoryCostValue: (map['inventory_cost_value'] as num? ?? 0).toDouble(),
      inventorySaleValue: (map['inventory_sale_value'] as num? ?? 0).toDouble(),
      potentialProfit: (map['potential_profit'] as num? ?? 0).toDouble(),
      soldQuantity30Days: (map['sold_quantity_30_days'] as num? ?? 0)
          .toDouble(),
      averageDailyMovement: (map['average_daily_movement'] as num? ?? 0)
          .toDouble(),
      coverageDays: (map['coverage_days'] as num?)?.toDouble(),
      recommendedRestockQuantity:
          (map['recommended_restock_quantity'] as num? ?? 0).toDouble(),
      status: map['status'] as String? ?? InventoryInsight.statusNormal,
      lastMovementAt: _date(map['last_movement_at']),
      lastCalculatedAt: _date(map['last_calculated_at']),
      dirty: (map['dirty'] as num? ?? 1).toInt() == 1,
      createdAt: _date(map['created_at']),
      updatedAt: _date(map['updated_at']),
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return {
      if (includeId) 'id': id,
      'negocio_id': negocioId,
      'producto_id': productoId,
      'product_name': productName,
      'code_reference': codeReference,
      'category': category,
      'location': location,
      'current_stock': currentStock,
      'minimum_stock': minimumStock,
      'unit_cost': unitCost,
      'sale_price': salePrice,
      'profit_margin_percent': profitMarginPercent,
      'inventory_cost_value': inventoryCostValue,
      'inventory_sale_value': inventorySaleValue,
      'potential_profit': potentialProfit,
      'sold_quantity_30_days': soldQuantity30Days,
      'average_daily_movement': averageDailyMovement,
      'coverage_days': coverageDays,
      'recommended_restock_quantity': recommendedRestockQuantity,
      'status': status,
      'last_movement_at': lastMovementAt?.toIso8601String(),
      'last_calculated_at': lastCalculatedAt?.toIso8601String(),
      'dirty': dirty ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  InventoryInsight toInsight({String? legacyProductId}) {
    return InventoryInsight(
      productId: legacyProductId ?? productoId.toString(),
      sqliteProductId: productoId,
      businessId: negocioId,
      productName: productName ?? 'Sin nombre',
      codeReference: codeReference,
      category: category,
      location: location ?? 'Sin ubicacion',
      currentStock: currentStock,
      minimumStock: minimumStock,
      unitCost: unitCost,
      salePrice: salePrice,
      profitMarginPercent: profitMarginPercent,
      inventoryCostValue: inventoryCostValue,
      inventorySaleValue: inventorySaleValue,
      potentialProfit: potentialProfit,
      averageDailyMovement: averageDailyMovement,
      coverageDays: coverageDays,
      recommendedRestockQuantity: recommendedRestockQuantity.round(),
      status: status,
      lastMovementAt: lastMovementAt,
      lastCalculatedAt: lastCalculatedAt ?? DateTime.now(),
    );
  }

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value as String);
  }
}
