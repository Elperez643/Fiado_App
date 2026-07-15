import '../../core/constants/subscription_plans.dart';

class SubscriptionSqliteModel {
  static const statusTrial = 'trial';
  static const statusTrialActive = 'trial_active';
  static const statusPaymentMethodRequired = 'payment_method_required';
  static const statusPastDue = 'past_due';
  static const statusCanceled = 'canceled';
  static const statusExpired = 'expired';
  static const statusTrialLocalPendingValidation =
      'trial_local_pendiente_validacion';
  static const statusActive = 'active';

  final int? id;
  final int usuarioId;
  final String planId;
  final String planNombre;
  final double precioMensual;
  final int maxColaboradores;
  final String billingCycle;
  final int discountPercent;
  final double originalPrice;
  final double finalPrice;
  final String currencyCode;
  final String status;
  final DateTime trialStartedAt;
  final DateTime trialEndsAt;
  final DateTime? currentPeriodStartedAt;
  final DateTime? currentPeriodEndsAt;
  final String? paymentProvider;
  final String? providerSubscriptionId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncStatus;

  const SubscriptionSqliteModel({
    this.id,
    required this.usuarioId,
    required this.planId,
    required this.planNombre,
    required this.precioMensual,
    required this.maxColaboradores,
    this.billingCycle = BillingCycle.mensual,
    this.discountPercent = 0,
    double? originalPrice,
    double? finalPrice,
    this.currencyCode = SubscriptionPlans.currencyCode,
    this.status = statusTrial,
    required this.trialStartedAt,
    required this.trialEndsAt,
    this.currentPeriodStartedAt,
    this.currentPeriodEndsAt,
    this.paymentProvider,
    this.providerSubscriptionId,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 'pending',
  }) : originalPrice = originalPrice ?? precioMensual,
       finalPrice = finalPrice ?? precioMensual;

  factory SubscriptionSqliteModel.trialBasico({
    required int usuarioId,
    required DateTime now,
  }) {
    return SubscriptionSqliteModel.fromPlan(
      usuarioId: usuarioId,
      plan: SubscriptionPlans.basico,
      status: statusTrialLocalPendingValidation,
      now: now,
    );
  }

  factory SubscriptionSqliteModel.fromPlan({
    required int usuarioId,
    required SubscriptionPlan plan,
    required String status,
    required DateTime now,
    String billingCycle = BillingCycle.mensual,
  }) {
    final price = plan.priceFor(billingCycle);
    return SubscriptionSqliteModel(
      usuarioId: usuarioId,
      planId: plan.id,
      planNombre: plan.nombre,
      precioMensual: plan.precioMensual,
      maxColaboradores: plan.maxColaboradores,
      billingCycle: price.billingCycle,
      discountPercent: price.discountPercent,
      originalPrice: price.originalPrice,
      finalPrice: price.finalPrice,
      currencyCode: price.currencyCode,
      status: status,
      trialStartedAt: now,
      trialEndsAt: now.add(const Duration(days: 30)),
      createdAt: now,
      updatedAt: now,
    );
  }

  factory SubscriptionSqliteModel.fromMap(Map<String, Object?> map) {
    return SubscriptionSqliteModel(
      id: map['id'] as int?,
      usuarioId: map['usuario_id'] as int,
      planId: map['plan_id'] as String? ?? SubscriptionPlans.basico.id,
      planNombre:
          map['plan_nombre'] as String? ?? SubscriptionPlans.basico.nombre,
      precioMensual:
          (map['precio_mensual'] as num?)?.toDouble() ??
          SubscriptionPlans.basico.precioMensual,
      maxColaboradores:
          (map['max_colaboradores'] as num?)?.toInt() ??
          SubscriptionPlans.basico.maxColaboradores,
      billingCycle: map['billing_cycle'] as String? ?? BillingCycle.mensual,
      discountPercent: (map['discount_percent'] as num?)?.toInt() ?? 0,
      originalPrice:
          (map['original_price'] as num?)?.toDouble() ??
          ((map['precio_mensual'] as num?)?.toDouble() ??
              SubscriptionPlans.basico.precioMensual),
      finalPrice:
          (map['final_price'] as num?)?.toDouble() ??
          ((map['precio_mensual'] as num?)?.toDouble() ??
              SubscriptionPlans.basico.precioMensual),
      currencyCode:
          map['currency_code'] as String? ?? SubscriptionPlans.currencyCode,
      status: map['status'] as String? ?? statusTrial,
      trialStartedAt: DateTime.parse(map['trial_started_at'] as String),
      trialEndsAt: DateTime.parse(map['trial_ends_at'] as String),
      currentPeriodStartedAt: map['current_period_started_at'] == null
          ? null
          : DateTime.parse(map['current_period_started_at'] as String),
      currentPeriodEndsAt: map['current_period_ends_at'] == null
          ? null
          : DateTime.parse(map['current_period_ends_at'] as String),
      paymentProvider: map['payment_provider'] as String?,
      providerSubscriptionId: map['provider_subscription_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      syncStatus: map['sync_status'] as String? ?? 'pending',
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return {
      if (includeId) 'id': id,
      'usuario_id': usuarioId,
      'plan_id': planId,
      'plan_nombre': planNombre,
      'precio_mensual': precioMensual,
      'max_colaboradores': maxColaboradores,
      'billing_cycle': billingCycle,
      'discount_percent': discountPercent,
      'original_price': originalPrice,
      'final_price': finalPrice,
      'currency_code': currencyCode,
      'status': status,
      'trial_started_at': trialStartedAt.toIso8601String(),
      'trial_ends_at': trialEndsAt.toIso8601String(),
      'current_period_started_at': currentPeriodStartedAt?.toIso8601String(),
      'current_period_ends_at': currentPeriodEndsAt?.toIso8601String(),
      'payment_provider': paymentProvider,
      'provider_subscription_id': providerSubscriptionId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus,
    };
  }

  SubscriptionSqliteModel copyWith({
    int? id,
    int? usuarioId,
    String? planId,
    String? planNombre,
    double? precioMensual,
    int? maxColaboradores,
    String? billingCycle,
    int? discountPercent,
    double? originalPrice,
    double? finalPrice,
    String? currencyCode,
    String? status,
    DateTime? trialStartedAt,
    DateTime? trialEndsAt,
    DateTime? currentPeriodStartedAt,
    DateTime? currentPeriodEndsAt,
    String? paymentProvider,
    String? providerSubscriptionId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncStatus,
  }) {
    return SubscriptionSqliteModel(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      planId: planId ?? this.planId,
      planNombre: planNombre ?? this.planNombre,
      precioMensual: precioMensual ?? this.precioMensual,
      maxColaboradores: maxColaboradores ?? this.maxColaboradores,
      billingCycle: billingCycle ?? this.billingCycle,
      discountPercent: discountPercent ?? this.discountPercent,
      originalPrice: originalPrice ?? this.originalPrice,
      finalPrice: finalPrice ?? this.finalPrice,
      currencyCode: currencyCode ?? this.currencyCode,
      status: status ?? this.status,
      trialStartedAt: trialStartedAt ?? this.trialStartedAt,
      trialEndsAt: trialEndsAt ?? this.trialEndsAt,
      currentPeriodStartedAt:
          currentPeriodStartedAt ?? this.currentPeriodStartedAt,
      currentPeriodEndsAt: currentPeriodEndsAt ?? this.currentPeriodEndsAt,
      paymentProvider: paymentProvider ?? this.paymentProvider,
      providerSubscriptionId:
          providerSubscriptionId ?? this.providerSubscriptionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
