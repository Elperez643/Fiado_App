import 'package:sqflite/sqflite.dart';

import '../collections_intelligence/collection_insight.dart';
import '../collections_intelligence/collections_intelligence_service.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_schema.dart';
import '../core/utils/money_formatter.dart';
import '../data/models/auditoria_sqlite_model.dart';
import '../data/models/solicitud_autorizacion_sqlite_model.dart';
import '../inventory_intelligence/inventory_insight.dart';
import '../inventory_intelligence/inventory_intelligence_service.dart';
import 'business_recommendation.dart';

class BusinessCopilotService {
  final DatabaseHelper databaseHelper;
  final CollectionsIntelligenceService collectionsService;
  final InventoryIntelligenceService inventoryService;

  const BusinessCopilotService({
    required this.databaseHelper,
    required this.collectionsService,
    required this.inventoryService,
  });

  Future<List<BusinessRecommendation>> getRecommendations({
    required int businessId,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await _loadValidCache(businessId);
      if (cached.isNotEmpty) return cached;
    }
    final recommendations = await recalculateRecommendations(
      businessId: businessId,
    );
    return recommendations;
  }

  Future<List<BusinessRecommendation>> recalculateRecommendations({
    required int businessId,
  }) async {
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 18));
    final db = await databaseHelper.database;
    final collections = await collectionsService.calculateInsights(
      businessId: businessId,
    );
    final inventory = await inventoryService.calculateInsights(
      businessId: businessId,
    );

    final recommendations = <BusinessRecommendation>[
      ..._collectionRecommendations(collections, now, expiresAt),
      ..._creditRecommendations(collections, now, expiresAt),
      ..._inventoryRecommendations(inventory, now, expiresAt),
      ..._promotionRecommendations(inventory, now, expiresAt),
      ...await _operationRecommendations(db, businessId, now, expiresAt),
      ...await _subscriptionRecommendations(db, businessId, now, expiresAt),
      ..._generalRecommendations(
        collections,
        inventory,
        businessId,
        now,
        expiresAt,
      ),
    ]..sort((a, b) => b.score.compareTo(a.score));

    await db.transaction((txn) async {
      await txn.delete(
        DatabaseSchema.businessRecommendationsCacheTable,
        where: 'business_id = ?',
        whereArgs: [businessId],
      );
      final batch = txn.batch();
      for (final recommendation in recommendations.take(40)) {
        batch.insert(
          DatabaseSchema.businessRecommendationsCacheTable,
          recommendation.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });

    return _loadValidCache(businessId);
  }

  Future<void> dismissRecommendation(String id) async {
    final db = await databaseHelper.database;
    await db.update(
      DatabaseSchema.businessRecommendationsCacheTable,
      {'dismissed': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<BusinessRecommendation>> _loadValidCache(int businessId) async {
    final db = await databaseHelper.database;
    final now = DateTime.now().toIso8601String();
    final rows = await db.query(
      DatabaseSchema.businessRecommendationsCacheTable,
      where: 'business_id = ? AND dismissed = 0 AND expires_at > ?',
      whereArgs: [businessId, now],
      orderBy: 'score DESC, created_at DESC',
      limit: 40,
    );
    return rows.map(BusinessRecommendation.fromMap).toList();
  }

  List<BusinessRecommendation> _collectionRecommendations(
    List<CollectionInsight> collections,
    DateTime now,
    DateTime expiresAt,
  ) {
    return collectionsService
        .collectToday(collections)
        .take(6)
        .map(
          (item) => _recommendation(
            businessId: item.businessId,
            type: BusinessRecommendationType.collection,
            priority: _priorityFromCollection(item.priorityLevel),
            title: 'Debes cobrar hoy',
            description:
                '${item.clientName}: ${MoneyFormatter.formatCurrency(item.totalPendingAmount)}'
                '${item.daysOverdue == null ? '' : ' - ${item.daysOverdue} dias vencido'}.',
            actionLabel: 'Abrir cliente',
            actionRoute: BusinessRecommendationRoute.collections,
            score: item.priorityLevel == CollectionPriority.critical ? 96 : 84,
            createdAt: now,
            expiresAt: expiresAt,
            stableKey: 'collection-${item.clientId}',
          ),
        )
        .toList();
  }

  List<BusinessRecommendation> _creditRecommendations(
    List<CollectionInsight> collections,
    DateTime now,
    DateTime expiresAt,
  ) {
    return collections
        .where(
          (item) =>
              (item.clientScore ?? 100) < 40 ||
              item.collectionStatus == CollectionStatus.blocked60 ||
              item.collectionStatus == CollectionStatus.overdue45,
        )
        .take(6)
        .map(
          (item) => _recommendation(
            businessId: item.businessId,
            type: BusinessRecommendationType.credit,
            priority: item.collectionStatus == CollectionStatus.blocked60
                ? BusinessRecommendationPriority.critical
                : BusinessRecommendationPriority.high,
            title: 'No recomendamos fiar a este cliente',
            description:
                '${item.clientName}: score ${item.clientScore ?? 'sin datos'}, ${item.riskLevel ?? item.collectionStatus}.',
            actionLabel: 'Abrir cobranza',
            actionRoute: BusinessRecommendationRoute.collections,
            score: item.collectionStatus == CollectionStatus.blocked60
                ? 95
                : 88,
            createdAt: now,
            expiresAt: expiresAt,
            stableKey: 'credit-${item.clientId}',
          ),
        )
        .toList();
  }

  List<BusinessRecommendation> _inventoryRecommendations(
    List<InventoryInsight> inventory,
    DateTime now,
    DateTime expiresAt,
  ) {
    return inventory
        .where(
          (item) =>
              item.status == InventoryInsight.statusOutOfStock ||
              item.status == InventoryInsight.statusCritical ||
              item.status == InventoryInsight.statusLowStock ||
              (item.coverageDays != null && item.coverageDays! <= 3),
        )
        .take(8)
        .map(
          (item) => _recommendation(
            businessId: item.businessId,
            type: BusinessRecommendationType.inventory,
            priority: item.status == InventoryInsight.statusOutOfStock
                ? BusinessRecommendationPriority.critical
                : BusinessRecommendationPriority.high,
            title: 'Debes reabastecer',
            description:
                '${item.productName}: cobertura ${_coverage(item.coverageDays)}, reponer ${item.recommendedRestockQuantity} unidades.',
            actionLabel: 'Abrir inventario',
            actionRoute: BusinessRecommendationRoute.inventory,
            score: item.status == InventoryInsight.statusOutOfStock ? 90 : 82,
            createdAt: now,
            expiresAt: expiresAt,
            stableKey: 'inventory-${item.sqliteProductId ?? item.productId}',
          ),
        )
        .toList();
  }

  List<BusinessRecommendation> _promotionRecommendations(
    List<InventoryInsight> inventory,
    DateTime now,
    DateTime expiresAt,
  ) {
    final candidates = inventory.where((item) {
      final highStock = item.currentStock > item.minimumStock * 3;
      final lowRotation =
          item.status == InventoryInsight.statusNoMovement ||
          (item.averageDailyMovement > 0 &&
              item.coverageDays != null &&
              item.coverageDays! >= 60);
      final highProfit = item.potentialProfit >= 3000;
      return highStock && lowRotation && highProfit;
    }).toList()..sort((a, b) => b.potentialProfit.compareTo(a.potentialProfit));

    return candidates
        .take(5)
        .map(
          (item) => _recommendation(
            businessId: item.businessId,
            type: BusinessRecommendationType.promotion,
            priority: BusinessRecommendationPriority.medium,
            title: 'Promociona este producto',
            description:
                '${item.productName}: stock ${item.currentStock}, ganancia potencial ${MoneyFormatter.formatCurrency(item.potentialProfit)}.',
            actionLabel: 'Crear campana WhatsApp',
            actionRoute: BusinessRecommendationRoute.campaign,
            score: 45,
            createdAt: now,
            expiresAt: expiresAt,
            stableKey: 'promotion-${item.sqliteProductId ?? item.productId}',
          ),
        )
        .toList();
  }

  Future<List<BusinessRecommendation>> _operationRecommendations(
    Database db,
    int businessId,
    DateTime now,
    DateTime expiresAt,
  ) async {
    final recommendations = <BusinessRecommendation>[];
    final auditCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            '''
SELECT COUNT(*) FROM ${DatabaseSchema.auditoriasTable}
WHERE negocio_id = ? AND estado != ?
''',
            [businessId, AuditoriaSqliteModel.estadoFinalizada],
          ),
        ) ??
        0;
    if (auditCount > 0) {
      recommendations.add(
        _recommendation(
          businessId: businessId,
          type: BusinessRecommendationType.audit,
          priority: BusinessRecommendationPriority.medium,
          title: 'Tienes auditorias pendientes',
          description: '$auditCount auditorias esperan completar o revisar.',
          actionLabel: 'Abrir auditoria',
          actionRoute: BusinessRecommendationRoute.audit,
          score: 58 + auditCount.clamp(0, 10).toInt(),
          createdAt: now,
          expiresAt: expiresAt,
          stableKey: 'audit-pending',
        ),
      );
    }

    final authCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            '''
SELECT COUNT(*) FROM ${DatabaseSchema.solicitudesAutorizacionTable}
WHERE negocio_id = ? AND estado = ?
''',
            [businessId, SolicitudAutorizacionSqliteModel.estadoPendiente],
          ),
        ) ??
        0;
    if (authCount > 0) {
      recommendations.add(
        _recommendation(
          businessId: businessId,
          type: BusinessRecommendationType.authorization,
          priority: BusinessRecommendationPriority.medium,
          title: 'Tienes solicitudes pendientes',
          description:
              '$authCount solicitudes de colaboradores requieren decision.',
          actionLabel: 'Abrir solicitudes',
          actionRoute: BusinessRecommendationRoute.authorization,
          score: 60 + authCount.clamp(0, 15).toInt(),
          createdAt: now,
          expiresAt: expiresAt,
          stableKey: 'authorization-pending',
        ),
      );
    }

    return recommendations;
  }

  Future<List<BusinessRecommendation>> _subscriptionRecommendations(
    Database db,
    int businessId,
    DateTime now,
    DateTime expiresAt,
  ) async {
    final rows = await db.query(
      DatabaseSchema.subscriptionsTable,
      where: 'usuario_id = ?',
      whereArgs: [businessId],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return const <BusinessRecommendation>[];

    final row = rows.first;
    final status = row['status']?.toString() ?? 'trial';
    final trialEnds = DateTime.tryParse(row['trial_ends_at']?.toString() ?? '');
    final periodEnds = DateTime.tryParse(
      row['current_period_ends_at']?.toString() ?? '',
    );
    final recommendations = <BusinessRecommendation>[];

    if (status == 'trial' && trialEnds != null) {
      final days = trialEnds.difference(now).inDays;
      if (days >= 0 && days <= 5) {
        recommendations.add(
          _recommendation(
            businessId: businessId,
            type: BusinessRecommendationType.subscription,
            priority: days <= 2
                ? BusinessRecommendationPriority.high
                : BusinessRecommendationPriority.medium,
            title: 'Tu trial esta proximo a vencer',
            description:
                'Quedan $days dias de trial. Revisa tu plan para evitar interrupciones.',
            actionLabel: 'Abrir suscripcion',
            actionRoute: BusinessRecommendationRoute.subscription,
            score: days <= 2 ? 78 : 64,
            createdAt: now,
            expiresAt: expiresAt,
            stableKey: 'subscription-trial',
          ),
        );
      }
    }

    if (status == 'active' && periodEnds != null) {
      final days = periodEnds.difference(now).inDays;
      if (days >= 0 && days <= 7) {
        recommendations.add(
          _recommendation(
            businessId: businessId,
            type: BusinessRecommendationType.subscription,
            priority: BusinessRecommendationPriority.medium,
            title: 'Tu plan esta proximo a renovar',
            description: 'La renovacion estimada ocurre en $days dias.',
            actionLabel: 'Abrir suscripcion',
            actionRoute: BusinessRecommendationRoute.subscription,
            score: 55,
            createdAt: now,
            expiresAt: expiresAt,
            stableKey: 'subscription-renewal',
          ),
        );
      }
    }

    if (status == 'payment_failed' || status == 'expired') {
      recommendations.add(
        _recommendation(
          businessId: businessId,
          type: BusinessRecommendationType.subscription,
          priority: BusinessRecommendationPriority.critical,
          title: 'Revisa el estado de pago',
          description: 'La suscripcion esta en estado $status.',
          actionLabel: 'Abrir suscripcion',
          actionRoute: BusinessRecommendationRoute.subscription,
          score: 92,
          createdAt: now,
          expiresAt: expiresAt,
          stableKey: 'subscription-payment',
        ),
      );
    }

    return recommendations;
  }

  List<BusinessRecommendation> _generalRecommendations(
    List<CollectionInsight> collections,
    List<InventoryInsight> inventory,
    int businessId,
    DateTime now,
    DateTime expiresAt,
  ) {
    final summary = CollectionsIntelligenceSummary.fromInsights(collections);
    final inventorySummary = InventoryIntelligenceSummary.fromInsights(
      inventory,
    );
    final recommendations = <BusinessRecommendation>[];

    if (summary.suggestedRecoveryToday > 0) {
      recommendations.add(
        _recommendation(
          businessId: businessId,
          type: BusinessRecommendationType.general,
          priority: BusinessRecommendationPriority.high,
          title: 'Hoy tienes dinero por recuperar',
          description:
              'Fiado App recomienda dar seguimiento a ${MoneyFormatter.formatCurrency(summary.suggestedRecoveryToday)}.',
          actionLabel: 'Abrir cobranza',
          actionRoute: BusinessRecommendationRoute.collections,
          score: 76,
          createdAt: now,
          expiresAt: expiresAt,
          stableKey: 'general-recovery',
        ),
      );
    }
    if (summary.criticalPriorityCount > 0) {
      recommendations.add(
        _recommendation(
          businessId: businessId,
          type: BusinessRecommendationType.general,
          priority: BusinessRecommendationPriority.critical,
          title: 'Tienes clientes criticos',
          description:
              '${summary.criticalPriorityCount} clientes requieren atencion prioritaria.',
          actionLabel: 'Abrir cobranza',
          actionRoute: BusinessRecommendationRoute.collections,
          score: 86,
          createdAt: now,
          expiresAt: expiresAt,
          stableKey: 'general-critical-clients',
        ),
      );
    }
    if (inventorySummary.outOfStockCount > 0) {
      recommendations.add(
        _recommendation(
          businessId: businessId,
          type: BusinessRecommendationType.general,
          priority: BusinessRecommendationPriority.high,
          title: 'Tienes productos agotados',
          description:
              '${inventorySummary.outOfStockCount} productos no tienen stock disponible.',
          actionLabel: 'Abrir inventario',
          actionRoute: BusinessRecommendationRoute.inventory,
          score: 80,
          createdAt: now,
          expiresAt: expiresAt,
          stableKey: 'general-out-of-stock',
        ),
      );
    }

    return recommendations;
  }

  BusinessRecommendation _recommendation({
    required int businessId,
    required String type,
    required String priority,
    required String title,
    required String description,
    required String actionLabel,
    required String actionRoute,
    required int score,
    required DateTime createdAt,
    required DateTime expiresAt,
    required String stableKey,
  }) {
    return BusinessRecommendation(
      id: '$businessId-$stableKey',
      businessId: businessId,
      type: type,
      priority: priority,
      title: title,
      description: description,
      actionLabel: actionLabel,
      actionRoute: actionRoute,
      score: score,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }

  String _priorityFromCollection(String priority) {
    return switch (priority) {
      CollectionPriority.critical => BusinessRecommendationPriority.critical,
      CollectionPriority.high => BusinessRecommendationPriority.high,
      CollectionPriority.medium => BusinessRecommendationPriority.medium,
      _ => BusinessRecommendationPriority.low,
    };
  }

  String _coverage(double? value) {
    if (value == null) return 'sin datos';
    return '${value.toStringAsFixed(1)} dias';
  }
}
