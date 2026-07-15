class BusinessRecommendationType {
  static const collection = 'collection';
  static const inventory = 'inventory';
  static const promotion = 'promotion';
  static const credit = 'credit';
  static const audit = 'audit';
  static const authorization = 'authorization';
  static const subscription = 'subscription';
  static const general = 'general';
}

class BusinessRecommendationPriority {
  static const low = 'low';
  static const medium = 'medium';
  static const high = 'high';
  static const critical = 'critical';
}

class BusinessRecommendationRoute {
  static const client = 'client';
  static const inventory = 'inventory';
  static const collections = 'collections';
  static const campaign = 'campaign';
  static const audit = 'audit';
  static const authorization = 'authorization';
  static const subscription = 'subscription';
  static const score = 'score';
}

class BusinessRecommendation {
  final String id;
  final int businessId;
  final String type;
  final String priority;
  final String title;
  final String description;
  final String actionLabel;
  final String actionRoute;
  final int score;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isDismissed;

  const BusinessRecommendation({
    required this.id,
    required this.businessId,
    required this.type,
    required this.priority,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.actionRoute,
    required this.score,
    required this.createdAt,
    required this.expiresAt,
    this.isDismissed = false,
  });

  factory BusinessRecommendation.fromMap(Map<String, Object?> map) {
    return BusinessRecommendation(
      id: map['id'] as String,
      businessId: (map['business_id'] as num).toInt(),
      type: map['type'] as String,
      priority: map['priority'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      actionLabel: map['action_label'] as String,
      actionRoute: map['action_route'] as String,
      score: (map['score'] as num? ?? 0).toInt(),
      createdAt: DateTime.parse(map['created_at'] as String),
      expiresAt: DateTime.parse(map['expires_at'] as String),
      isDismissed: (map['dismissed'] as num? ?? 0).toInt() == 1,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'type': type,
      'priority': priority,
      'title': title,
      'description': description,
      'action_label': actionLabel,
      'action_route': actionRoute,
      'score': score.clamp(0, 100),
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'dismissed': isDismissed ? 1 : 0,
    };
  }
}

class BusinessCopilotSummary {
  final int criticalCount;
  final int collectionTodayCount;
  final int criticalProductCount;
  final int promotionCount;

  const BusinessCopilotSummary({
    required this.criticalCount,
    required this.collectionTodayCount,
    required this.criticalProductCount,
    required this.promotionCount,
  });

  factory BusinessCopilotSummary.fromRecommendations(
    List<BusinessRecommendation> recommendations,
  ) {
    return BusinessCopilotSummary(
      criticalCount: recommendations
          .where(
            (item) => item.priority == BusinessRecommendationPriority.critical,
          )
          .length,
      collectionTodayCount: recommendations
          .where((item) => item.type == BusinessRecommendationType.collection)
          .length,
      criticalProductCount: recommendations
          .where(
            (item) =>
                item.type == BusinessRecommendationType.inventory &&
                (item.priority == BusinessRecommendationPriority.critical ||
                    item.priority == BusinessRecommendationPriority.high),
          )
          .length,
      promotionCount: recommendations
          .where((item) => item.type == BusinessRecommendationType.promotion)
          .length,
    );
  }
}
