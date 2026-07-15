// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/money_formatter.dart';
import '../data/models/comprobante_sqlite_model.dart';
import '../data/models/credito_ciclo_sqlite_model.dart';
import '../data/models/deuda_item_sqlite_model.dart';
import '../data/models/solicitud_autorizacion_sqlite_model.dart';
import '../data/models/usuario_sqlite_model.dart';
import '../data/repositories/credito_ciclo_repository.dart';
import '../data/services/credito_mensaje_service.dart';
import '../models/cliente.dart';
import '../models/movimiento.dart';
import '../presentation/providers/auth_providers.dart';
import '../presentation/providers/fiado_data_providers.dart';
import '../widgets/adaptive_layout.dart';
import 'comprobante_screen.dart';
import 'client_score_screen.dart';
import 'widgets/agregar_deuda_dialog.dart';

class DetalleClienteScreen extends ConsumerStatefulWidget {
  final Cliente cliente;
  final List<Movimiento> historial;
  final List<Cliente> clientes;

  const DetalleClienteScreen({
    super.key,
    required this.cliente,
    required this.historial,
    required this.clientes,
  });

  @override
  ConsumerState<DetalleClienteScreen> createState() =>
      _DetalleClienteScreenState();
}

class _DetalleDeudaDato extends StatelessWidget {
  final String label;
  final String value;

