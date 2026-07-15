import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/money_formatter.dart';
import '../credit_scoring/client_score.dart';
import '../models/cliente.dart';
import '../presentation/providers/auth_providers.dart';
import '../presentation/providers/fiado_data_providers.dart';

class ClientScoreScreen extends ConsumerWidget {
  final Cliente cliente;

  const ClientScoreScreen({super.key, required this.cliente});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessId = ref.watch(currentBusinessIdProvider);
    final scoreFuture = businessId == null
        ? Future<ClientScore>.error('No hay negocio activo.')
        : ref
              .read(clientScoreServiceProvider)
              .calculateClientScore(cliente: cliente, businessId: businessId);

    return Scaffold(
      appBar: AppBar(title: const Text('Score inteligente')),
      body: FutureBuilder<ClientScore>(
        future: scoreFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('No se pudo calcular: ${snapshot.error}'),
            );
          }
          final score = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ScoreHeader(score: score),
              const SizedBox(height: 12),
              _MetricGrid(score: score),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Motivos del calculo',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      for (final reason in score.reasons)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle_outline, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(reason)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ScoreHeader extends StatelessWidget {
  final ClientScore score;

  const _ScoreHeader({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score.score >= 70
        ? const Color(0xFF1B7F63)
        : score.score >= 40
        ? const Color(0xFFE7B04B)
        : const Color(0xFFB3261E);
    return Card(
      color: const Color(0xFF17322C),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fiado App recomienda',
              style: TextStyle(color: Color(0xFFDCE9E5)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: color,
                  child: Text(
                    '${score.score}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        score.riskLevel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Limite sugerido ${MoneyFormatter.formatCurrency(score.suggestedCreditLimit)}',
                        style: const TextStyle(color: Color(0xFFDCE9E5)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final ClientScore score;

  const _MetricGrid({required this.score});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Cumplimiento', '${score.paymentCompliancePercent.toStringAsFixed(1)}%'),
      ('Fiado historico', MoneyFormatter.formatCurrency(score.totalCredits)),
      ('Pagado', MoneyFormatter.formatCurrency(score.totalPayments)),
      ('Vencidos 30', '${score.overdue30Count}'),
      ('Mora 45', '${score.overdue45Count}'),
      ('Bloqueos 60', '${score.blocked60Count}'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: 2.25,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item.$1, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                      item.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
