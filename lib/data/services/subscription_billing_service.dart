import '../../core/constants/subscription_plans.dart';
import '../models/payment_method_model.dart';
import '../models/subscription_sqlite_model.dart';
import 'payment_service.dart';

class SubscriptionBillingSnapshot {
  final String plan;
  final String billingCycle;
  final String status;
  final double amountUsd;
  final double amountDop;
  final double exchangeRate;
  final int trialDaysLeft;
  final DateTime? nextRenewalAt;
  final PaymentMethodModel? defaultPaymentMethod;
  final bool remote;

  const SubscriptionBillingSnapshot({
    required this.plan,
    required this.billingCycle,
    required this.status,
    required this.amountUsd,
    required this.amountDop,
    required this.exchangeRate,
    required this.trialDaysLeft,
    required this.nextRenewalAt,
    required this.defaultPaymentMethod,
    required this.remote,
  });

  factory SubscriptionBillingSnapshot.local({
    required SubscriptionSqliteModel? subscription,
    required int trialDaysLeft,
  }) {
    final usd = subscription?.finalPrice ?? 0;
    const rate = 59.25;
    return SubscriptionBillingSnapshot(
      plan: subscription?.planNombre ?? SubscriptionPlans.basico.nombre,
      billingCycle: subscription?.billingCycle ?? BillingCycle.mensual,
      status: subscription?.status ?? 'trial',
      amountUsd: usd,
      amountDop: usd * rate,
      exchangeRate: rate,
      trialDaysLeft: trialDaysLeft,
      nextRenewalAt:
          subscription?.currentPeriodEndsAt ?? subscription?.trialEndsAt,
      defaultPaymentMethod: null,
      remote: false,
    );
  }

  factory SubscriptionBillingSnapshot.fromJson(Map<String, dynamic> json) {
    final methodJson = json['defaultPaymentMethod'];
    return SubscriptionBillingSnapshot(
      plan: json['plan'] as String? ?? 'Sin plan',
      billingCycle: json['billingCycle'] as String? ?? BillingCycle.mensual,
      status: json['status'] as String? ?? 'trial',
      amountUsd: (json['amountUsd'] as num? ?? 0).toDouble(),
      amountDop: (json['amountDop'] as num? ?? 0).toDouble(),
      exchangeRate: (json['exchangeRate'] as num? ?? 59.25).toDouble(),
      trialDaysLeft: (json['trialDaysLeft'] as num? ?? 0).toInt(),
      nextRenewalAt: DateTime.tryParse(json['nextRenewalAt'] as String? ?? ''),
      defaultPaymentMethod: methodJson is Map<String, dynamic>
          ? PaymentMethodModel.fromJson(methodJson)
          : null,
      remote: true,
    );
  }
}

class SubscriptionBillingService {
  final PaymentService paymentService;

  const SubscriptionBillingService({required this.paymentService});

  Future<SubscriptionBillingSnapshot> fetchRemote() async {
    final response = await paymentService.getSubscriptionStatus();
    return SubscriptionBillingSnapshot.fromJson(response);
  }
}
