import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/money_formatter.dart';
import '../data/models/credito_ciclo_sqlite_model.dart';
import '../data/services/credito_mensaje_service.dart';
import '../models/cliente.dart';
import '../presentation/providers/fiado_data_providers.dart';
import '../widgets/adaptive_layout.dart';
import 'detalle_cliente_screen.dart';

class CuentasPorCobrarScreen extends ConsumerWidget {
  const CuentasPorCobrarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vencidos = ref.watch(cuentasPorCobrarProvider);
    final mora = ref.watch(ciclosMoraProvider);
    final bloqueados = ref.watch(ciclosBloqueadosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cuentas por cobrar')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padding = AdaptiveLayout.contentInset(constraints.maxWidth);
            return ListView(
              padding: EdgeInsets.fromLTRB(padding, 16, padding, 28),
              children: [
                _Section(
                  title: 'Vencidos 30 dias',
                  asyncValue: vencidos,
                  color: const Color(0xFFFFF3CD),
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'Mora 45 dias',
                  asyncValue: mora,
                  color: const Color(0xFFFFE1B8),
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'Bloqueados 60 dias',
                  asyncValue: bloqueados,
                  color: const Color(0xFFFFD6D1),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Section extends ConsumerWidget {
  final String title;
  final AsyncValue<List<CreditoCicloSqliteModel>> asyncValue;
  final Color color;

  const _Section({
    required this.title,
    required this.asyncValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return asyncValue.when(
      data: (ciclos) {
        final total = ciclos.fold<double>(
          0,
          (sum, ciclo) => sum + ciclo.saldoPendiente,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF17322C),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  MoneyFormatter.formatCurrency(total, symbol: 'US\$'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (ciclos.isEmpty)
              const _EmptyState()
            else
              for (final ciclo in ciclos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CicloTile(ciclo: ciclo, color: color),
                ),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Text('No se pudo cargar: $error'),
    );
  }
}

class _CicloTile extends ConsumerWidget {
  final CreditoCicloSqliteModel ciclo;
  final Color color;

  const _CicloTile({required this.ciclo, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cliente = Cliente(
      nombre: ciclo.clienteNombre ?? 'Cliente',
      telefono: ciclo.clienteTelefono ?? '',
      deuda: ciclo.saldoPendiente,
    );
    final mensaje = CreditoMensajeService.mensajePorEstado(
      ciclo: ciclo,
      nombreCliente: cliente.nombre,
      nombreNegocio: ciclo.negocioNombre ?? 'tu negocio',
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE7B04B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  cliente.nombre,
                  style: const TextStyle(
                    color: Color(0xFF17322C),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                MoneyFormatter.formatCurrency(
                  ciclo.saldoPendiente,
                  symbol: 'US\$',
                ),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${cliente.telefono} - ${ciclo.negocioNombre ?? 'Negocio'}'),
          Text(
            'Inicio ${_fecha(ciclo.fechaInicio)} / limite ${_fecha(ciclo.fechaLimite30)}',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetalleClienteScreen(
                        cliente: cliente,
                        historial: const [],
                        clientes: const [],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.person_search_outlined),
                label: const Text('Ver cliente'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref
                      .read(creditoCicloRepositoryProvider)
                      .generarToqueManual(
                        ciclo: ciclo,
                        nombreCliente: cliente.nombre,
                        nombreNegocio: ciclo.negocioNombre ?? 'tu negocio',
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Toque registrado.')),
                    );
                  }
                },
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Dar toque'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  CreditoMensajeService.abrirWhatsAppConMensaje(
                    telefono: cliente.telefono,
                    mensaje: mensaje,
                  );
                },
                icon: const Icon(Icons.chat_outlined),
                label: const Text('WhatsApp'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fecha(DateTime fecha) => '${fecha.day}/${fecha.month}/${fecha.year}';
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD9E8E3)),
      ),
      child: const Text('No hay clientes en este estado.'),
    );
  }
}
