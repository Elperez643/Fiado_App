import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/billable_product.dart';
import '../../data/models/deuda_item_sqlite_model.dart';
import '../../core/utils/money_formatter.dart';
import '../../presentation/providers/fiado_data_providers.dart';

class AgregarDeudaResult {
  final String? concepto;
  final double monto;
  final List<DeudaItemSqliteModel> items;
  final double subtotalMercancias;
  final double ajusteManual;
  final double abonoInicial;

  const AgregarDeudaResult({
    required this.concepto,
    required this.monto,
    required this.items,
    required this.subtotalMercancias,
    required this.ajusteManual,
    required this.abonoInicial,
  });
}

class AgregarDeudaDialog extends ConsumerStatefulWidget {
  final String clienteNombre;

  const AgregarDeudaDialog({super.key, required this.clienteNombre});

  @override
  ConsumerState<AgregarDeudaDialog> createState() => _AgregarDeudaDialogState();
}

class _AgregarDeudaDialogState extends ConsumerState<AgregarDeudaDialog> {
  final _conceptoController = TextEditingController();
  final _montoController = TextEditingController();
  final _cantidadController = TextEditingController(text: '1');
  final _precioController = TextEditingController();
  final _items = <DeudaItemSqliteModel>[];

  BillableProduct? _productoSeleccionado;
  bool _agregandoItem = false;
  bool _actualizandoMontoDesdeSistema = false;
  bool _totalFueEditadoManualmente = false;

  double get _totalItems {
    return _items.fold<double>(0, (total, item) => total + item.subtotal);
  }

  bool get _tieneItems => _items.isNotEmpty;

  double get _subtotalPreview {
    final cantidad = int.tryParse(_cantidadController.text.trim()) ?? 0;
    final precio =
        double.tryParse(_precioController.text.trim()) ??
        _productoSeleccionado?.precioVenta ??
        0;
    return cantidad * precio;
  }

  @override
  void initState() {
    super.initState();
    _montoController.addListener(_marcarTotalManualSiAplica);
  }

