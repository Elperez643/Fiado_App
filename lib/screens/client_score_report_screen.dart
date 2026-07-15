import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/money_formatter.dart';
import '../credit_scoring/client_score.dart';
import '../presentation/providers/auth_providers.dart';
import '../presentation/providers/fiado_data_providers.dart';

class ClientScoreReportScreen extends ConsumerWidget {
  const ClientScoreReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessId = ref.watch(currentBusinessIdProvider);
    final future = businessId == null
        ? Future<BusinessClientScoreReport>.error('No hay negocio activo.')
        : _load(ref, businessId);

    return Scaffold(
      appBar: AppBar(title: const Text('Inteligencia comercial')),
      body: FutureBuilder<BusinessClientScoreReport>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('No se pudo calcular: ${snapshot.error}'),
            );
          }
          final report = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Fiado App recomienda revisar estos rankings junto al contexto del negocio.',
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Top mejores clientes',
                scores: report.bestClients,
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Top clientes en riesgo',
                scores: report.riskyClients,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<BusinessClientScoreReport> _load(WidgetRef ref, int businessId) async {
    final clientes = await ref
        .read(clienteRepositoryProvider)
        .obtenerClientes(negocioId: businessId, limit: 1000);
    return ref
        .read(clientScoreServiceProvider)
        .buildBusinessReport(businessId: businessId, clientes: clientes);
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<ClientScore> scores;

  const _Section({required this.title, required this.scores});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (scores.isEmpty)
              const Text('Sin clientes suficientes para calcular.')
            else
              for (final score in scores)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text('${score.score}')),
                  title: Text(score.clientName),
                  subtitle: Text(
                    '${score.riskLevel} · ${MoneyFormatter.formatCurrency(score.suggestedCreditLimit)} sugerido',
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
