import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/adaptive_layout.dart';
import 'auditoria_screen.dart';

class ValidacionReporteResultado {
  final String productoId;
  final int cantidadValidada;

  const ValidacionReporteResultado({
    required this.productoId,
    required this.cantidadValidada,
  });
}

class ValidacionReporteScreen extends StatefulWidget {
  final List<AuditoriaResultado> reporte;
  final bool soloReporte;

  const ValidacionReporteScreen({
    super.key,
    required this.reporte,
    this.soloReporte = false,
  });

  @override
  State<ValidacionReporteScreen> createState() => _ValidacionReporteScreenState();
}

class _ValidacionReporteScreenState extends State<ValidacionReporteScreen> {
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = widget.reporte
        .map(
          (item) => TextEditingController(
            text: widget.soloReporte ? '${item.stockSistema}' : '',
          ),
        )
        .toList(growable: false);

    for (final controller in _controllers) {
      controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller
        ..removeListener(_onControllerChanged)
        ..dispose();
    }
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _puedeActualizar {
    if (widget.soloReporte) {
      return true;
    }

    if (_controllers.isEmpty) {
      return false;
    }

    for (final controller in _controllers) {
      final texto = controller.text.trim();
      if (texto.isEmpty || int.tryParse(texto) == null) {
        return false;
      }
    }

    return true;
  }

  void _actualizarInventario() {
    if (!_puedeActualizar) {
      return;
    }

    final resultados = <ValidacionReporteResultado>[];

    for (var i = 0; i < widget.reporte.length; i++) {
      resultados.add(
        ValidacionReporteResultado(
          productoId: widget.reporte[i].productoId,
          cantidadValidada: int.parse(_controllers[i].text.trim()),
        ),
      );
    }

    Navigator.pop(context, resultados);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Validar reporte de Inventario')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentPadding =
              AdaptiveLayout.contentInset(constraints.maxWidth);

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                contentPadding,
                18,
                contentPadding,
                20,
              ),
              itemCount: widget.reporte.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final item = widget.reporte[index];

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
                        item.nombre,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF17322C),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ubicacion: ${item.ubicacion}',
                        style: const TextStyle(color: Color(0xFF66756D)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cantidad auditada: ${item.cantidadAuditada}',
                        style: const TextStyle(color: Color(0xFF66756D)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cantidad en sistema: ${item.stockSistema}',
                        style: const TextStyle(color: Color(0xFF66756D)),
                      ),
                      const SizedBox(height: 4),
                      item.diferencia == 0
                          ? const Text(
                              'Producto verificado correctamente',
                              style: TextStyle(
                                color: Color(0xFF1F7A6B),
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : Text(
                              'Diferencia detectada: ${item.diferencia > 0 ? '+' : ''}${item.diferencia}',
                              style: const TextStyle(
                                color: Color(0xFFB42318),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _controllers[index],
                        readOnly: widget.soloReporte,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: widget.soloReporte
                              ? 'Cantidad validada'
                              : 'Cantidad validada por encargado',
                          prefixIcon: Icon(Icons.rule_folder_outlined),
                        ),
                      ),
                    ],
                  ),
                );
              },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
              padding: EdgeInsets.fromLTRB(
                contentPadding,
                0,
                contentPadding,
                20,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _puedeActualizar ? _actualizarInventario : null,
                  child: Text(
                    widget.soloReporte
                        ? 'Aceptar reporte'
                        : 'Actualizar productos',
                  ),
                ),
              ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
