import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../models/cliente.dart';
import '../models/movimiento.dart';
import '../services/storage_service.dart';
import '../widgets/adaptive_layout.dart';
import 'login_screen.dart';

class PersonalPortalScreen extends StatefulWidget {
  final String telefono;

  const PersonalPortalScreen({
    super.key,
    required this.telefono,
  });

  @override
  State<PersonalPortalScreen> createState() => _PersonalPortalScreenState();
}

class _PersonalPortalScreenState extends State<PersonalPortalScreen> {
  Cliente? cliente;
  List<Movimiento> movimientos = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final clientes = await StorageService.cargarClientes();
    final historial = await StorageService.cargarHistorial();
    Cliente? encontrado;

    for (final item in clientes) {
      if (item.telefono == widget.telefono) {
        encontrado = item;
        break;
      }
    }

    final movimientosCliente = <Movimiento>[];
    if (encontrado != null) {
      movimientosCliente.addAll(
        historial.where(
          (movimiento) => movimiento.nombreCliente == encontrado!.nombre,
        ),
      );
      movimientosCliente.sort((a, b) => b.fecha.compareTo(a.fecha));
    }

    if (!mounted) {
      return;
    }

    setState(() {
      cliente = encontrado;
      movimientos = movimientosCliente;
      cargando = false;
    });
  }

  double get balance {
    return movimientos.fold<double>(0, (total, movimiento) {
      if (movimiento.tipo == 'pago') {
        return total - movimiento.monto;
      }

      return total + movimiento.monto;
    });
  }

  void _cerrarSesion() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombre = cliente?.nombre ?? 'Cliente';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi historial'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar sesion',
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentPadding =
                AdaptiveLayout.contentInset(constraints.maxWidth);

            if (cargando) {
              return const Center(child: CircularProgressIndicator());
            }

            return ListView(
              padding: EdgeInsets.fromLTRB(
                contentPadding,
                16,
                contentPadding,
                28,
              ),
              children: [
                _PersonalSummaryCard(
                  nombre: nombre,
                  telefono: widget.telefono,
                  balance: balance,
                  movimientos: movimientos.length,
                ),
                if (balance > 0) ...[
                  const SizedBox(height: 18),
                  _BusinessDebtCard(
                    balance: balance,
                    movimientos: movimientos.length,
                  ),
                ],
                const SizedBox(height: 22),
                const Text(
                  'Movimientos',
                  style: TextStyle(
                    color: Color(0xFF17322C),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                if (movimientos.isEmpty)
                  _EmptyPersonalState(telefono: widget.telefono)
                else
                  ...movimientos.map(
                    (movimiento) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MovimientoPersonalTile(movimiento: movimiento),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PersonalSummaryCard extends StatelessWidget {
  final String nombre;
  final String telefono;
  final double balance;
  final int movimientos;

  const _PersonalSummaryCard({
    required this.nombre,
    required this.telefono,
    required this.balance,
    required this.movimientos,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF17322C), Color(0xFF1F7A6B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2217322C),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Text(
              'Acceso personal',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            nombre,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            telefono,
            style: const TextStyle(color: Color(0xFFDCE9E5)),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _PersonalMetric(
                  label: 'Balance',
                  value: 'RD\$${balance.toStringAsFixed(2)}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PersonalMetric(
                  label: 'Movimientos',
                  value: '$movimientos',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BusinessDebtCard extends StatelessWidget {
  final double balance;
  final int movimientos;

  const _BusinessDebtCard({
    required this.balance,
    required this.movimientos,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFD9E8E3)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F3EF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              color: Color(0xFF1F7A6B),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  AppConstants.businessDisplayName,
                  style: TextStyle(
                    color: Color(0xFF17322C),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$movimientos movimientos registrados',
                  style: const TextStyle(color: Color(0xFF66756D)),
                ),
              ],
            ),
          ),
          Text(
            'RD\$${balance.toStringAsFixed(2)}',
            style: TextStyle(
              color: balance > 0
                  ? const Color(0xFFB42318)
                  : const Color(0xFF1F7A6B),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MovimientoPersonalTile extends StatelessWidget {
  final Movimiento movimiento;

  const _MovimientoPersonalTile({required this.movimiento});

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
                    color: Color(0xFF17322C),
                    fontWeight: FontWeight.w800,
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

class _PersonalMetric extends StatelessWidget {
  final String label;
  final String value;

  const _PersonalMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFDCE9E5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPersonalState extends StatelessWidget {
  final String telefono;

  const _EmptyPersonalState({required this.telefono});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE3DED2)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F3EF),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.history_toggle_off_rounded,
              color: Color(0xFF1F7A6B),
              size: 34,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No hay movimientos para este telefono',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF17322C),
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            telefono,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF66756D)),
          ),
        ],
      ),
    );
  }
}