  @override
  void dispose() {
    _montoController.removeListener(_marcarTotalManualSiAplica);
    _conceptoController.dispose();
    _montoController.dispose();
    _cantidadController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  void _marcarTotalManualSiAplica() {
    if (_actualizandoMontoDesdeSistema || !mounted) return;
    if (_totalFueEditadoManualmente) {
      setState(() {});
      return;
    }
    setState(() => _totalFueEditadoManualmente = true);
  }

  void _usarSubtotalComoMontoFinal() {
    if (!_tieneItems) return;
    setState(() => _totalFueEditadoManualmente = false);
    _actualizarMontoTotalDesdeSubtotal();
  }

  void _actualizarMontoTotalDesdeSubtotal() {
    if (!_tieneItems || _totalFueEditadoManualmente) return;
    _actualizandoMontoDesdeSistema = true;
    _montoController.text = _formatMoneyInput(_totalItems);
    _actualizandoMontoDesdeSistema = false;
    if (mounted) setState(() {});
  }

  String _formatMoneyInput(num value) {
    if (value % 1 == 0) {
      return MoneyFormatter.format(value.round());
    }
    return MoneyFormatter.format(value);
  }

  double? _parseMoneyInput(String value) {
    final clean = value.trim().replaceAll(',', '');
    if (clean.isEmpty) return null;
    return double.tryParse(clean);
  }

  double? get _montoManual {
    return _parseMoneyInput(_montoController.text);
  }

  double get _montoFinalPreview {
    final manual = _montoManual;
    if (manual != null) return manual;
    return _tieneItems ? _totalItems : 0;
  }

  double get _ajustePreview => _montoFinalPreview - _totalItems;

  double get _abonoInicialPreview {
    if (!_tieneItems) return 0;
    final diferencia = _totalItems - _montoFinalPreview;
    return diferencia > 0 ? diferencia : 0;
  }

  bool get _puedeAgregarItem {
    final cantidad = int.tryParse(_cantidadController.text.trim()) ?? 0;
    final precio = double.tryParse(_precioController.text.trim()) ?? -1;
    return !_agregandoItem &&
        _productoSeleccionado != null &&
        _productoSeleccionado!.stock > 0 &&
        cantidad > 0 &&
        precio >= 0;
  }

  Future<void> _agregarItem() async {
    final producto = _productoSeleccionado;
    final cantidad = int.tryParse(_cantidadController.text.trim()) ?? 0;
    final precio =
        double.tryParse(_precioController.text.trim()) ??
        producto?.precioVenta ??
        0;

    if (cantidad <= 0 || precio < 0) {
      _mostrarError(
        'La cantidad debe ser mayor que 0 y el precio no puede ser negativo.',
      );
      return;
    }

    if (producto == null) {
      _mostrarError('Selecciona un producto del inventario.');
      return;
    }

    if (cantidad > producto.stock) {
      _mostrarError(
        'Stock insuficiente para ${producto.nombre}. Disponible: ${producto.stock}.',
      );
      return;
    }

    setState(() => _agregandoItem = true);
    setState(() {
      _items.add(
        DeudaItemSqliteModel(
          movimientoId: 0,
          productoId: producto.id,
          nombreProducto: producto.nombre,
          codigoReferencia: producto.codigoReferencia,
          cantidad: cantidad,
          precioUnitario: precio,
          subtotal: cantidad * precio,
        ),
      );
      _cantidadController.text = '1';
      _precioController.text = '0.00';
      _productoSeleccionado = null;
      _agregandoItem = false;
    });
    _actualizarMontoTotalDesdeSubtotal();
  }

  Future<void> _guardar() async {
    final subtotalMercancias = _totalItems;
    final montoText = _montoController.text.trim();
    if (montoText.isNotEmpty && _parseMoneyInput(montoText) == null) {
      _mostrarError('El monto total final debe ser un numero valido.');
      return;
    }
    final montoManual = _montoManual;
    final monto = montoManual ?? (_tieneItems ? subtotalMercancias : 0);

    if (!_tieneItems && (montoManual == null || monto <= 0)) {
      _mostrarError('El monto total debe ser mayor a 0.');
      return;
    }

    if (_tieneItems && monto < 0) {
      _mostrarError('El monto total debe ser mayor o igual a 0.');
      return;
    }

    if (_tieneItems && monto == 0) {
      final confirmado = await _confirmarDeudaEnCero();
      if (!confirmado) return;
      if (!mounted) return;
    }

    final concepto = _conceptoController.text.trim();
    final ajuste = _tieneItems ? monto - subtotalMercancias : 0.0;
    final abonoInicial = _tieneItems && subtotalMercancias > monto
        ? subtotalMercancias - monto
        : 0.0;
    Navigator.of(context).pop(
      AgregarDeudaResult(
        concepto: concepto.isEmpty ? null : concepto,
        monto: monto,
        items: List<DeudaItemSqliteModel>.from(_items),
        subtotalMercancias: subtotalMercancias,
        ajusteManual: ajuste,
        abonoInicial: abonoInicial,
      ),
    );
  }

  Future<bool> _confirmarDeudaEnCero() async {
    if (!mounted) return false;
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Fiado totalmente pagado'),
          content: const Text(
            'El cliente esta pagando todo en el momento. No quedara deuda pendiente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar'),
            ),
          ],
        );
      },
    );
    return resultado ?? false;
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalItems;
    final productosAsync = ref.watch(billableProductsProvider);
    final productoSinPrecio =
        _productoSeleccionado != null &&
        _productoSeleccionado!.precioVenta <= 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text('Agregar deuda a ${widget.clienteNombre}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _conceptoController,
                decoration: const InputDecoration(
                  labelText: 'Concepto o descripcion',
                ),
              ),
              const SizedBox(height: 18),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Agregar articulos',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF17322C),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Fuente estable: no usar productosProvider/productoBusquedaProvider
              // ni listas visuales de InventarioScreen para facturar.
              productosAsync.when(
                loading: () => const _BillableProductsState(
                  icon: Icons.hourglass_empty_rounded,
                  message: 'Cargando productos disponibles...',
                ),
                error: (error, _) => _BillableProductsState(
                  icon: Icons.error_outline_rounded,
                  message: error.toString(),
                  onRetry: () => ref.invalidate(billableProductsProvider),
                ),
                data: (productosDisponibles) {
                  BillableProduct? selected;
                  for (final producto in productosDisponibles) {
                    if (producto.id == _productoSeleccionado?.id) {
                      selected = producto;
                      break;
                    }
                  }
                  if (selected == null && _productoSeleccionado != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      setState(() {
                        _productoSeleccionado = null;
                        _precioController.clear();
                        _cantidadController.text = '1';
                      });
                    });
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<BillableProduct>(
                        initialValue: selected,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Producto del inventario',
                        ),
                        hint: const Text('Selecciona un producto'),
                        items: productosDisponibles
                            .map(
                              (producto) => DropdownMenuItem(
                                value: producto,
                                child: Text(
                                  producto.codigoReferencia == null
                                      ? producto.nombre
                                      : '${producto.nombre} (${producto.codigoReferencia})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: productosDisponibles.isEmpty
                            ? null
                            : (producto) {
                                setState(() {
                                  _productoSeleccionado = producto;
                                  _precioController.text =
                                      (producto?.precioVenta ?? 0)
                                          .toStringAsFixed(2);
                                  _cantidadController.text = '1';
                                });
                              },
                      ),
                      if (productosDisponibles.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'No hay productos con stock disponible. Puedes registrar una deuda manual.',
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (productoSinPrecio) ...[
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Este producto no tiene precio de venta configurado.',
                    style: TextStyle(
                      color: Color(0xFFB54708),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cantidadController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cantidad'),
                      onChanged: (_) {
                        setState(() {});
                        _actualizarMontoTotalDesdeSubtotal();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _precioController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Precio unitario',
                        prefixText: 'RD\$ ',
                      ),
                      onChanged: (_) {
                        setState(() {});
                        _actualizarMontoTotalDesdeSubtotal();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Subtotal actual: ${MoneyFormatter.formatCurrency(_subtotalPreview)}',
                  style: const TextStyle(
                    color: Color(0xFF17322C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _puedeAgregarItem ? _agregarItem : null,
                  icon: const Icon(Icons.add_shopping_cart_outlined),
                  label: Text(
                    _agregandoItem ? 'Agregando...' : 'Agregar articulo',
                  ),
                ),
              ),
              if (_items.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (var i = 0; i < _items.length; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _items[i].codigoReferencia == null
                          ? _items[i].nombreProducto
                          : '${_items[i].nombreProducto} (${_items[i].codigoReferencia})',
                    ),
                    subtitle: Text(
                      '${_items[i].cantidad} x ${MoneyFormatter.formatCurrency(_items[i].precioUnitario)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(MoneyFormatter.formatCurrency(_items[i].subtotal)),
                        IconButton(
                          tooltip: 'Quitar producto',
                          onPressed: () {
                            setState(() {
                              _items.removeAt(i);
                              if (_items.isEmpty &&
                                  !_totalFueEditadoManualmente) {
                                _actualizandoMontoDesdeSistema = true;
                                _montoController.clear();
                                _actualizandoMontoDesdeSistema = false;
                              }
                            });
                            _actualizarMontoTotalDesdeSubtotal();
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                const Divider(),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Subtotal mercancias ${MoneyFormatter.formatCurrency(total)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              TextField(
                controller: _montoController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Monto total final',
                  prefixText: 'RD\$ ',
                  hintText: _tieneItems
                      ? 'Usara subtotal: ${MoneyFormatter.formatCurrency(_totalItems)}'
                      : null,
                  helperText:
                      'Este monto se llena automaticamente con el total de los articulos. Puedes editarlo si necesitas ajustar el fiado.',
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (_tieneItems) ...[
                const SizedBox(height: 10),
                _ResumenMontoFinal(
                  subtotalMercancias: _totalItems,
                  montoFinal: _montoFinalPreview,
                  ajuste: _ajustePreview,
                  abonoInicial: _abonoInicialPreview,
                  montoManual: _montoManual,
                  totalFueEditadoManualmente: _totalFueEditadoManualmente,
                  onRecalcular: _usarSubtotalComoMontoFinal,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _guardar, child: const Text('Agregar')),
      ],
    );
  }
}

class _BillableProductsState extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  const _BillableProductsState({
    required this.icon,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD9E8E3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF1F7A6B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF53635F),
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

class _ResumenMontoFinal extends StatelessWidget {
  final double subtotalMercancias;
  final double montoFinal;
  final double ajuste;
  final double abonoInicial;
  final double? montoManual;
  final bool totalFueEditadoManualmente;
  final VoidCallback onRecalcular;

  const _ResumenMontoFinal({
    required this.subtotalMercancias,
    required this.montoFinal,
    required this.ajuste,
    required this.abonoInicial,
    required this.montoManual,
    required this.totalFueEditadoManualmente,
    required this.onRecalcular,
  });

  @override
  Widget build(BuildContext context) {
    final tieneMontoManual = montoManual != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9E8E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _linea('Subtotal mercancias', subtotalMercancias),
          _linea('Monto final', montoFinal),
          if (totalFueEditadoManualmente &&
              tieneMontoManual &&
              ajuste.abs() > 0.01)
            _linea(ajuste > 0 ? 'Ajuste adicional' : 'Ajuste manual', ajuste),
          if (abonoInicial > 0.01) ...[
            _linea('Monto abonado', abonoInicial),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'El monto abonado se registrara como pago inicial de este fiado.',
                style: TextStyle(fontSize: 12, color: Color(0xFF66756D)),
              ),
            ),
          ] else if (totalFueEditadoManualmente &&
              tieneMontoManual &&
              ajuste > 0.01)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Este monto final es mayor al subtotal de mercancias. Se registrara como ajuste adicional.',
                style: TextStyle(fontSize: 12, color: Color(0xFF66756D)),
              ),
            ),
          if (totalFueEditadoManualmente)
            TextButton.icon(
              onPressed: onRecalcular,
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('Usar subtotal'),
            ),
        ],
      ),
    );
  }

  Widget _linea(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF53635F),
              ),
            ),
          ),
          Text(
            MoneyFormatter.formatCurrency(value),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
