import 'package:flutter/material.dart';
import '../models/cliente.dart';
import '../models/movimiento.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/cliente_search_dialog.dart';
import 'historial_cliente_screen.dart';

class HistorialScreen extends StatelessWidget {
  final List<Movimiento> historial;
  final List<Cliente> clientes;

  const HistorialScreen({
    super.key,
    required this.historial,
    required this.clientes,
  });

  Cliente _clienteParaMovimiento(Movimiento movimiento) {
    for (final cliente in clientes) {
      if (cliente.nombre == movimiento.nombreCliente) {
        return cliente;
      }
    }

    return Cliente(nombre: movimiento.nombreCliente, telefono: 'Sin telefono');
  }

  Future<void> _buscarCliente(BuildContext context) async {
    final cliente = await showClienteSearchDialog(
      context: context,
      clientes: clientes,
    );

    if (cliente == null || !context.mounted) {
      return;
    }

    _abrirHistorialCliente(context, cliente);
  }

  void _abrirHistorialCliente(BuildContext context, Cliente cliente) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistorialClienteScreen(
          cliente: cliente,
          historial: historial,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final historialOrdenado = [...historial]
      ..sort((a, b) => b.fecha.compareTo(a.fecha));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Buscar cliente',
            onPressed: () => _buscarCliente(context),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentPadding =
              AdaptiveLayout.contentInset(constraints.maxWidth);

          if (historialOrdenado.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: contentPadding,
                  vertical: 28,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: const Icon(
                        Icons.history_toggle_off_rounded,
                        size: 40,
                        color: Color(0xFF1F7A6B),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'No hay movimientos',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF17322C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Aqui veras el registro completo de deudas y pagos a medida que uses la app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF66756D)),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
              padding: EdgeInsets.fromLTRB(
                contentPadding,
                16,
                contentPadding,
                24,
              ),
              itemCount: historialOrdenado.length,
              itemBuilder: (context, index) {
                final mov = historialOrdenado[index];
                final esPago = mov.tipo == 'pago';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _abrirHistorialCliente(
                      context,
                      _clienteParaMovimiento(mov),
                    ),
                    child: Ink(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: esPago
                              ? const Color(0xFFD9E8E3)
                              : const Color(0xFFF3D6D0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: esPago
                                  ? const Color(0xFFE7F3EF)
                                  : const Color(0xFFFDEAE5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              esPago
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.receipt_long_outlined,
                              color: esPago
                                  ? const Color(0xFF1F7A6B)
                                  : const Color(0xFFB54708),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mov.nombreCliente,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: Color(0xFF17322C),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  esPago ? 'Pago' : 'Deuda',
                                  style: TextStyle(
                                    color: esPago
                                        ? const Color(0xFF1F7A6B)
                                        : const Color(0xFFB54708),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'RD\$${mov.monto.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: esPago
                                      ? const Color(0xFF1F7A6B)
                                      : const Color(0xFFB42318),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${mov.fecha.day}/${mov.fecha.month}/${mov.fecha.year}',
                                style: const TextStyle(
                                  color: Color(0xFF66756D),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
        },
      ),
    );
  }
}
