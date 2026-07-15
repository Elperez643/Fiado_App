import '../models/payment_method_model.dart';
import '../models/subscription_payment_model.dart';
import 'api_client.dart';

class PaymentService {
  final ApiClient apiClient;

  const PaymentService({required this.apiClient});

  Future<List<PaymentMethodModel>> getMethods() async {
    final items = await apiClient.getList('/payments/methods');
    return items
        .whereType<Map<String, dynamic>>()
        .map(PaymentMethodModel.fromJson)
        .toList();
  }

  Future<PaymentMethodModel> addMockMethod() async {
    final response = await apiClient.post(
      '/payments/methods',
      body: {
        'provider': 'mock',
        'mockCardLast4': '4242',
        'brand': 'Visa',
        'expMonth': 12,
        'expYear': 2030,
        'isDefault': true,
      },
    );
    return PaymentMethodModel.fromJson(response);
  }

  Future<List<SubscriptionPaymentModel>> getHistory() async {
    final items = await apiClient.getList('/payments/history');
    return items
        .whereType<Map<String, dynamic>>()
        .map(SubscriptionPaymentModel.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> getSubscriptionStatus() {
    return apiClient.get('/payments/subscription');
  }

  Future<String> createStripeCheckoutSession({
    required String planId,
    required String billingCycle,
  }) async {
    final response = await apiClient.post(
      '/payments/stripe/create-checkout-session',
      body: {'planId': planId, 'billingCycle': billingCycle},
    );
    final url = response['checkoutUrl'] as String?;
    if (url == null || url.isEmpty) {
      throw const ApiException('Stripe no devolvio URL de Checkout.');
    }
    return url;
  }

  Future<String> createStripeSetupSession({
    required String planId,
    required String billingCycle,
  }) async {
    final response = await apiClient.post(
      '/payments/stripe/create-setup-session',
      body: {'planId': planId, 'billingCycle': billingCycle},
    );
    final url = response['checkoutUrl'] as String?;
    if (url == null || url.isEmpty) {
      throw const ApiException('Stripe no devolvio URL para agregar tarjeta.');
    }
    return url;
  }

  Future<Map<String, dynamic>> createAzulCardTokenSession({
    required String planId,
    required String billingCycle,
  }) {
    return apiClient.post(
      '/payments/azul/create-card-token-session',
      body: {'planId': planId, 'billingCycle': billingCycle},
    );
  }

  Future<PaymentMethodModel> confirmAzulSandboxCard({
    String brand = 'Visa',
    String last4 = '4242',
    int expMonth = 12,
    int expYear = 2030,
  }) async {
    final response = await apiClient.post(
      '/payments/azul/confirm-card-token',
      body: {
        'brand': brand,
        'last4': last4,
        'expMonth': expMonth,
        'expYear': expYear,
        'isDefault': true,
      },
    );
    return PaymentMethodModel.fromJson(response);
  }

  Future<Map<String, dynamic>> activateTrial({
    required String planId,
    required String billingCycle,
  }) {
    return apiClient.post(
      '/subscriptions/activate-trial',
      body: {'planId': planId, 'billingCycle': billingCycle},
    );
  }

  Future<Map<String, dynamic>> getSubscriptionArchitectureStatus() {
    return apiClient.get('/subscriptions/status');
  }

  Future<Map<String, dynamic>> chargeAzulSubscription({
    bool forceFailure = false,
  }) {
    return apiClient.post(
      '/payments/azul/charge-subscription',
      body: {'forceFailure': forceFailure},
    );
  }

  Future<SubscriptionPaymentModel> mockCharge() async {
    final response = await apiClient.post('/payments/mock/charge');
    return SubscriptionPaymentModel.fromJson(response);
  }

  Future<SubscriptionPaymentModel> mockRenew() async {
    final response = await apiClient.post('/payments/mock/renew');
    return SubscriptionPaymentModel.fromJson(response);
  }

  Future<SubscriptionPaymentModel> mockFail() async {
    final response = await apiClient.post('/payments/mock/fail');
    return SubscriptionPaymentModel.fromJson(response);
  }
}
