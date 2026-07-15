import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/money_formatter.dart';
import '../data/models/solicitud_autorizacion_sqlite_model.dart';
import '../data/models/usuario_sqlite_model.dart';
import '../models/cliente.dart';
import '../models/movimiento.dart';
import '../presentation/providers/auth_providers.dart';
import '../presentation/providers/fiado_data_providers.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/cliente_search_dialog.dart';
import 'detalle_cliente_screen.dart';
import 'historial_cliente_screen.dart';
import 'historial_screen.dart';
import 'inventario_screen.dart';

class ClientesScreen extends ConsumerStatefulWidget {
  const ClientesScreen({super.key});

  @override
  ConsumerState<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesAccesoDenegado extends StatelessWidget {
  const _ClientesAccesoDenegado();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No tienes permiso para acceder a clientes, deudas o pagos.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _ClientesScreenState extends ConsumerState<ClientesScreen> {
  Future<String?> _nombreNegocioActual() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return null;
    if (user.tipoUsuario == UsuarioSqliteModel.tipoNegocio) return user.nombre;
    final negocioId = user.negocioId;
    if (negocioId == null) return user.nombre;
    final negocio = await ref
        .read(authRepositoryProvider)
        .obtenerUsuarioPorId(negocioId);
    return negocio?.nombre ?? user.nombre;
  }

  bool telefonoValido(String telefono) {
    return RegExp(r'^\d{10}$').hasMatch(telefono);
  }

  List<Cliente> get clientes =>
      ref.read(clientesProvider).valueOrNull?.clientes ?? const [];

  List<Movimiento> get historial =>
      ref.read(movimientosProvider).valueOrNull ?? const [];

  void mostrarErrorTelefono() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('El telefono debe tener exactamente 10 digitos.'),
      ),
    );
  }

  void agregarCliente(Cliente cliente) async {
    await ref.read(clientesProvider.notifier).guardarCliente(cliente);
  }

  Cliente? buscarClientePorTelefono(String telefono, {Cliente? excluir}) {
    for (final cliente in clientes) {
      if (identical(cliente, excluir)) {
        continue;
      }

      if (cliente.telefono == telefono) {
        return cliente;
      }
    }

    return null;
  }

  Future<void> mostrarTelefonoDuplicado(Cliente cliente) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: const Text('Telefono ya registrado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ese numero ya pertenece a un cliente registrado.'),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F6F0),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFD9E8E3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cliente.nombre,
                      style: const TextStyle(
                        color: Color(0xFF17322C),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cliente.telefono,
                      style: const TextStyle(color: Color(0xFF66756D)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  Future<void> mostrarFormulario() async {
    String nombre = '';
    String telefono = '';
    final nombreController = TextEditingController();
    final telefonoController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: const Text('Nuevo cliente'),
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
                final nombreLimpio = nombre.trim();
                final telefonoLimpio = telefono.trim();

                if (nombreLimpio.isEmpty) {
                  return;
                }

                if (!telefonoValido(telefonoLimpio)) {
                  mostrarErrorTelefono();
                  return;
                }

                final clienteExistente = buscarClientePorTelefono(
                  telefonoLimpio,
                );
                if (clienteExistente != null) {
                  telefono = '';
                  telefonoController.clear();
                  await mostrarTelefonoDuplicado(clienteExistente);
                  return;
                }

                agregarCliente(
                  Cliente(nombre: nombreLimpio, telefono: telefonoLimpio),
                );
                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    Future<void>.delayed(const Duration(milliseconds: 400), () {
      nombreController.dispose();
      telefonoController.dispose();
    });
  }

  Future<void> mostrarEditarCliente(Cliente cliente) async {
    String nombre = cliente.nombre;
    String telefono = cliente.telefono;

    final nombreController = TextEditingController(text: cliente.nombre);
    final telefonoController = TextEditingController(text: cliente.telefono);

    await showDialog<void>(
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
                final nombreAnterior = cliente.nombre;
                final nombreLimpio = nombre.trim();
                final telefonoLimpio = telefono.trim();

                if (nombreLimpio.isEmpty) {
                  return;
                }

                if (!telefonoValido(telefonoLimpio)) {
                  mostrarErrorTelefono();
                  return;
                }

                final clienteExistente = buscarClientePorTelefono(
                  telefonoLimpio,
                  excluir: cliente,
                );
                if (clienteExistente != null) {
                  mostrarTelefonoDuplicado(clienteExistente);
                  return;
                }

                final clienteActualizado = Cliente(
                  id: cliente.id,
                  nombre: nombreLimpio,
                  telefono: telefonoLimpio,
                  deuda: cliente.deuda,
                );

                final solicitado = await _solicitarOCambiarCliente(
                  tipoSolicitud:
                      SolicitudAutorizacionSqliteModel.tipoEditarCliente,
                  clienteAntes: cliente,
                  clienteDespues: clienteActualizado,
                  accionDirecta: () async {
                    await ref
                        .read(clientesProvider.notifier)
                        .actualizarCliente(
                          cliente: clienteActualizado,
                          telefonoAnterior: cliente.telefono,
                        );

                    if (nombreAnterior != nombreLimpio) {
                      ref.invalidate(movimientosProvider);
                    }
                  },
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
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
    );
  }

  void eliminarCliente(Cliente cliente) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: const Text('Eliminar cliente'),
          content: Text(
            'Se eliminara a ${cliente.nombre} junto con su historial. Deseas continuar?',
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
      clienteAntes: cliente,
      clienteDespues: cliente,
      accionDirecta: () async {
        await ref
            .read(movimientosProvider.notifier)
            .eliminarPorCliente(
              cliente.nombre,
              clienteId: cliente.id,
              clienteTelefono: cliente.telefono,
            );
        await ref.read(clientesProvider.notifier).eliminarCliente(cliente);
      },
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            solicitado
                ? 'Solicitud de eliminacion enviada al negocio.'
                : 'Cliente eliminado.',
          ),
        ),
      );
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

  void mostrarOpcionesCliente(Cliente cliente) {
    final user = ref.read(currentUserProvider);
    final esColaborador =
        user?.tipoUsuario == UsuarioSqliteModel.tipoColaborador;
    final puedeGestionarDeudas = ref
        .read(currentPermissionsProvider)
        .canManageClientes;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Wrap(
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8D3C7),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(
                    esColaborador
                        ? 'Solicitar editar cliente'
                        : 'Editar cliente',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    mostrarEditarCliente(cliente);
                  },
                ),
                if (puedeGestionarDeudas)
                  ListTile(
                    leading: const Icon(Icons.add_card_outlined),
                    title: const Text('Agregar deuda'),
                    onTap: () {
                      Navigator.pop(context);
                      mostrarAgregarDeuda(cliente);
                    },
                  ),
                if (puedeGestionarDeudas)
                  ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: const Text('Registrar pago'),
                    onTap: () {
                      Navigator.pop(context);
                      mostrarRegistrarPago(cliente);
                    },
                  ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFB42318),
                  ),
                  title: const Text('Eliminar cliente'),
                  subtitle: esColaborador
                      ? const Text('Requiere aprobacion del negocio')
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    eliminarCliente(cliente);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void mostrarAgregarDeuda(Cliente cliente) {
    String monto = '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: Text('Agregar deuda a ${cliente.nombre}'),
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

                final movimiento = Movimiento(
                  clienteId: cliente.id,
                  nombreCliente: cliente.nombre,
                  clienteTelefono: cliente.telefono,
                  tipo: 'deuda',
                  monto: valor,
                  fecha: DateTime.now(),
                );
                final nuevoSaldo = cliente.deuda + valor;
                await ref
                    .read(clientesProvider.notifier)
                    .actualizarCliente(
                      cliente: Cliente(
                        id: cliente.id,
                        nombre: cliente.nombre,
                        telefono: cliente.telefono,
                        deuda: nuevoSaldo,
                      ),
                    );
                final movimientoId = await ref
                    .read(movimientosProvider.notifier)
                    .guardarMovimiento(
                      movimiento,
                      clienteTelefono: cliente.telefono,
                    );
                final user = ref.read(currentUserProvider);
                final negocioId = ref.read(currentBusinessIdProvider);
                if (negocioId == null) return;
                await ref
                    .read(comprobanteRepositoryProvider)
                    .crearComprobanteDeuda(
                      negocioId: negocioId,
                      movimientoId: movimientoId,
                      clienteNombre: cliente.nombre,
                      clienteTelefono: cliente.telefono,
                      negocioNombre: await _nombreNegocioActual(),
                      fecha: movimiento.fecha,
                      concepto: movimiento.concepto,
                      productos: const [],
                      total: valor,
                      saldoPendiente: nuevoSaldo,
                      creadoPorUsuarioId: user?.id,
                      creadoPorNombre: user?.nombre,
                    );

                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }

  void mostrarRegistrarPago(Cliente cliente) {
    String monto = '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: Text('Pago de ${cliente.nombre}'),
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

                if (pago <= 0 || pago > cliente.deuda) {
                  return;
                }

                final saldoAnterior = cliente.deuda;
                final saldoNuevo = saldoAnterior - pago;
                final movimiento = Movimiento(
                  clienteId: cliente.id,
                  nombreCliente: cliente.nombre,
                  clienteTelefono: cliente.telefono,
                  tipo: 'pago',
                  monto: pago,
                  fecha: DateTime.now(),
                );
                await ref
                    .read(clientesProvider.notifier)
                    .actualizarCliente(
                      cliente: Cliente(
                        id: cliente.id,
                        nombre: cliente.nombre,
                        telefono: cliente.telefono,
                        deuda: saldoNuevo,
                      ),
                    );
                final movimientoId = await ref
                    .read(movimientosProvider.notifier)
                    .guardarMovimiento(
                      movimiento,
                      clienteTelefono: cliente.telefono,
                    );
                final user = ref.read(currentUserProvider);
                final negocioId = ref.read(currentBusinessIdProvider);
                if (negocioId == null) return;
                await ref
                    .read(comprobanteRepositoryProvider)
                    .crearComprobantePago(
                      negocioId: negocioId,
                      movimientoId: movimientoId,
                      clienteNombre: cliente.nombre,
                      clienteTelefono: cliente.telefono,
                      negocioNombre: await _nombreNegocioActual(),
                      fecha: movimiento.fecha,
                      montoPagado: pago,
                      deudaAnterior: saldoAnterior,
                      saldoNuevo: saldoNuevo,
                      creadoPorUsuarioId: user?.id,
                      creadoPorNombre: user?.nombre,
                    );

                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Registrar'),
            ),
          ],
        );
      },
    );
  }

  double get deudaTotal {
    return clientes.fold(0, (total, cliente) => total + cliente.deuda);
  }

  int get clientesConDeuda {
    return clientes.where((cliente) => cliente.deuda > 0).length;
  }

  Future<void> buscarCliente() async {
    final textoController = TextEditingController(
      text: ref.read(clienteBusquedaProvider),
    );

    final busqueda = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: const Text('Buscar cliente'),
          content: TextField(
            controller: textoController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nombre o telefono',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('Limpiar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, textoController.text),
              child: const Text('Buscar'),
            ),
          ],
        );
      },
    );

    Future<void>.delayed(const Duration(milliseconds: 400), () {
      textoController.dispose();
    });

    if (busqueda == null || !mounted) {
      return;
    }

    ref.read(clienteBusquedaProvider.notifier).state = busqueda.trim();
    final resultado = await ref.read(clientesProvider.future);

    if (!mounted) {
      return;
    }

    final cliente = await showClienteSearchDialog(
      context: context,
      clientes: resultado.clientes,
    );

    if (cliente == null || !mounted) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            HistorialClienteScreen(cliente: cliente, historial: historial),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(currentPermissionsProvider);
    if (!permissions.canViewClientes) {
      return const _ClientesAccesoDenegado();
    }

    final clientesAsync = ref.watch(clientesProvider);
    final movimientosAsync = ref.watch(movimientosProvider);
    final clientesState = clientesAsync.valueOrNull;
    final clientes = clientesState?.clientes ?? const <Cliente>[];
    final historial = movimientosAsync.valueOrNull ?? const <Movimiento>[];
    final textTheme = Theme.of(context).textTheme;
    final deudaPendiente = clientes.fold<double>(
      0,
      (total, cliente) => total + cliente.deuda,
    );
    final clientesConSaldo = clientes
        .where((cliente) => cliente.deuda > 0)
        .length;
    final pagosRegistrados = historial
        .where((movimiento) => movimiento.tipo == 'pago')
        .length;
    final pagosTotal = historial
        .where((movimiento) => movimiento.tipo == 'pago')
        .fold<double>(0, (total, movimiento) => total + movimiento.monto);

    if (clientesAsync.hasError && clientesState == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFB42318),
                    size: 42,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No se pudieron cargar los clientes',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF17322C),
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(clientesProvider.notifier).recargar();
                      ref.read(movimientosProvider.notifier).recargar();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (clientesAsync.isLoading && clientesState == null) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: mostrarFormulario,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nuevo cliente'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentPadding = AdaptiveLayout.contentInset(
              constraints.maxWidth,
            );

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      contentPadding,
                      18,
                      contentPadding,
                      14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (Navigator.canPop(context)) ...[
                              _HeaderActionButton(
                                icon: Icons.arrow_back_rounded,
                                tooltip: 'Volver',
                                onPressed: () => Navigator.pop(context),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Clientes',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF17322C),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Administra deudas, pagos y seguimiento diario.',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: const Color(0xFF66756D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _HeaderActionButton(
                              icon: Icons.search_rounded,
                              tooltip: 'Buscar cliente',
                              onPressed: buscarCliente,
                            ),
                            _HeaderActionButton(
                              icon: Icons.refresh_rounded,
                              tooltip: 'Recargar',
                              onPressed: () {
                                ref.read(clientesProvider.notifier).recargar();
                                ref
                                    .read(movimientosProvider.notifier)
                                    .recargar();
                              },
                            ),
                            _HeaderActionButton(
                              icon: Icons.inventory_2_outlined,
                              tooltip: 'Inventario',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const InventarioScreen(),
                                  ),
                                );
                              },
                            ),
                            _HeaderActionButton(
                              icon: Icons.history_rounded,
                              tooltip: 'Historial',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => HistorialScreen(
                                      historial: historial,
                                      clientes: clientes,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
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
                              Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.groups_2_outlined,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Resumen de cartera',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          clientesConSaldo == 0
                                              ? 'Cartera sin saldos pendientes'
                                              : '$clientesConSaldo clientes requieren seguimiento',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFFDCE9E5),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Saldo total pendiente',
                                      style: TextStyle(
                                        color: Color(0xFFDCE9E5),
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        MoneyFormatter.formatCurrency(
                                          deudaPendiente,
                                        ),
                                        maxLines: 1,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 30,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final crossAxisCount =
                                      constraints.maxWidth >= 720
                                      ? 4
                                      : constraints.maxWidth >= 360
                                      ? 2
                                      : 1;
                                  final tiles = [
                                    _MetricTile(
                                      icon: Icons.people_alt_outlined,
                                      label: 'Clientes',
                                      value: '${clientes.length}',
                                    ),
                                    _MetricTile(
                                      icon:
                                          Icons.account_balance_wallet_outlined,
                                      label: 'Con saldo',
                                      value: '$clientesConSaldo',
                                    ),
                                    _MetricTile(
                                      icon: Icons.payments_outlined,
                                      label: 'Pagos',
                                      value: '$pagosRegistrados',
                                    ),
                                    _MetricTile(
                                      icon: Icons.receipt_long_outlined,
                                      label: 'Pagado',
                                      value: MoneyFormatter.formatCurrency(
                                        pagosTotal,
                                      ),
                                    ),
                                  ];

                                  return GridView.count(
                                    crossAxisCount: crossAxisCount,
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: crossAxisCount == 1
                                        ? 3.3
                                        : 1.95,
                                    children: tiles,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Tu cartera',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF17322C),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          clientes.isEmpty
                              ? 'Agrega tu primer cliente para empezar.'
                              : 'Manten pulsado sobre una tarjeta para ver acciones rapidas.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF66756D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                clientes.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 86,
                                  height: 86,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  child: const Icon(
                                    Icons.groups_2_outlined,
                                    size: 40,
                                    color: Color(0xFF1F7A6B),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'No hay clientes registrados',
                                  style: textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF17322C),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Crea tu primer cliente y empieza a llevar el control del fiado con una vista mucho mas clara.',
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF66756D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          contentPadding,
                          6,
                          contentPadding,
                          110,
                        ),
                        sliver: SliverList.builder(
                          itemCount:
                              clientes.length +
                              ((clientesState?.hasMore ?? false) ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= clientes.length) {
                              final isLoadingMore =
                                  clientesState?.isLoadingMore ?? false;

                              return Padding(
                                padding: const EdgeInsets.only(
                                  top: 4,
                                  bottom: 14,
                                ),
                                child: Center(
                                  child: OutlinedButton.icon(
                                    onPressed: isLoadingMore
                                        ? null
                                        : () => ref
                                              .read(clientesProvider.notifier)
                                              .cargarMas(),
                                    icon: isLoadingMore
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.expand_more_rounded),
                                    label: Text(
                                      isLoadingMore
                                          ? 'Cargando'
                                          : 'Cargar mas clientes',
                                    ),
                                  ),
                                ),
                              );
                            }

                            final cliente = clientes[index];
                            final tieneDeuda = cliente.deuda > 0;
                            final movimientosCliente = historial.where((
                              movimiento,
                            ) {
                              if (cliente.id != null &&
                                  movimiento.clienteId != null) {
                                return movimiento.clienteId == cliente.id;
                              }
                              return movimiento.clienteTelefono ==
                                      cliente.telefono ||
                                  movimiento.clienteTelefonoSnapshot ==
                                      cliente.telefono ||
                                  movimiento.nombreCliente == cliente.nombre;
                            }).length;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(26),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DetalleClienteScreen(
                                        cliente: cliente,
                                        historial: historial,
                                        clientes: clientes,
                                      ),
                                    ),
                                  ).then((_) {
                                    ref
                                        .read(clientesProvider.notifier)
                                        .recargar();
                                    ref
                                        .read(movimientosProvider.notifier)
                                        .recargar();
                                  });
                                },
                                onLongPress: () {
                                  mostrarOpcionesCliente(cliente);
                                },
                                child: Ink(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: tieneDeuda
                                          ? const Color(0xFFF3D6D0)
                                          : const Color(0xFFD9E8E3),
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x12000000),
                                        blurRadius: 18,
                                        offset: Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final compact =
                                          constraints.maxWidth < 430;
                                      final leading = Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          color: tieneDeuda
                                              ? const Color(0xFFFDEAE5)
                                              : const Color(0xFFE7F3EF),
                                        ),
                                        child: Icon(
                                          tieneDeuda
                                              ? Icons.trending_up_rounded
                                              : Icons.verified_rounded,
                                          color: tieneDeuda
                                              ? const Color(0xFFB54708)
                                              : const Color(0xFF1F7A6B),
                                        ),
                                      );
                                      final info = Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              cliente.nombre,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF17322C),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 6,
                                              children: [
                                                _InfoPill(
                                                  icon: Icons.phone_outlined,
                                                  label: cliente.telefono,
                                                ),
                                                _InfoPill(
                                                  icon: Icons.history_rounded,
                                                  label:
                                                      '$movimientosCliente mov.',
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                      final status = _ClienteStatusAmount(
                                        tieneDeuda: tieneDeuda,
                                        deuda: cliente.deuda,
                                        alignEnd: !compact,
                                      );
                                      final detalle = IconButton.filledTonal(
                                        tooltip: 'Ver detalle',
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  DetalleClienteScreen(
                                                    cliente: cliente,
                                                    historial: historial,
                                                    clientes: clientes,
                                                  ),
                                            ),
                                          ).then((_) {
                                            ref
                                                .read(clientesProvider.notifier)
                                                .recargar();
                                            ref
                                                .read(
                                                  movimientosProvider.notifier,
                                                )
                                                .recargar();
                                          });
                                        },
                                        icon: const Icon(
                                          Icons.chevron_right_rounded,
                                        ),
                                      );

                                      if (compact) {
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                leading,
                                                const SizedBox(width: 12),
                                                info,
                                                const SizedBox(width: 6),
                                                detalle,
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            status,
                                          ],
                                        );
                                      }

                                      return Row(
                                        children: [
                                          leading,
                                          const SizedBox(width: 14),
                                          info,
                                          const SizedBox(width: 10),
                                          status,
                                          const SizedBox(width: 4),
                                          detalle,
                                        ],
                                      );
                                    },
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
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricTile({
    required this.icon,
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
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFDCE9E5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FAF8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE4EEE9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF66756D)),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF66756D),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _HeaderActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3DED2)),
        ),
        child: IconButton(
          icon: Icon(icon),
          tooltip: tooltip,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _ClienteStatusAmount extends StatelessWidget {
  final bool tieneDeuda;
  final double deuda;
  final bool alignEnd;

  const _ClienteStatusAmount({
    required this.tieneDeuda,
    required this.deuda,
    required this.alignEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: tieneDeuda
                ? const Color(0xFFFDEAE5)
                : const Color(0xFFE7F3EF),
          ),
          child: Text(
            tieneDeuda ? 'Pendiente' : 'Al dia',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: tieneDeuda
                  ? const Color(0xFFB54708)
                  : const Color(0xFF1F7A6B),
            ),
          ),
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            MoneyFormatter.formatCurrency(deuda),
            maxLines: 1,
            style: TextStyle(
              color: tieneDeuda
                  ? const Color(0xFFB42318)
                  : const Color(0xFF1F7A6B),
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}
