import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/product_optimized_image_result.dart';
import '../../data/models/producto_imagen_sqlite_model.dart';
import '../../data/repositories/producto_imagen_repository.dart';
import '../../data/services/product_image_optimizer_service.dart';
import '../../models/producto.dart';
import '../../presentation/providers/auth_providers.dart';
import '../../presentation/providers/fiado_data_providers.dart';
import '../barcode_scanner_screen.dart';

class ProductoFormResult {
  final Producto producto;
  final List<ProductoImagenSqliteModel> imagenes;

  const ProductoFormResult({required this.producto, required this.imagenes});
}

class AgregarProductoDialog extends ConsumerStatefulWidget {
  final Producto? producto;
  final bool puedeAgregarImagenes;

  const AgregarProductoDialog({
    super.key,
    this.producto,
    required this.puedeAgregarImagenes,
  });

  @override
  ConsumerState<AgregarProductoDialog> createState() =>
      _AgregarProductoDialogState();
}

class _AgregarProductoDialogState extends ConsumerState<AgregarProductoDialog> {
  late final TextEditingController _nombreController;
  late final TextEditingController _codigoController;
  late final TextEditingController _categoriaController;
  late final TextEditingController _descripcionController;
  late final TextEditingController _ubicacionController;
  late final TextEditingController _cantidadController;
  late final TextEditingController _costoController;
  late final TextEditingController _porcentajeController;
  late final TextEditingController _precioController;
  late final TextEditingController _stockMinimoController;

  final _optimizer = const ProductImageOptimizerService();
  final _imagenes = <ProductoImagenSqliteModel>[];
  final _imagenesOptimizadas = <ProductOptimizedImageResult>[];
  bool _esClave = false;
  bool _seleccionandoImagenes = false;

  Producto? get _producto => widget.producto;

  @override
  void initState() {
    super.initState();
    final producto = widget.producto;
    _nombreController = TextEditingController(text: producto?.nombre);
    _codigoController = TextEditingController(text: producto?.codigoReferencia);
    _categoriaController = TextEditingController(
      text: producto?.categoria ?? producto?.ubicacion,
    );
    _descripcionController = TextEditingController(text: producto?.descripcion);
    final ubicacion = producto?.ubicacion;
    _ubicacionController = TextEditingController(
      text: ubicacion == null || ubicacion == 'Sin ubicacion' ? '' : ubicacion,
    );
    _cantidadController = TextEditingController(
      text: producto == null ? '0' : '${producto.cantidad}',
    );
    _costoController = TextEditingController(
      text: producto == null ? '0' : '${producto.costoUnitario}',
    );
    _porcentajeController = TextEditingController(
      text: producto == null ? '0' : '${producto.porcentajeGanancia}',
    );
    _precioController = TextEditingController(
      text: producto == null ? '0' : '${producto.precioVenta}',
    );
    _stockMinimoController = TextEditingController(
      text: producto == null ? '0' : '${producto.stockMinimo}',
    );
    _esClave = producto?.esClave ?? false;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _codigoController.dispose();
    _categoriaController.dispose();
    _descripcionController.dispose();
    _ubicacionController.dispose();
    _cantidadController.dispose();
    _costoController.dispose();
    _porcentajeController.dispose();
    _precioController.dispose();
    _stockMinimoController.dispose();
    super.dispose();
  }

  void _recalcularPrecioVenta() {
    final costo = double.tryParse(_costoController.text.trim()) ?? 0;
    final porcentaje = double.tryParse(_porcentajeController.text.trim()) ?? 0;
    if (costo < 0 || porcentaje < 0) return;
    final precio = costo + (costo * porcentaje / 100);
    _precioController.text = precio.toStringAsFixed(2);
  }

