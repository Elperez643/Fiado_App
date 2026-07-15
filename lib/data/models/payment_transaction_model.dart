class PaymentTransactionModel {
  final String id;
  final String paymentId;
  final String provider;
  final String requestJson;
  final String responseJson;
  final String status;
  final DateTime createdAt;

  const PaymentTransactionModel({
    required this.id,
    required this.paymentId,
    required this.provider,
    required this.requestJson,
    required this.responseJson,
    required this.status,
    required this.createdAt,
  });

  factory PaymentTransactionModel.fromJson(Map<String, dynamic> json) {
    return PaymentTransactionModel(
      id: json['id'] as String? ?? '',
      paymentId: json['paymentId'] as String? ?? '',
      provider: json['provider'] as String? ?? 'mock',
      requestJson: json['requestJson'] as String? ?? '{}',
      responseJson: json['responseJson'] as String? ?? '{}',
      status: json['status'] as String? ?? 'pending',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
