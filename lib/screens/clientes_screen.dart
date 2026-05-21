import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/cliente.dart';
import '../models/movimiento.dart';
import '../services/storage_service.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/cliente_search_dialog.dart';
import 'detalle_cliente_screen.dart';
import 'historial_cliente_screen.dart';
import 'historial_screen.dart';
import 'inventario_screen.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  List<Cliente> clientes = [];
  List<Movimiento> historial = [];

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

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  void cargarDatos() async {
    clientes = await StorageService.cargarClientes();
    historial = await StorageService.cargarHistorial();
    setState(() {});
  }

  void agregarCliente(Cliente cliente) async {
    setState(() {
      clientes.add(cliente);
    });
    await StorageService.guardarClientes(clientes);
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
              const Text(
                'Ese numero ya pertenece a un cliente registrado.',
              ),
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

                final clienteExistente =
                    buscarClientePorTelefono(telefonoLimpio);
                if (clienteExistente != null) {
                  telefono = '';
                  telefonoController.clear();
                  await mostrarTelefonoDuplicado(clienteExistente);
                  return;
                }

                agregarCliente(
                  Cliente(
                    nombre: nombreLimpio,
                    telefono: telefonoLimpio,
                  ),
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

                setState(() {
                  cliente.nombre = nombreLimpio;
                  cliente.telefono = telefonoLimpio;

                  for (final movimiento in historial) {
                    if (movimiento.nombreCliente == nombreAnterior) {
                      movimiento.nombreCliente = nombreLimpio;
                    }
                  }
                });

                await StorageService.guardarClientes(clientes);
                await StorageService.guardarHistorial(historial);

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

    setState(() {
      clientes.remove(cliente);
      historial.removeWhere((m) => m.nombreCliente == cliente.nombre);
    });

    await StorageService.guardarClientes(clientes);
    await StorageService.guardarHistorial(historial);
  }

  void mostrarOpcionesCliente(Cliente cliente) {
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
                  title: const Text('Editar cliente'),
                  onTap: () {
                    Navigator.pop(context);
                    mostrarEditarCliente(cliente);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.add_card_outlined),
                  title: const Text('Agregar deuda'),
                  onTap: () {
                    Navigator.pop(context);
                    mostrarAgregarDeuda(cliente);
                  },
                ),
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

                setState(() {
                  cliente.deuda += valor;

                  historial.add(
                    Movimiento(
                      nombreCliente: cliente.nombre,
                      tipo: 'deuda',
                      monto: valor,
                      fecha: DateTime.now(),
                    ),
                  );
                });

                await StorageService.guardarClientes(clientes);
                await StorageService.guardarHistorial(historial);

                if (mounted) {
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

                setState(() {
                  cliente.deuda -= pago;

                  historial.add(
                    Movimiento(
                      nombreCliente: cliente.nombre,
                      tipo: 'pago',
                      monto: pago,
                      fecha: DateTime.now(),
                    ),
                  );
                });

                await StorageService.guardarClientes(clientes);
                await StorageService.guardarHistorial(historial);

                if (mounted) {
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
    final cliente = await showClienteSearchDialog(
      context: context,
      clientes: clientes,
    );

    if (cliente == null || !mounted) {
      return;
    }

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
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: mostrarFormulario,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nuevo cliente'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentPadding =
                AdaptiveLayout.contentInset(constraints.maxWidth);

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
                      children: [
                        if (Navigator.canPop(context)) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back_rounded),
                              tooltip: 'Volver',
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Clientes',
                                style: textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF17322C),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Administra deudas, pagos y seguimiento diario.',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF66756D),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.search_rounded),
                                tooltip: 'Buscar cliente',
                                onPressed: buscarCliente,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.inventory_2_outlined),
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
                            ),
                            const SizedBox(width: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.history_rounded),
                                tooltip: 'Historial',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          HistorialScreen(
                                        historial: historial,
                                        clientes: clientes,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Container(
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Text(
                              'Resumen general',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'RD\$${deudaTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Saldo total pendiente',
                            style: TextStyle(
                              color: Color(0xFFDCE9E5),
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: _MetricTile(
                                  label: 'Clientes',
                                  value: '${clientes.length}',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _MetricTile(
                                  label: 'Con deuda',
                                  value: '$clientesConDeuda',
                                ),
                              ),
                            ],
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
                      itemCount: clientes.length,
                      itemBuilder: (context, index) {
                        final cliente = clientes[index];
                        final tieneDeuda = cliente.deuda > 0;

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
                              ).then((_) => setState(() {}));
                            },
                            onLongPress: () {
                              mostrarOpcionesCliente(cliente);
                            },
                            child: Ink(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(26),
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
                              child: Row(
                                children: [
                                  Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
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
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cliente.nombre,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF17322C),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          cliente.telefono,
                                          style: const TextStyle(
                                            color: Color(0xFF66756D),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(999),
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
                                      Text(
                                        'RD\$${cliente.deuda.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: tieneDeuda
                                              ? const Color(0xFFB42318)
                                              : const Color(0xFF1F7A6B),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
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
  final String label;
  final String value;

  const _MetricTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFDCE9E5),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