  Future<void> _seleccionarImagenes() async {
    if (_seleccionandoImagenes) return;
    setState(() => _seleccionandoImagenes = true);
    try {
      final seleccionadas = await ImagePicker().pickMultiImage();
      if (!mounted || seleccionadas.isEmpty) return;

      if (_imagenes.length + seleccionadas.length >
          ProductoImagenRepository.maxImagenesPorProducto) {
        _mostrarError('Solo puedes agregar hasta 3 imagenes por articulo.');
        return;
      }

      final nuevas = <ProductoImagenSqliteModel>[];
      final nuevasOptimizadas = <ProductOptimizedImageResult>[];
      for (final file in seleccionadas) {
        if (!mounted) return;
        if (!_optimizer.isAllowedFormat(file.mimeType, file.path)) {
          _mostrarError('Formato no permitido. Usa PNG o JPG.');
          return;
        }
        final optimized = await _optimizer.optimizeProductImage(
          sourcePath: file.path,
          mimeType: file.mimeType,
        );
        if (!mounted) return;
        final now = DateTime.now();
        nuevasOptimizadas.add(optimized);
        nuevas.add(
          ProductoImagenSqliteModel(
            productoId: 0,
            localPath: optimized.optimizedPath,
            orden: _imagenes.length + nuevas.length,
            mimeType: optimized.mimeType,
            sizeBytes: optimized.optimizedSizeBytes,
            width: optimized.optimizedWidth,
            height: optimized.optimizedHeight,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _imagenes.addAll(nuevas);
        _imagenesOptimizadas.addAll(nuevasOptimizadas);
      });
      _mostrarError('Imagen optimizada correctamente.');
    } catch (error) {
      if (!mounted) return;
      _mostrarError('No se pudo seleccionar imagenes: $error');
    } finally {
      if (mounted) setState(() => _seleccionandoImagenes = false);
    }
  }

  bool get _scannerDisponible {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS => true,
      TargetPlatform.fuchsia ||
      TargetPlatform.linux ||
      TargetPlatform.windows => false,
    };
  }

