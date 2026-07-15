class SubscriptionPaymentModel {
  final String id;
  final String subscriptionId;
  final double amountUsd;
  final double amountDop;
  final double exchangeRate;
  final String billingCycle;
  final DateTime paymentDate;
  final String status;
  final String provider;
  final String? providerTransactionId;

  const SubscriptionPaymentModel({
    required this.id,
    required this.subscriptionId,
    required this.amountUsd,
    required this.amountDop,
    required this.exchangeRate,
    required this.billingCycle,
    required this.paymentDate,
    required this.status,
    required this.provider,
    this.providerTransactionId,
  });

  factory SubscriptionPaymentModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionPaymentModel(
      id: json['id'] as String? ?? '',
      subscriptionId: json['subscriptionId'] as String? ?? '',
      amountUsd: (json['amountUsd'] as num? ?? 0).toDouble(),
      amountDop: (json['amountDop'] as num? ?? 0).toDouble(),
      exchangeRate: (json['exchangeRate'] as num? ?? 0).toDouble(),
      billingCycle: json['billingCycle'] as String? ?? 'mensual',
      paymentDate:
          DateTime.tryParse(json['paymentDate'] as String? ?? '') ??
          DateTime.now(),
      status: json['status'] as String? ?? 'pending',
      provider: json['provider'] as String? ?? 'mock',
      providerTransactionId: json['providerTransactionId'] as String?,
    );
  }
}
