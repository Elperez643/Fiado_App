class CollectionStatus {
  static const upToDate = 'al_dia';
  static const dueSoon = 'vence_pronto';
  static const overdue30 = 'vencido_30';
  static const overdue45 = 'mora_45';
  static const blocked60 = 'bloqueado_60';
  static const pendingBalance = 'saldo_pendiente';
  static const noAction = 'sin_accion';
}

class CollectionPriority {
  static const low = 'baja';
  static const medium = 'media';
  static const high = 'alta';
  static const critical = 'critica';
}

class CollectionInsight {
  final int clientId;
  final int businessId;
  final String clientName;
  final String clientPhone;
  final double totalPendingAmount;
  final DateTime? oldestCycleStartDate;
  final DateTime? nextDueDate;
  final int? daysToDue;
  final int? daysOverdue;
  final String collectionStatus;
  final String priorityLevel;
  final String recommendedAction;
  final String suggestedMessage;
  final String? riskLevel;
  final int? clientScore;
  final DateTime? lastPaymentDate;
  final DateTime? lastCreditDate;
  final DateTime lastCalculatedAt;

  const CollectionInsight({
    required this.clientId,
    required this.businessId,
    required this.clientName,
    required this.clientPhone,
    required this.totalPendingAmount,
    required this.oldestCycleStartDate,
    required this.nextDueDate,
    required this.daysToDue,
    required this.daysOverdue,
    required this.collectionStatus,
    required this.priorityLevel,
    required this.recommendedAction,
    required this.suggestedMessage,
    required this.riskLevel,
    required this.clientScore,
    required this.lastPaymentDate,
    required this.lastCreditDate,
    required this.lastCalculatedAt,
  });
}

class CollectionsIntelligenceSummary {
  final double totalReceivable;
  final double criticalReceivable;
  final double suggestedRecoveryToday;
  final int dueSoonCount;
  final int overdue45Count;
  final int blocked60Count;
  final int collectTodayCount;
  final int lowPriorityCount;
  final int mediumPriorityCount;
  final int highPriorityCount;
  final int criticalPriorityCount;

  const CollectionsIntelligenceSummary({
    required this.totalReceivable,
    required this.criticalReceivable,
    required this.suggestedRecoveryToday,
    required this.dueSoonCount,
    required this.overdue45Count,
    required this.blocked60Count,
    required this.collectTodayCount,
    required this.lowPriorityCount,
    required this.mediumPriorityCount,
    required this.highPriorityCount,
    required this.criticalPriorityCount,
  });

  factory CollectionsIntelligenceSummary.fromInsights(
    List<CollectionInsight> insights,
  ) {
    final dueSoon = insights
        .where((item) => item.collectionStatus == CollectionStatus.dueSoon)
        .length;
    final overdue45 = insights
        .where((item) => item.collectionStatus == CollectionStatus.overdue45)
        .length;
    final blocked = insights
        .where((item) => item.collectionStatus == CollectionStatus.blocked60)
        .length;
    final collectToday = insights
        .where((item) => item.daysToDue != null && item.daysToDue! <= 0)
        .length;
    final critical = insights.where(
      (item) => item.priorityLevel == CollectionPriority.critical,
    );
    final high = insights.where(
      (item) => item.priorityLevel == CollectionPriority.high,
    );

    return CollectionsIntelligenceSummary(
      totalReceivable: insights.fold<double>(
        0,
        (sum, item) => sum + item.totalPendingAmount,
      ),
      criticalReceivable: critical.fold<double>(
        0,
        (sum, item) => sum + item.totalPendingAmount,
      ),
      suggestedRecoveryToday: [
        ...critical,
        ...high,
      ].fold<double>(0, (sum, item) => sum + item.totalPendingAmount),
      dueSoonCount: dueSoon,
      overdue45Count: overdue45,
      blocked60Count: blocked,
      collectTodayCount: collectToday,
      lowPriorityCount: insights
          .where((item) => item.priorityLevel == CollectionPriority.low)
          .length,
      mediumPriorityCount: insights
          .where((item) => item.priorityLevel == CollectionPriority.medium)
          .length,
      highPriorityCount: high.length,
      criticalPriorityCount: critical.length,
    );
  }
}
