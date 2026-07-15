import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/payment_method_model.dart';
import '../data/services/api_client.dart';
import '../presentation/providers/sync_providers.dart';

class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() =>
      _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen> {
  late Future<List<PaymentMethodModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<PaymentMethodModel>> _load() {
    return ref.read(paymentServiceProvider).getMethods();
  }

  Future<void> _addAzulSandbox() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(paymentServiceProvider).confirmAzulSandboxCard();
      setState(() => _future = _load());
      messenger.showSnackBar(
        const SnackBar(content: Text('Metodo Azul sandbox 4242 agregado.')),
      );
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Metodos de pago')),
      body: FutureBuilder<List<PaymentMethodModel>>(
        future: _future,
        builder: (context, snapshot) {
          final methods = snapshot.data ?? const <PaymentMethodModel>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                kDebugMode
                    ? 'Azul sandbox mock de desarrollo. No se cobra dinero real ni se guardan datos sensibles.'
                    : 'Para gestionar metodos de pago necesitas conexion segura a la nube.',
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _addAzulSandbox,
                  icon: const Icon(Icons.add_card_outlined),
                  label: const Text('Agregar Azul sandbox 4242'),
                ),
              ],
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (snapshot.hasError)
                _InfoBox(message: _errorText(snapshot.error))
              else if (methods.isEmpty)
                const _InfoBox(message: 'No hay metodos de pago configurados.')
              else
                for (final method in methods)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.credit_card_outlined),
                      title: Text(
                        '${method.brand} terminada en ${method.last4}',
                      ),
                      subtitle: Text(
                        '${method.provider.toUpperCase()} · Exp ${method.expMonth}/${method.expYear}',
                      ),
                      trailing: method.isDefault
                          ? const Chip(label: Text('Default'))
                          : null,
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  String _errorText(Object? error) {
    if (error is ApiException) return error.message;
    return 'No se pudo cargar metodos de pago.';
  }
}

class _InfoBox extends StatelessWidget {
  final String message;

  const _InfoBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
    );
  }
}