  const _DetalleDeudaDato({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF66756D),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF17322C),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditoCicloAlDiaCard extends StatelessWidget {
  const _CreditoCicloAlDiaCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD9E8E3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_outlined, color: Color(0xFF1F7A6B)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sin ciclo de credito pendiente. El proximo fiado iniciara un ciclo de 30 dias.',
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditoCicloEstadoCard extends StatefulWidget {
  final CreditoCicloSqliteModel ciclo;
  final String clienteNombre;
  final String clienteTelefono;
  final String negocioNombre;
  final VoidCallback onDarToque;
  final VoidCallback onWhatsApp;
  final VoidCallback? onFiarDeTodosModos;

  const _CreditoCicloEstadoCard({
    required this.ciclo,
    required this.clienteNombre,
    required this.clienteTelefono,
    required this.negocioNombre,
    required this.onDarToque,
    required this.onWhatsApp,
    this.onFiarDeTodosModos,
  });

  @override
  State<_CreditoCicloEstadoCard> createState() =>
      _CreditoCicloEstadoCardState();
}

class _CreditoCicloEstadoCardState extends State<_CreditoCicloEstadoCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    if (widget.ciclo.estado == CreditoCicloEstado.mora45) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _CreditoCicloEstadoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ciclo.estado == CreditoCicloEstado.mora45 &&
        !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (widget.ciclo.estado != CreditoCicloEstado.mora45 &&
        _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ciclo = widget.ciclo;
    final dias = DateTime.now().difference(ciclo.fechaInicio).inDays;
    final blocked = ciclo.estado == CreditoCicloEstado.bloqueado60;
    final overdue = ciclo.estado != CreditoCicloEstado.activo;
    final saldado = ciclo.estado == CreditoCicloEstado.saldado;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final baseColor = _colorPorEstado(ciclo.estado);
        final color = ciclo.estado == CreditoCicloEstado.mora45
            ? Color.lerp(
                const Color(0xFFFFF3CD),
                const Color(0xFFFFD6D1),
                _controller.value,
              )!
            : baseColor;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: blocked
                  ? const Color(0xFFB42318)
                  : const Color(0xFFE7B04B),
            ),
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                blocked
                    ? Icons.block_outlined
                    : saldado
                    ? Icons.done_all_outlined
                    : overdue
                    ? Icons.warning_amber_rounded
                    : Icons.schedule_outlined,
                color: saldado
                    ? const Color(0xFF1F7A6B)
                    : blocked
                    ? const Color(0xFFB42318)
                    : const Color(0xFF8A5A00),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ciclo de credito: ${_estadoLabel(ciclo.estado)}',
                  style: const TextStyle(
                    color: Color(0xFF17322C),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _CreditoDato(label: 'Inicio', value: _fecha(ciclo.fechaInicio)),
              _CreditoDato(
                label: 'Limite 30',
                value: _fecha(ciclo.fechaLimite30),
              ),
              _CreditoDato(label: 'Dias', value: '$dias'),
              _CreditoDato(
                label: 'Saldo',
                value: MoneyFormatter.formatCurrency(
                  ciclo.saldoPendiente,
                  symbol: 'US\$',
                ),
              ),
              if (ciclo.fechaSaldado != null)
                _CreditoDato(
                  label: 'Saldado',
                  value: _fecha(ciclo.fechaSaldado!),
                ),
            ],
          ),
          if (overdue && !saldado) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: widget.onDarToque,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Dar toque'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onWhatsApp,
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('WhatsApp'),
                ),
                if (widget.onFiarDeTodosModos != null)
                  FilledButton.icon(
                    onPressed: widget.onFiarDeTodosModos,
                    icon: const Icon(Icons.lock_open_outlined),
                    label: const Text('Fiar de todos modos'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _colorPorEstado(String estado) {
    switch (estado) {
      case CreditoCicloEstado.bloqueado60:
        return const Color(0xFFFFD6D1);
      case CreditoCicloEstado.saldado:
        return const Color(0xFFE7F3EF);
      case CreditoCicloEstado.mora45:
      case CreditoCicloEstado.vencido30:
        return const Color(0xFFFFF3CD);
      default:
        return Colors.white;
    }
  }

  String _estadoLabel(String estado) {
    switch (estado) {
      case CreditoCicloEstado.vencido30:
        return 'vencido 30 dias';
      case CreditoCicloEstado.mora45:
        return 'mora 45 dias';
      case CreditoCicloEstado.bloqueado60:
        return 'bloqueado 60 dias';
      case CreditoCicloEstado.saldado:
        return 'Saldado - Borron y cuenta nueva';
      default:
        return 'activo';
    }
  }

  String _fecha(DateTime fecha) {
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }
}

class _CreditoDato extends StatelessWidget {
  final String label;
  final String value;

  const _CreditoDato({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF66756D),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF17322C),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetalleClienteScreenState extends ConsumerState<DetalleClienteScreen> {
  bool telefonoValido(String telefono) {
    return RegExp(r'^\d{10}$').hasMatch(telefono);
  }

  void mostrarErrorTelefono() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('El telefono debe tener exactamente 10 digitos.'),
      ),
    );
  }

  Future<String?> _nombreNegocioActual() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return null;
    if (user.tipoUsuario == UsuarioSqliteModel.tipoNegocio) {
      return user.nombre;
    }
    final negocioId = user.negocioId;
    if (negocioId == null) return user.nombre;
    final negocio = await ref
        .read(authRepositoryProvider)
        .obtenerUsuarioPorId(negocioId);
    return negocio?.nombre ?? user.nombre;
  }

  Future<ComprobanteSqliteModel> _crearOObtenerComprobante({
    required Movimiento movimiento,
    required List<DeudaItemSqliteModel> items,
    double? saldoAnterior,
    double? saldoNuevo,
    double? subtotalMercancias,
    double? ajusteManual,
    double? abonoInicial,
  }) async {
    if (movimiento.id == null) {
      throw StateError('Este movimiento no tiene identificador local.');
    }

    final repository = ref.read(comprobanteRepositoryProvider);
    final negocioId = ref.read(currentBusinessIdProvider);
    if (negocioId == null) {
      throw StateError('No hay un negocio activo para crear comprobantes.');
    }
    final existente = await repository.obtenerComprobantePorMovimiento(
      movimiento.id!,
      negocioId: negocioId,
    );
    if (existente != null) {
      if (movimiento.tipo == 'deuda') {
        final productos = items.isNotEmpty
            ? items
            : await ref
                  .read(deudaItemRepositoryProvider)
                  .obtenerItemsPorMovimiento(
                    movimiento.id!,
                    negocioId: negocioId,
                  );
        if (productos.isNotEmpty) {
          return repository.actualizarComprobanteDeuda(
            existente,
            productos: productos,
            total: movimiento.monto,
            saldoPendiente: saldoNuevo ?? widget.cliente.deuda,
            concepto: movimiento.concepto,
            subtotalMercancias: subtotalMercancias,
            ajusteManual: ajusteManual,
            abonoInicial: abonoInicial,
          );
        }
      }
      return existente;
    }

    final user = ref.read(currentUserProvider);
    final negocioNombre = await _nombreNegocioActual();
    if (movimiento.tipo == 'pago') {
      return repository.crearComprobantePago(
        negocioId: negocioId,
        movimientoId: movimiento.id!,
        clienteNombre: widget.cliente.nombre,
        clienteTelefono: widget.cliente.telefono,
        negocioNombre: negocioNombre,
        fecha: movimiento.fecha,
        montoPagado: movimiento.monto,
        deudaAnterior: saldoAnterior ?? widget.cliente.deuda + movimiento.monto,
        saldoNuevo: saldoNuevo ?? widget.cliente.deuda,
        creadoPorUsuarioId: user?.id,
        creadoPorNombre: user?.nombre,
      );
    }

    final productosComprobante = movimiento.tipo == 'deuda' && items.isEmpty
        ? await ref
              .read(deudaItemRepositoryProvider)
              .obtenerItemsPorMovimiento(movimiento.id!, negocioId: negocioId)
        : items;

    return repository.crearComprobanteDeuda(
      negocioId: negocioId,
      movimientoId: movimiento.id!,
      clienteNombre: widget.cliente.nombre,
      clienteTelefono: widget.cliente.telefono,
      negocioNombre: negocioNombre,
      fecha: movimiento.fecha,
      concepto: movimiento.concepto,
      productos: productosComprobante,
      total: movimiento.monto,
      saldoPendiente: saldoNuevo ?? widget.cliente.deuda,
      subtotalMercancias: subtotalMercancias,
      ajusteManual: ajusteManual,
      abonoInicial: abonoInicial,
      creadoPorUsuarioId: user?.id,
      creadoPorNombre: user?.nombre,
    );
  }

  Future<void> _abrirComprobante({
    required Movimiento movimiento,
    List<DeudaItemSqliteModel> items = const [],
    double? saldoAnterior,
    double? saldoNuevo,
  }) async {
    try {
      final comprobante = await _crearOObtenerComprobante(
        movimiento: movimiento,
        items: items,
        saldoAnterior: saldoAnterior,
        saldoNuevo: saldoNuevo,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ComprobanteScreen(comprobante: comprobante),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el comprobante: $error')),
      );
    }
  }

  Future<void> agregarDeuda() async {
    final negocioId = ref.read(currentBusinessIdProvider);
    if (negocioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay un negocio activo.')),
      );
      return;
    }

    final resultado = await showDialog<AgregarDeudaResult>(
      context: context,
      builder: (_) {
        return AgregarDeudaDialog(clienteNombre: widget.cliente.nombre);
      },
    );

    if (resultado == null || !mounted) return;

    final movimiento = Movimiento(
      clienteId: widget.cliente.id,
      nombreCliente: widget.cliente.nombre,
      clienteTelefono: widget.cliente.telefono,
      tipo: 'deuda',
      monto: resultado.monto,
      fecha: DateTime.now(),
      concepto: resultado.concepto,
    );
    final nuevaDeuda = widget.cliente.deuda + resultado.monto;

    try {
      final movimientoId = await ref
          .read(movimientosProvider.notifier)
          .guardarMovimiento(
            movimiento,
            deudaItems: resultado.items,
            clienteTelefono: widget.cliente.telefono,
          );
      await ref
          .read(clientesProvider.notifier)
          .actualizarCliente(
            cliente: Cliente(
              id: widget.cliente.id,
              nombre: widget.cliente.nombre,
              telefono: widget.cliente.telefono,
              deuda: nuevaDeuda,
            ),
          );
      await ref.read(productosProvider.notifier).recargar();
      _invalidarDespuesDeGuardarDeuda(
        afectoInventario: resultado.items.isNotEmpty,
      );
      final movimientoGuardado = Movimiento(
        id: movimientoId,
        clienteId: widget.cliente.id,
        nombreCliente: movimiento.nombreCliente,
        clienteTelefono: widget.cliente.telefono,
        tipo: movimiento.tipo,
        monto: movimiento.monto,
        fecha: movimiento.fecha,
        concepto: movimiento.concepto,
      );
      await _crearOObtenerComprobante(
        movimiento: movimientoGuardado,
        items: resultado.items,
        saldoNuevo: nuevaDeuda,
        subtotalMercancias: resultado.subtotalMercancias,
        ajusteManual: resultado.ajusteManual,
        abonoInicial: resultado.abonoInicial,
      );
      Movimiento? abonoInicialMovimiento;
      if (resultado.abonoInicial > 0.01) {
        abonoInicialMovimiento = await _registrarAbonoInicial(
          deudaMovimientoId: movimientoId,
          monto: resultado.abonoInicial,
        );
      }
      _invalidarCreditoCliente();
      if (!mounted) return;
      setState(() {
        widget.cliente.deuda = nuevaDeuda;
        widget.historial.add(movimientoGuardado);
        if (abonoInicialMovimiento != null) {
          widget.historial.add(abonoInicialMovimiento);
        }
      });
      await _mostrarDetalleDeuda(
        movimientoGuardado,
        subtotalMercancias: resultado.subtotalMercancias,
        ajusteManual: resultado.ajusteManual,
        abonoInicial: resultado.abonoInicial,
      );
    } catch (error) {
      if (error is CreditoBloqueadoException) {
        final confirmado = await _confirmarFiarDeTodosModos(error.ciclo);
        if (confirmado == null) return;
        await _guardarDeudaComoExcepcion(
          movimiento: movimiento,
          resultado: resultado,
          nuevaDeuda: nuevaDeuda,
          motivo: confirmado,
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _guardarDeudaComoExcepcion({
    required Movimiento movimiento,
    required AgregarDeudaResult resultado,
    required double nuevaDeuda,
    String? motivo,
  }) async {
    try {
      final movimientoId = await ref
          .read(movimientosProvider.notifier)
          .guardarMovimiento(
            movimiento,
            deudaItems: resultado.items,
            clienteTelefono: widget.cliente.telefono,
            fiarDeTodosModos: true,
            motivoExcepcion: motivo,
          );
      await ref
          .read(clientesProvider.notifier)
          .actualizarCliente(
            cliente: Cliente(
              id: widget.cliente.id,
              nombre: widget.cliente.nombre,
              telefono: widget.cliente.telefono,
              deuda: nuevaDeuda,
            ),
          );
      await ref.read(productosProvider.notifier).recargar();
      _invalidarDespuesDeGuardarDeuda(
        afectoInventario: resultado.items.isNotEmpty,
      );
      final movimientoGuardado = Movimiento(
        id: movimientoId,
        clienteId: widget.cliente.id,
        nombreCliente: movimiento.nombreCliente,
        clienteTelefono: widget.cliente.telefono,
        tipo: movimiento.tipo,
        monto: movimiento.monto,
        fecha: movimiento.fecha,
        concepto: movimiento.concepto,
      );
      await _crearOObtenerComprobante(
        movimiento: movimientoGuardado,
        items: resultado.items,
        saldoNuevo: nuevaDeuda,
        subtotalMercancias: resultado.subtotalMercancias,
        ajusteManual: resultado.ajusteManual,
        abonoInicial: resultado.abonoInicial,
      );
      Movimiento? abonoInicialMovimiento;
      if (resultado.abonoInicial > 0.01) {
        abonoInicialMovimiento = await _registrarAbonoInicial(
          deudaMovimientoId: movimientoId,
          monto: resultado.abonoInicial,
        );
      }
      _invalidarCreditoCliente();
      if (!mounted) return;
      setState(() {
        widget.cliente.deuda = nuevaDeuda;
        widget.historial.add(movimientoGuardado);
        if (abonoInicialMovimiento != null) {
          widget.historial.add(abonoInicialMovimiento);
        }
      });
      await _mostrarDetalleDeuda(
        movimientoGuardado,
        subtotalMercancias: resultado.subtotalMercancias,
        ajusteManual: resultado.ajusteManual,
        abonoInicial: resultado.abonoInicial,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _invalidarDespuesDeGuardarDeuda({required bool afectoInventario}) {
    ref.invalidate(movimientosProvider);
    ref.invalidate(collectionInsightsProvider);
    ref.invalidate(businessRecommendationsProvider);
    if (afectoInventario) {
      ref.invalidate(billableProductsProvider);
      ref.invalidate(productosProvider);
      ref.invalidate(inventarioResumenProvider);
      ref.invalidate(inventoryInsightsProvider);
      ref.invalidate(inventoryDirtyMetricsCountProvider);
      ref.invalidate(inventoryCachedMetricsCountProvider);
    }
  }

  Future<Movimiento> _registrarAbonoInicial({
    required int deudaMovimientoId,
    required double monto,
  }) async {
    final pago = Movimiento(
      clienteId: widget.cliente.id,
      nombreCliente: widget.cliente.nombre,
      clienteTelefono: widget.cliente.telefono,
      tipo: 'pago',
      monto: monto,
      fecha: DateTime.now(),
      concepto: 'Abono inicial del fiado #$deudaMovimientoId',
    );
    final id = await ref
        .read(movimientosProvider.notifier)
        .guardarMovimientoInformativo(pago);
    debugPrint(
      '[deuda-items] abono inicial registrado id=$id deuda=$deudaMovimientoId monto=$monto',
    );
    return Movimiento(
      id: id,
      clienteId: widget.cliente.id,
      nombreCliente: pago.nombreCliente,
      clienteTelefono: widget.cliente.telefono,
      tipo: pago.tipo,
      monto: pago.monto,
      fecha: pago.fecha,
      concepto: pago.concepto,
    );
  }

  Future<String?> _confirmarFiarDeTodosModos(
    CreditoCicloSqliteModel ciclo,
  ) async {
    final motivoController = TextEditingController();
    String? resultado;
    try {
      resultado = await showDialog<String?>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Fiado bloqueado'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Este cliente tiene un ciclo de credito vencido por mas de 60 dias en este negocio. El fiado esta bloqueado.',
                ),
                const SizedBox(height: 12),
                Text(
                  'Saldo pendiente: ${MoneyFormatter.formatCurrency(ciclo.saldoPendiente, symbol: 'US\$')}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: motivoController,
                  decoration: const InputDecoration(
                    labelText: 'Motivo opcional',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  final motivo = motivoController.text.trim();
                  Navigator.pop(context, motivo.isEmpty ? '' : motivo);
                },
                child: const Text('Fiar de todos modos'),
              ),
            ],
          );
        },
      );
    } finally {
      motivoController.dispose();
    }
    return resultado;
  }

  void registrarPago() {
    String monto = '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: Text('Pago de ${widget.cliente.nombre}'),
          content: TextField(
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monto',
              prefixText: 'RD\$ ',
            ),
            onChanged: (value) => monto = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final pago = double.tryParse(monto) ?? 0;

                if (pago <= 0 || pago > widget.cliente.deuda) {
                  return;
                }

                final deudaAnterior = widget.cliente.deuda;
                final nuevaDeuda = deudaAnterior - pago;
                final movimiento = Movimiento(
                  clienteId: widget.cliente.id,
                  nombreCliente: widget.cliente.nombre,
                  clienteTelefono: widget.cliente.telefono,
                  tipo: 'pago',
                  monto: pago,
                  fecha: DateTime.now(),
                );

                await ref
                    .read(clientesProvider.notifier)
                    .actualizarCliente(
                      cliente: Cliente(
                        id: widget.cliente.id,
                        nombre: widget.cliente.nombre,
                        telefono: widget.cliente.telefono,
                        deuda: nuevaDeuda,
                      ),
                    );
                final movimientoId = await ref
                    .read(movimientosProvider.notifier)
                    .guardarMovimiento(
                      movimiento,
                      clienteTelefono: widget.cliente.telefono,
                    );
                final movimientoGuardado = Movimiento(
                  id: movimientoId,
                  clienteId: widget.cliente.id,
                  nombreCliente: movimiento.nombreCliente,
                  clienteTelefono: widget.cliente.telefono,
                  tipo: movimiento.tipo,
                  monto: movimiento.monto,
                  fecha: movimiento.fecha,
                  concepto: movimiento.concepto,
                );
                await _crearOObtenerComprobante(
                  movimiento: movimientoGuardado,
                  items: const [],
                  saldoAnterior: deudaAnterior,
                  saldoNuevo: nuevaDeuda,
                );
                if (!mounted || !context.mounted) return;
                setState(() {
                  widget.cliente.deuda = nuevaDeuda;
                  widget.historial.add(movimientoGuardado);
                });
                _invalidarCreditoCliente();

                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Registrar'),
            ),
          ],
        );
      },
    );
  }

  void _invalidarCreditoCliente() {
    final key = (
      telefono: widget.cliente.telefono,
      nombre: widget.cliente.nombre,
    );
    ref.invalidate(cicloActualClienteProvider(key));
    ref.invalidate(ciclosClienteProvider(key));
    ref.invalidate(cuentasPorCobrarProvider);
    ref.invalidate(ciclosMoraProvider);
    ref.invalidate(ciclosBloqueadosProvider);
  }

  void editarCliente() {
    String nombre = widget.cliente.nombre;
    String telefono = widget.cliente.telefono;

    final nombreController = TextEditingController(text: widget.cliente.nombre);
    final telefonoController = TextEditingController(
      text: widget.cliente.telefono,
    );
    final screenContext = context;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: const Text('Editar cliente'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                onChanged: (value) => nombre = value,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: telefonoController,
                decoration: const InputDecoration(
                  labelText: 'Telefono',
                  prefixIcon: Icon(Icons.phone_outlined),
                  counterText: '',
                ),
                keyboardType: TextInputType.number,
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onChanged: (value) => telefono = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final nombreAnterior = widget.cliente.nombre;
                final telefonoAnterior = widget.cliente.telefono;
                final nombreLimpio = nombre.trim();
                final telefonoLimpio = telefono.trim();

                if (nombreLimpio.isEmpty) {
                  return;
                }

                if (!telefonoValido(telefonoLimpio)) {
                  mostrarErrorTelefono();
                  return;
                }

                final clienteAntes = Cliente(
                  id: widget.cliente.id,
                  nombre: widget.cliente.nombre,
                  telefono: widget.cliente.telefono,
                  deuda: widget.cliente.deuda,
                );
                final clienteDespues = Cliente(
                  id: widget.cliente.id,
                  nombre: nombreLimpio,
                  telefono: telefonoLimpio,
                  deuda: widget.cliente.deuda,
                );

                final solicitado = await _solicitarOCambiarCliente(
                  tipoSolicitud:
                      SolicitudAutorizacionSqliteModel.tipoEditarCliente,
                  clienteAntes: clienteAntes,
                  clienteDespues: clienteDespues,
                  accionDirecta: () async {
                    setState(() {
                      widget.cliente.nombre = nombreLimpio;
                      widget.cliente.telefono = telefonoLimpio;
                    });

                    await ref
                        .read(clientesProvider.notifier)
                        .actualizarCliente(
                          cliente: Cliente(
                            id: widget.cliente.id,
                            nombre: widget.cliente.nombre,
                            telefono: widget.cliente.telefono,
                            deuda: widget.cliente.deuda,
                          ),
                          telefonoAnterior: telefonoAnterior,
                        );

                    if (nombreAnterior != nombreLimpio) {
                      ref.invalidate(movimientosProvider);
                    }
                  },
                );

                if (mounted && context.mounted) {
                  Navigator.pop(context);
                  if (!screenContext.mounted) return;
                  ScaffoldMessenger.of(screenContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        solicitado
                            ? 'Solicitud de edicion enviada al negocio.'
                            : 'Cliente actualizado.',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Guardar cambios'),
            ),
          ],
        );
      },
    ).whenComplete(() {
      nombreController.dispose();
      telefonoController.dispose();
    });
  }

  void eliminarCliente() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: const Text('Eliminar cliente'),
          content: Text(
            'Se eliminara a ${widget.cliente.nombre} junto con su historial. Deseas continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB42318),
                foregroundColor: Colors.white,
              ),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    final solicitado = await _solicitarOCambiarCliente(
      tipoSolicitud: SolicitudAutorizacionSqliteModel.tipoEliminarCliente,
      clienteAntes: widget.cliente,
      clienteDespues: widget.cliente,
      accionDirecta: () async {
        widget.clientes.remove(widget.cliente);
        widget.historial.removeWhere(_movimientoPerteneceAlCliente);

        await ref
            .read(movimientosProvider.notifier)
            .eliminarPorCliente(
              widget.cliente.nombre,
              clienteId: widget.cliente.id,
              clienteTelefono: widget.cliente.telefono,
            );
        await ref
            .read(clientesProvider.notifier)
            .eliminarCliente(widget.cliente);
      },
    );

    if (mounted) {
      if (solicitado) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitud de eliminacion enviada al negocio.'),
          ),
        );
      } else {
        Navigator.pop(context, true);
      }
    }
  }

  Future<bool> _solicitarOCambiarCliente({
    required String tipoSolicitud,
    required Cliente clienteAntes,
    required Cliente clienteDespues,
    required Future<void> Function() accionDirecta,
  }) async {
    final user = ref.read(currentUserProvider);
    final esColaborador =
        user?.tipoUsuario == UsuarioSqliteModel.tipoColaborador;

    if (!esColaborador) {
      await accionDirecta();
      return false;
    }

    if (user?.id == null || user?.negocioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo identificar el negocio asociado.'),
        ),
      );
      return true;
    }

    await ref
        .read(solicitudAutorizacionRepositoryProvider)
        .crearSolicitud(
          negocioId: user!.negocioId!,
          colaboradorId: user.id!,
          tipoSolicitud: tipoSolicitud,
          entidad: SolicitudAutorizacionSqliteModel.entidadCliente,
          datosAntes: jsonEncode(clienteAntes.toJson()),
          datosDespues: jsonEncode(clienteDespues.toJson()),
        );
    ref.invalidate(solicitudesColaboradorProvider);
    ref.invalidate(solicitudesPendientesProvider);
    ref.invalidate(solicitudesPendientesCountProvider);
    return true;
  }

  bool _movimientoPerteneceAlCliente(Movimiento movimiento) {
    final clienteId = widget.cliente.id;
    if (clienteId != null && movimiento.clienteId != null) {
      return movimiento.clienteId == clienteId;
    }
    return movimiento.clienteTelefono == widget.cliente.telefono ||
        movimiento.clienteTelefonoSnapshot == widget.cliente.telefono ||
        movimiento.nombreCliente == widget.cliente.nombre;
  }

  Future<void> _mostrarDetalleDeuda(
    Movimiento movimiento, {
    double? subtotalMercancias,
    double? ajusteManual,
    double? abonoInicial,
  }) async {
    final negocioId = ref.read(currentBusinessIdProvider);
    final items = movimiento.id == null
        ? const <DeudaItemSqliteModel>[]
        : await ref
              .read(deudaItemRepositoryProvider)
              .obtenerItemsPorMovimiento(movimiento.id!, negocioId: negocioId);
    final subtotal =
        subtotalMercancias ??
        items.fold<double>(0, (total, item) => total + item.subtotal);
    final ajuste =
        ajusteManual ?? (items.isEmpty ? 0 : movimiento.monto - subtotal);
    final abono =
        abonoInicial ??
        (items.isEmpty || subtotal <= movimiento.monto
            ? 0
            : subtotal - movimiento.monto);
    debugPrint(
      '[deuda-items] detalle movimientoId=${movimiento.id} negocioId=$negocioId items=${items.length} subtotal=$subtotal montoFinal=${movimiento.monto}',
    );

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text('Detalle de deuda'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetalleDeudaDato(
                    label: 'Fecha',
                    value:
                        '${movimiento.fecha.day}/${movimiento.fecha.month}/${movimiento.fecha.year}',
                  ),
                  _DetalleDeudaDato(
                    label: 'Concepto',
                    value: movimiento.concepto?.trim().isNotEmpty ?? false
                        ? movimiento.concepto!.trim()
                        : 'Sin descripcion',
                  ),
                  _DetalleDeudaDato(
                    label: 'Monto final',
                    value: MoneyFormatter.formatCurrency(movimiento.monto),
                  ),
                  if (items.isNotEmpty) ...[
                    _DetalleDeudaDato(
                      label: 'Subtotal mercancias',
                      value: MoneyFormatter.formatCurrency(subtotal),
                    ),
                    if (ajuste.abs() > 0.01)
                      _DetalleDeudaDato(
                        label: ajuste > 0
                            ? 'Ajuste adicional'
                            : 'Ajuste manual',
                        value: MoneyFormatter.formatCurrency(ajuste),
                      ),
                    if (abono > 0.01)
                      _DetalleDeudaDato(
                        label: 'Abono inicial',
                        value: MoneyFormatter.formatCurrency(abono),
                      ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'Mercancias',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF17322C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (items.isEmpty)
                    const Text(
                      'Esta deuda no tiene detalle de mercancias registrado.',
                    )
                  else
                    for (final item in items)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F3EA),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.codigoReferencia == null
                                  ? item.nombreProducto
                                  : '${item.nombreProducto} (${item.codigoReferencia})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 12,
                              runSpacing: 6,
                              children: [
                                Text('Cantidad: ${item.cantidad}'),
                                Text(
                                  'Precio: ${MoneyFormatter.formatCurrency(item.precioUnitario)}',
                                ),
                                Text(
                                  'Subtotal: ${MoneyFormatter.formatCurrency(item.subtotal)}',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await _abrirComprobante(movimiento: movimiento, items: items);
              },
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Ver comprobante'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _darToque(CreditoCicloSqliteModel ciclo) async {
    final negocioNombre = await _nombreNegocioActual() ?? 'tu negocio';
    await ref
        .read(creditoCicloRepositoryProvider)
        .generarToqueManual(
          ciclo: ciclo,
          nombreCliente: widget.cliente.nombre,
          nombreNegocio: negocioNombre,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recordatorio preparado para el cliente.')),
    );
  }

  Future<void> _abrirWhatsAppCiclo(CreditoCicloSqliteModel ciclo) async {
    final negocioNombre = await _nombreNegocioActual() ?? 'tu negocio';
    final mensaje = CreditoMensajeService.mensajePorEstado(
      ciclo: ciclo,
      nombreCliente: widget.cliente.nombre,
      nombreNegocio: negocioNombre,
    );
    await CreditoMensajeService.abrirWhatsAppConMensaje(
      telefono: widget.cliente.telefono,
      mensaje: mensaje,
    );
  }

  @override
  Widget build(BuildContext context) {
    final historialCliente =
        widget.historial.where(_movimientoPerteneceAlCliente).toList()
          ..sort((a, b) => b.fecha.compareTo(a.fecha));

    final tieneDeuda = widget.cliente.deuda > 0;
    final puedeGestionarDeudas = ref
        .watch(currentPermissionsProvider)
        .canManageClientes;
    final creditoKey = (
      telefono: widget.cliente.telefono,
      nombre: widget.cliente.nombre,
    );
    final cicloActualAsync = ref.watch(cicloActualClienteProvider(creditoKey));

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentPadding = AdaptiveLayout.contentInset(
            constraints.maxWidth,
          );

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 320,
                pinned: true,
                backgroundColor: const Color(0xFFF3EFE7),
                surfaceTintColor: Colors.transparent,
                actions: [
                  IconButton(
                    onPressed: editarCliente,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: eliminarCliente,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsetsDirectional.only(
                    start: 20,
                    bottom: 18,
                    end: 20,
                  ),
                  title: Text(
                    widget.cliente.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(
                          color: Color(0x66000000),
                          blurRadius: 12,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFF3EFE7), Color(0xFFE6F0ED)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final bool mostrarResumen = constraints.maxHeight > 285;

                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                            contentPadding,
                            96,
                            contentPadding,
                            20,
                          ),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: mostrarResumen
                                ? Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF17322C),
                                          Color(0xFF1F7A6B),
                                        ],
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
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.14,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            tieneDeuda
                                                ? 'Cuenta pendiente'
                                                : 'Cuenta al dia',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    widget.cliente.telefono,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Color(0xFFDCE9E5),
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Flexible(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Text(
                                                      MoneyFormatter.formatCurrency(
                                                        widget.cliente.deuda,
                                                      ),
                                                      maxLines: 1,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 26,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        letterSpacing: 0,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  const Text(
                                                    'Monto adeudado',
                                                    textAlign: TextAlign.end,
                                                    style: TextStyle(
                                                      color: Color(0xFFDCE9E5),
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    contentPadding,
                    18,
                    contentPadding,
                    10,
                  ),
                  child: constraints.maxWidth < AdaptiveLayout.compactWidth
                      ? Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: puedeGestionarDeudas
                                    ? agregarDeuda
                                    : null,
                                icon: const Icon(Icons.add_card_outlined),
                                label: const Text('Agregar deuda'),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: puedeGestionarDeudas
                                    ? registrarPago
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE7B04B),
                                  foregroundColor: const Color(0xFF17322C),
                                ),
                                icon: const Icon(Icons.payments_outlined),
                                label: const Text('Registrar pago'),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _abrirScoreCliente,
                                icon: const Icon(Icons.insights_outlined),
                                label: const Text('Score inteligente'),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: puedeGestionarDeudas
                                    ? agregarDeuda
                                    : null,
                                icon: const Icon(Icons.add_card_outlined),
                                label: const Text('Agregar deuda'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: puedeGestionarDeudas
                                    ? registrarPago
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE7B04B),
                                  foregroundColor: const Color(0xFF17322C),
                                ),
                                icon: const Icon(Icons.payments_outlined),
                                label: const Text('Registrar pago'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _abrirScoreCliente,
                                icon: const Icon(Icons.insights_outlined),
                                label: const Text('Score inteligente'),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    contentPadding,
                    6,
                    contentPadding,
                    12,
                  ),
                  child: cicloActualAsync.when(
                    data: (ciclo) => ciclo == null
                        ? const _CreditoCicloAlDiaCard()
                        : _CreditoCicloEstadoCard(
                            ciclo: ciclo,
                            clienteNombre: widget.cliente.nombre,
                            clienteTelefono: widget.cliente.telefono,
                            negocioNombre:
                                ref.read(currentUserProvider)?.nombre ??
                                'tu negocio',
                            onDarToque: () => _darToque(ciclo),
                            onWhatsApp: () => _abrirWhatsAppCiclo(ciclo),
                            onFiarDeTodosModos:
                                ciclo.estado == CreditoCicloEstado.bloqueado60
                                ? agregarDeuda
                                : null,
                          ),
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) =>
                        Text('No se pudo cargar el ciclo de credito: $error'),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    contentPadding,
                    12,
                    contentPadding,
                    12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Historial',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF17322C),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        historialCliente.isEmpty
                            ? 'Todavia no hay movimientos registrados.'
                            : 'Movimientos mas recientes del cliente.',
                        style: const TextStyle(
                          color: Color(0xFF66756D),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              historialCliente.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 42,
                                  color: Color(0xFF1F7A6B),
                                ),
                                SizedBox(height: 14),
                                Text(
                                  'Sin movimientos',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF17322C),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Cuando registres una deuda o un pago, aparecera aqui.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Color(0xFF66756D)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        contentPadding,
                        0,
                        contentPadding,
                        32,
                      ),
                      sliver: SliverList.builder(
                        itemCount: historialCliente.length,
                        itemBuilder: (context, index) {
                          final mov = historialCliente[index];
                          final esPago = mov.tipo == 'pago';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: esPago
                                  ? () => _abrirComprobante(movimiento: mov)
                                  : () => _mostrarDetalleDeuda(mov),
                              child: Container(
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
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: esPago
                                            ? const Color(0xFFE7F3EF)
                                            : const Color(0xFFFDEAE5),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(
                                        esPago
                                            ? Icons.south_west_rounded
                                            : Icons.north_east_rounded,
                                        color: esPago
                                            ? const Color(0xFF1F7A6B)
                                            : const Color(0xFFB54708),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            esPago
                                                ? 'Pago registrado'
                                                : (mov.concepto
                                                          ?.trim()
                                                          .isNotEmpty ??
                                                      false)
                                                ? mov.concepto!.trim()
                                                : 'Nueva deuda',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF17322C),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${mov.fecha.day}/${mov.fecha.month}/${mov.fecha.year}',
                                            style: const TextStyle(
                                              color: Color(0xFF66756D),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      MoneyFormatter.formatCurrency(mov.monto),
                                      style: TextStyle(
                                        color: esPago
                                            ? const Color(0xFF1F7A6B)
                                            : const Color(0xFFB42318),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }

  void _abrirScoreCliente() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientScoreScreen(cliente: widget.cliente),
      ),
    );
  }
}
