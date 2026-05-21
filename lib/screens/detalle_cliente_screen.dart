// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/cliente.dart';
import '../models/movimiento.dart';
import '../services/storage_service.dart';
import '../widgets/adaptive_layout.dart';

class DetalleClienteScreen extends StatefulWidget {
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
  State<DetalleClienteScreen> createState() => _DetalleClienteScreenState();
}

class _DetalleClienteScreenState extends State<DetalleClienteScreen> {
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

  void agregarDeuda() {
    String monto = '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: Text('Agregar deuda a ${widget.cliente.nombre}'),
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
                final valor = double.tryParse(monto) ?? 0;

                if (valor <= 0) {
                  return;
                }

                setState(() {
                  widget.cliente.deuda += valor;
                  widget.historial.add(
                    Movimiento(
                      nombreCliente: widget.cliente.nombre,
                      tipo: 'deuda',
                      monto: valor,
                      fecha: DateTime.now(),
                    ),
                  );
                });

                await StorageService.guardarClientes(widget.clientes);
                await StorageService.guardarHistorial(widget.historial);

                Navigator.pop(context);
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
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

                setState(() {
                  widget.cliente.deuda -= pago;
                  widget.historial.add(
                    Movimiento(
                      nombreCliente: widget.cliente.nombre,
                      tipo: 'pago',
                      monto: pago,
                      fecha: DateTime.now(),
                    ),
                  );
                });

                await StorageService.guardarClientes(widget.clientes);
                await StorageService.guardarHistorial(widget.historial);

                Navigator.pop(context);
              },
              child: const Text('Registrar'),
            ),
          ],
        );
      },
    );
  }

  void editarCliente() {
    String nombre = widget.cliente.nombre;
    String telefono = widget.cliente.telefono;

    final nombreController = TextEditingController(text: widget.cliente.nombre);
    final telefonoController =
        TextEditingController(text: widget.cliente.telefono);

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
                final nombreLimpio = nombre.trim();
                final telefonoLimpio = telefono.trim();

                if (nombreLimpio.isEmpty) {
                  return;
                }

                if (!telefonoValido(telefonoLimpio)) {
                  mostrarErrorTelefono();
                  return;
                }

                setState(() {
                  widget.cliente.nombre = nombreLimpio;
                  widget.cliente.telefono = telefonoLimpio;

                  for (final movimiento in widget.historial) {
                    if (movimiento.nombreCliente == nombreAnterior) {
                      movimiento.nombreCliente = nombreLimpio;
                    }
                  }
                });

                await StorageService.guardarClientes(widget.clientes);
                await StorageService.guardarHistorial(widget.historial);

                if (mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Guardar cambios'),
            ),
          ],
        );
      },
    );
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

    widget.clientes.remove(widget.cliente);
    widget.historial.removeWhere(
      (movimiento) => movimiento.nombreCliente == widget.cliente.nombre,
    );

    await StorageService.guardarClientes(widget.clientes);
    await StorageService.guardarHistorial(widget.historial);

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final historialCliente = widget.historial
        .where((m) => m.nombreCliente == widget.cliente.nombre)
        .toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));

    final tieneDeuda = widget.cliente.deuda > 0;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentPadding =
              AdaptiveLayout.contentInset(constraints.maxWidth);

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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                        borderRadius: BorderRadius.circular(999),
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
                                                overflow: TextOverflow.ellipsis,
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
                                                  'RD\$${widget.cliente.deuda.toStringAsFixed(2)}',
                                                  maxLines: 1,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 26,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: -1,
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
                            onPressed: agregarDeuda,
                            icon: const Icon(Icons.add_card_outlined),
                            label: const Text('Agregar deuda'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: registrarPago,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE7B04B),
                              foregroundColor: const Color(0xFF17322C),
                            ),
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Registrar pago'),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: agregarDeuda,
                            icon: const Icon(Icons.add_card_outlined),
                            label: const Text('Agregar deuda'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: registrarPago,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE7B04B),
                              foregroundColor: const Color(0xFF17322C),
                            ),
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Registrar pago'),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      esPago ? 'Pago registrado' : 'Nueva deuda',
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
                                'RD\$${mov.monto.toStringAsFixed(2)}',
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
}
