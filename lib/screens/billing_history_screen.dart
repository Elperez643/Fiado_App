import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/money_formatter.dart';
import '../data/models/subscription_payment_model.dart';
import '../data/services/api_client.dart';
import '../presentation/providers/sync_providers.dart';

class BillingHistoryScreen extends ConsumerWidget {
  const BillingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final future = ref.read(paymentServiceProvider).getHistory();
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de pagos')),
      body: FutureBuilder<List<SubscriptionPaymentModel>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(_errorText(snapshot.error)));
          }
          final payments = snapshot.data ?? const <SubscriptionPaymentModel>[];
          if (payments.isEmpty) {
            return const Center(child: Text('Todavia no hay pagos mock.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final payment = payments[index];
              return ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(
                  '${MoneyFormatter.formatCurrency(payment.amountUsd, symbol: 'USD ')} · DOP aprox. ${MoneyFormatter.formatCurrency(payment.amountDop, symbol: '')}',
                ),
                subtitle: Text(
                  '${payment.billingCycle} · ${payment.provider} · ${payment.paymentDate.toLocal()}',
                ),
                trailing: Chip(label: Text(payment.status)),
              );
            },
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemCount: payments.length,
          );
        },
      ),
    );
  }

  String _errorText(Object? error) {
    if (error is ApiException) return error.message;
    return 'No se pudo cargar historial.';
  }
}
