import 'package:flutter/material.dart';

import '../models/cliente.dart';
import '../models/movimiento.dart';
import '../widgets/adaptive_layout.dart';

class HistorialClienteScreen extends StatelessWidget {
  final Cliente cliente;
  final List<Movimiento> historial;

  const HistorialClienteScreen({
    super.key,
    required this.cliente,
    required this.historial,
  });

  @override
  Widget build(BuildContext context) {
    final movimientos = historial
        .where((movimiento) => movimiento.nombreCliente == cliente.nombre)
        .toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));

    final deudaTotal = movimientos.fold<double>(0, (total, movimiento) {
      if (movimiento.tipo == 'pago') {
        return total - movimiento.monto;
      }

      return total + movimiento.monto;
    });

    return Scaffold(
      appBar: AppBar(title: Text(cliente.nombre)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentPadding =
                AdaptiveLayout.contentInset(constraints.maxWidth);

            return ListView.separated(
              padding: EdgeInsets.fromLTRB(
                contentPadding,
                18,
                contentPadding,
                28,
              ),
              itemCount: movimientos.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _ResumenCliente(
                    cliente: cliente,
                    movimientos: movimientos.length,
                    balance: deudaTotal,
                  );
                }

                final movimiento = movimientos[index - 1];
                return _MovimientoTile(movimiento: movimiento);
              },
            );
          },
        ),
      ),
    );
  }
}

class _ResumenCliente extends StatelessWidget {
  final Cliente cliente;
  final int movimientos;
  final double balance;

  const _ResumenCliente({
    required this.cliente,
    required this.movimientos,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF17322C), Color(0xFF1F7A6B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cliente.telefono,
            style: const TextStyle(color: Color(0xFFDCE9E5)),
          ),
          const SizedBox(height: 12),
          Text(
            'RD\$${balance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$movimientos movimientos registrados',
            style: const TextStyle(color: Color(0xFFDCE9E5)),
          ),
        ],
      ),
    );
  }
}

class _MovimientoTile extends StatelessWidget {
  final Movimiento movimiento;

  const _MovimientoTile({required this.movimiento});

  @override
  Widget build(BuildContext context) {
    final esPago = movimiento.tipo == 'pago';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: esPago ? const Color(0xFFD9E8E3) : const Color(0xFFF3D6D0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: esPago ? const Color(0xFFE7F3EF) : const Color(0xFFFDEAE5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              esPago ? Icons.payments_outlined : Icons.add_card_outlined,
              color: esPago ? const Color(0xFF1F7A6B) : const Color(0xFFB54708),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  esPago ? 'Pago registrado' : 'Deuda agregada',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF17322C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${movimiento.fecha.day}/${movimiento.fecha.month}/${movimiento.fecha.year}',
                  style: const TextStyle(color: Color(0xFF66756D)),
                ),
              ],
            ),
          ),
          Text(
            'RD\$${movimiento.monto.toStringAsFixed(2)}',
            style: TextStyle(
              color: esPago ? const Color(0xFF1F7A6B) : const Color(0xFFB42318),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
