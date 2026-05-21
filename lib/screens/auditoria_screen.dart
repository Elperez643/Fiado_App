import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/producto.dart';
import '../widgets/adaptive_layout.dart';

class AuditoriaResultado {
  final String productoId;
  final String nombre;
  final String ubicacion;
  final int cantidadAuditada;
  final int stockSistema;

  const AuditoriaResultado({
    required this.productoId,
    required this.nombre,
    required this.ubicacion,
    required this.cantidadAuditada,
    required this.stockSistema,
  });

  int get diferencia => cantidadAuditada - stockSistema;
  bool get fueVerificadoCorrectamente => diferencia == 0;
}

class AuditoriaScreen extends StatefulWidget {
  final List<Producto> productos;
  final int cantidadObjetivo;
  final bool productosPreseleccionados;

  const AuditoriaScreen({
    super.key,
    required this.productos,
    this.cantidadObjetivo = 3,
    this.productosPreseleccionados = false,
  });

  @override
  State<AuditoriaScreen> createState() => _AuditoriaScreenState();
}

class _AuditoriaScreenState extends State<AuditoriaScreen> {
  final TextEditingController _cantidadController = TextEditingController();
  final List<AuditoriaResultado> _reporte = [];
  late final List<Producto> _productosAuditoria;
  int _indiceActual = 0;
  bool _hayCantidadEscrita = false;

  Producto get _productoActual => _productosAuditoria[_indiceActual];
  bool get _esUltimoArticulo =>
      _indiceActual >= _productosAuditoria.length - 1;

  @override
  void initState() {
    super.initState();
    if (widget.productosPreseleccionados) {
      _productosAuditoria = List<Producto>.from(widget.productos);
    } else {
      final disponibles = widget.productos
          .where((producto) => producto.cantidad > 0)
          .toList(growable: false);
      final seleccion = List<Producto>.from(disponibles)..shuffle(Random());
      _productosAuditoria = seleccion
          .take(min(widget.cantidadObjetivo, seleccion.length))
          .toList(growable: false);
    }
    _cantidadController.addListener(_actualizarEstadoCantidad);
  }

  @override
  void dispose() {
    _cantidadController
      ..removeListener(_actualizarEstadoCantidad)
      ..dispose();
    super.dispose();
  }

  void _actualizarEstadoCantidad() {
    final tieneTexto = _cantidadController.text.trim().isNotEmpty;
    if (tieneTexto == _hayCantidadEscrita) {
      return;
    }

    setState(() {
      _hayCantidadEscrita = tieneTexto;
    });
  }

  bool _registrarCantidadActual() {
    final cantidadAuditada = int.tryParse(_cantidadController.text.trim());
    if (cantidadAuditada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Introduce una cantidad valida para continuar.'),
        ),
      );
      return false;
    }

    _reporte.add(
      AuditoriaResultado(
        productoId: _productoActual.id,
        nombre: _productoActual.nombre,
        ubicacion: _productoActual.ubicacion,
        cantidadAuditada: cantidadAuditada,
        stockSistema: _productoActual.cantidad,
      ),
    );
    return true;
  }

  void _siguienteArticulo() {
    if (!_registrarCantidadActual()) {
      return;
    }

    setState(() {
      _indiceActual++;
      _cantidadController.clear();
      _hayCantidadEscrita = false;
    });
  }

  void _finalizarInventario() {
    if (!_registrarCantidadActual()) {
      return;
    }

    if (_reporte.length >= widget.cantidadObjetivo) {
      Navigator.pop(context, _reporte);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Faltan ${widget.cantidadObjetivo - _reporte.length} articulos por auditar.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _productosAuditoria.length;
    final progreso = total == 0 ? 0.0 : (_indiceActual + 1) / total;

    return Scaffold(
      appBar: AppBar(title: const Text('Auditoria')),
      body: _productosAuditoria.length < widget.cantidadObjetivo
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Se necesitan ${widget.cantidadObjetivo} articulos disponibles para iniciar la auditoria.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final contentPadding = AdaptiveLayout.contentInset(
                  constraints.maxWidth,
                );

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    contentPadding,
                    18,
                    contentPadding,
                    20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ProgresoAuditoria(
                        actual: _indiceActual + 1,
                        total: total,
                        progreso: progreso,
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: SingleChildScrollView(
                          child: _ProductoAuditoriaCard(
                            producto: _productoActual,
                            controller: _cantidadController,
                            onSubmitted: _esUltimoArticulo
                                ? _finalizarInventario
                                : _siguienteArticulo,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: !_hayCantidadEscrita
                              ? null
                              : _esUltimoArticulo
                                  ? _finalizarInventario
                                  : _siguienteArticulo,
                          icon: Icon(
                            _esUltimoArticulo && _hayCantidadEscrita
                                ? Icons.check_circle_outline
                                : Icons.arrow_forward_rounded,
                          ),
                          label: Text(
                            _esUltimoArticulo && _hayCantidadEscrita
                                ? 'Finalizar Inventario'
                                : 'Siguiente Articulo',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _ProgresoAuditoria extends StatelessWidget {
  final int actual;
  final int total;
  final double progreso;

  const _ProgresoAuditoria({
    required this.actual,
    required this.total,
    required this.progreso,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD9E8E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Articulo $actual de $total',
            style: const TextStyle(
              color: Color(0xFF17322C),
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'La auditoria termina cuando todos los articulos tengan cantidad.',
            style: TextStyle(
              color: Color(0xFF66756D),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 10,
              backgroundColor: const Color(0xFFE7F3EF),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF1F7A6B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductoAuditoriaCard extends StatelessWidget {
  final Producto producto;
  final TextEditingController controller;
  final VoidCallback onSubmitted;

  const _ProductoAuditoriaCard({
    required this.producto,
    required this.controller,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD9E8E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            producto.nombre,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF17322C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ubicacion: ${producto.ubicacion}',
            style: const TextStyle(color: Color(0xFF66756D)),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              labelText: 'Cantidad validada en stock',
              prefixIcon: Icon(Icons.fact_check_outlined),
            ),
            onSubmitted: (_) => onSubmitted(),
          ),
        ],
      ),
    );
  }
}
