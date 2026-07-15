class PaymentMethodModel {
  final String id;
  final String provider;
  final String brand;
  final String last4;
  final int expMonth;
  final int expYear;
  final bool isDefault;
  final DateTime createdAt;

  const PaymentMethodModel({
    required this.id,
    required this.provider,
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
    required this.isDefault,
    required this.createdAt,
  });

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodModel(
      id: json['id'] as String? ?? '',
      provider: json['provider'] as String? ?? 'mock',
      brand: json['brand'] as String? ?? 'Visa',
      last4: json['last4'] as String? ?? '4242',
      expMonth: (json['expMonth'] as num? ?? 12).toInt(),
      expYear: (json['expYear'] as num? ?? 2030).toInt(),
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static PaymentMethodModel mockDefault() => PaymentMethodModel(
    id: 'local-mock-4242',
    provider: 'mock',
    brand: 'Visa',
    last4: '4242',
    expMonth: 12,
    expYear: 2030,
    isDefault: true,
    createdAt: DateTime.now(),
  );
}
