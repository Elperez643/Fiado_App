import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/money_formatter.dart';
import '../data/services/api_client.dart';
import '../data/services/subscription_billing_service.dart';
import '../presentation/providers/auth_providers.dart';
import '../presentation/providers/sync_providers.dart';
import 'billing_history_screen.dart';
import 'payment_methods_screen.dart';

class SubscriptionStatusScreen extends ConsumerWidget {
  const SubscriptionStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(currentSubscriptionProvider).valueOrNull;
    final access = ref.watch(subscriptionStatusProvider).valueOrNull;
    final remoteFuture = ref
        .read(subscriptionBillingServiceProvider)
        .fetchRemote()
        .catchError((_) {
          return SubscriptionBillingSnapshot.local(
            subscription: subscription,
            trialDaysLeft: access?.trialDaysLeft ?? 0,
          );
        });

    return Scaffold(
      appBar: AppBar(title: const Text('Estado de suscripcion')),
      body: FutureBuilder<SubscriptionBillingSnapshot>(
        future: remoteFuture,
        builder: (context, snapshot) {
          final data =
              snapshot.data ??
              SubscriptionBillingSnapshot.local(
                subscription: subscription,
                trialDaysLeft: access?.trialDaysLeft ?? 0,
              );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (snapshot.hasError)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_errorText(snapshot.error)),
                  ),
                ),
              _StatusCard(data: data),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PaymentMethodsScreen(),
                  ),
                ),
                icon: const Icon(Icons.credit_card_outlined),
                label: const Text('Metodos de pago'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BillingHistoryScreen(),
                  ),
                ),
                icon: const Icon(Icons.history_outlined),
                label: const Text('Historial'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _mock(context, ref, 'charge'),
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Simular pago exitoso'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _mock(context, ref, 'renew'),
                icon: const Icon(Icons.autorenew_outlined),
                label: const Text('Simular renovacion'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _mock(context, ref, 'fail'),
                icon: const Icon(Icons.error_outline),
                label: const Text('Simular pago fallido'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _mock(BuildContext context, WidgetRef ref, String action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = ref.read(paymentServiceProvider);
      if (action == 'renew') {
        await service.mockRenew();
      } else if (action == 'fail') {
        await service.mockFail();
      } else {
        await service.mockCharge();
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Evento mock registrado.')),
      );
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  String _errorText(Object? error) {
    if (error is ApiException) return error.message;
    return 'Mostrando estado local porque backend no respondio.';
  }
}

class _StatusCard extends StatelessWidget {
  final SubscriptionBillingSnapshot data;

  const _StatusCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.plan,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _Line('Estado', data.status),
            _Line('Ciclo', data.billingCycle),
            _Line(
              'USD',
              MoneyFormatter.formatCurrency(data.amountUsd, symbol: 'USD '),
            ),
            _Line(
              'DOP aproximado',
              MoneyFormatter.formatCurrency(data.amountDop, symbol: ''),
            ),
            _Line('Tasa usada', data.exchangeRate.toStringAsFixed(2)),
            _Line('Trial restante', '${data.trialDaysLeft} dias'),
            _Line(
              'Proxima renovacion',
              data.nextRenewalAt?.toLocal().toString() ?? 'Pendiente',
            ),
            _Line(
              'Metodo',
              data.defaultPaymentMethod == null
                  ? 'No configurado'
                  : '${data.defaultPaymentMethod!.brand} ${data.defaultPaymentMethod!.last4}',
            ),
            _Line('Fuente', data.remote ? 'Backend' : 'Local'),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;

  const _Line(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