  Future<String?> _leerCodigo({required String titulo}) async {
    if (!_scannerDisponible) {
      _mostrarError('Escaneo no disponible en esta plataforma.');
      return null;
    }

    try {
      return await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => BarcodeScannerScreen(title: titulo)),
      );
    } catch (_) {
      if (!mounted) return null;
      _mostrarError('Escaneo no disponible en esta plataforma.');
      return null;
    }
  }

  Future<void> _escanearCodigoProducto() async {
    final code = await _leerCodigo(titulo: 'Escanear codigo del producto');
    if (!mounted || code == null || code.trim().isEmpty) return;

    final normalized = code.trim();
    _codigoController.text = normalized;

    final negocioId = ref.read(currentBusinessIdProvider);
    if (negocioId == null) return;

    final lookup = await ref
        .read(barcodeProductLookupServiceProvider)
        .lookupByBarcode(normalized, negocioId: negocioId);
    if (!mounted || !lookup.found) return;

    final product = lookup.existingProduct!;
    _nombreController.text = product.nombre;
    _descripcionController.text = product.descripcion ?? '';
    _categoriaController.text = product.categoria ?? '';
    _costoController.text = product.costoUnitario.toStringAsFixed(2);
    _porcentajeController.text = product.porcentajeGanancia.toStringAsFixed(2);
    _precioController.text = product.precioVenta.toStringAsFixed(2);
    _stockMinimoController.text = '${product.stockMinimo}';
    _ubicacionController.text = product.ubicacion == 'Sin ubicacion'
        ? ''
        : product.ubicacion;
    _mostrarError('Ya existe un producto con este codigo en tu inventario.');
  }

  Future<void> _escanearUbicacion() async {
    final code = await _leerCodigo(titulo: 'Escanear ubicacion');
    if (!mounted || code == null || code.trim().isEmpty) return;
    _ubicacionController.text = code.trim();
  }

  void _guardar() {
    final nombre = _nombreController.text.trim();
    final cantidad = int.tryParse(_cantidadController.text.trim()) ?? -1;
    final costo = double.tryParse(_costoController.text.trim()) ?? 0;
    final porcentaje = double.tryParse(_porcentajeController.text.trim()) ?? 0;
    final precio = double.tryParse(_precioController.text.trim()) ?? 0;
    final stockMinimo = int.tryParse(_stockMinimoController.text.trim()) ?? 0;

    if (nombre.isEmpty) {
      _mostrarError('El nombre es obligatorio.');
      return;
    }
    if (cantidad < 0 ||
        costo < 0 ||
        precio < 0 ||
        porcentaje < 0 ||
        stockMinimo < 0) {
      _mostrarError('Los valores numericos no pueden ser negativos.');
      return;
    }
    if (_imagenes.length > ProductoImagenRepository.maxImagenesPorProducto) {
      _mostrarError('Solo puedes agregar hasta 3 imagenes por articulo.');
      return;
    }

    final producto = Producto(
      id: _producto?.id ?? 'prod-${DateTime.now().millisecondsSinceEpoch}',
      nombre: nombre,
      codigoReferencia: _codigoController.text.trim().isEmpty
          ? null
          : _codigoController.text.trim(),
      categoria: _categoriaController.text.trim().isEmpty
          ? null
          : _categoriaController.text.trim(),
      descripcion: _descripcionController.text.trim().isEmpty
          ? null
          : _descripcionController.text.trim(),
      ubicacion: _ubicacionController.text.trim().isEmpty
          ? 'Sin ubicacion'
          : _ubicacionController.text.trim(),
      cantidad: cantidad,
      costoUnitario: costo,
      precioCompra: costo,
      precioVenta: precio,
      porcentajeGanancia: porcentaje,
      stockMinimo: stockMinimo,
      tipoMedida: _producto?.tipoMedida ?? Producto.medidaUnidad,
      nivelDemanda: _producto?.nivelDemanda ?? Producto.demandaMedia,
      esClave: _esClave,
      ultimaVerificacion: _producto?.ultimaVerificacion,
      disponibilidadConfirmada: _producto?.disponibilidadConfirmada ?? false,
      disponibilidadCorregida: _producto?.disponibilidadCorregida ?? false,
      requiereVerificacionAdministrador:
          _producto?.requiereVerificacionAdministrador ?? false,
      rotacionSemanaAnterior: _producto?.rotacionSemanaAnterior ?? 0,
    );

    Navigator.of(context).pop(
      ProductoFormResult(
        producto: producto,
        imagenes: List<ProductoImagenSqliteModel>.from(_imagenes),
      ),
    );
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_producto == null ? 'Agregar producto' : 'Editar producto'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _codigoController,
                decoration: InputDecoration(
                  labelText: 'Codigo de referencia',
                  helperText:
                      'Escanea el codigo del producto o escribelo manualmente.',
                  suffixIcon: IconButton(
                    tooltip: 'Escanear codigo del producto',
                    onPressed: _escanearCodigoProducto,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _categoriaController,
                decoration: const InputDecoration(labelText: 'Categoria'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descripcionController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Descripcion'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ubicacionController,
                decoration: InputDecoration(
                  labelText: 'Ubicacion',
                  helperText:
                      'Puede ser estante, pasillo, caja o un codigo interno.',
                  suffixIcon: IconButton(
                    tooltip: 'Escanear ubicacion',
                    onPressed: _escanearUbicacion,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cantidadController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cantidad'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _costoController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Costo unitario',
                  prefixText: 'RD\$ ',
                ),
                onChanged: (_) => _recalcularPrecioVenta(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _porcentajeController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Porcentaje de ganancia',
                  suffixText: '%',
                ),
                onChanged: (_) => _recalcularPrecioVenta(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _precioController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Precio de venta',
                  prefixText: 'RD\$ ',
                ),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Puedes calcular el precio de venta desde el costo y el porcentaje, o escribirlo manualmente.',
                  style: TextStyle(color: Color(0xFF66756D), fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _stockMinimoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stock minimo'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Producto clave'),
                value: _esClave,
                onChanged: (value) => setState(() => _esClave = value),
              ),
              if (widget.puedeAgregarImagenes) ...[
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Imagen opcional. Las imagenes seran optimizadas automaticamente a 500x500 px.',
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed:
                        _seleccionandoImagenes ||
                            _imagenes.length >=
                                ProductoImagenRepository.maxImagenesPorProducto
                        ? null
                        : _seleccionarImagenes,
                    icon: _seleccionandoImagenes
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      _seleccionandoImagenes
                          ? 'Seleccionando'
                          : 'Agregar imagen (${_imagenes.length}/3)',
                    ),
                  ),
                ),
                if (_imagenes.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Si no agregas imagen, el producto se guardara normalmente.',
                      style: TextStyle(color: Color(0xFF66756D), fontSize: 12),
                    ),
                  ),
                if (_imagenes.isNotEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Imagen optimizada correctamente.',
                      style: TextStyle(
                        color: Color(0xFF1F7A6B),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                for (var i = 0; i < _imagenes.length; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF1F7A6B),
                    ),
                    title: Text('Imagen optimizada ${i + 1}'),
                    subtitle: Text(_descripcionImagenOptimizada(i)),
                    trailing: IconButton(
                      tooltip: 'Quitar imagen',
                      onPressed: () {
                        setState(() {
                          _imagenes.removeAt(i);
                          if (i < _imagenesOptimizadas.length) {
                            _imagenesOptimizadas.removeAt(i);
                          }
                        });
                      },
                      icon: const Icon(Icons.close),
                    ),
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
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }

  String _descripcionImagenOptimizada(int index) {
    if (index >= _imagenesOptimizadas.length) {
      final image = _imagenes[index];
      return '${image.width ?? 500}x${image.height ?? 500} - ${_formatBytes(image.sizeBytes)}';
    }
    final result = _imagenesOptimizadas[index];
    return 'Original ${result.originalWidth}x${result.originalHeight} (${_formatBytes(result.originalSizeBytes)}) -> Optimizada ${result.optimizedWidth}x${result.optimizedHeight} (${_formatBytes(result.optimizedSizeBytes)})';
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}
