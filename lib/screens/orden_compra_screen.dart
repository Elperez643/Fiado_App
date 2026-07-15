import 'package:flutter/material.dart';

import '../models/producto.dart';
import '../widgets/adaptive_layout.dart';

class OrdenCompraScreen extends StatelessWidget {
  final List<Producto> productos;

  const OrdenCompraScreen({super.key, required this.productos});

  static const int minimoUnidades = 10;
  static const int minimoLibras = 70;

  static int minimoPara(Producto producto) {
    return producto.tipoMedida == Producto.medidaPeso
        ? minimoLibras
        : minimoUnidades;
  }

  static bool requiereReposicion(Producto producto) {
    return producto.cantidad <= minimoPara(producto);
  }

  static int prioridadDemanda(Producto producto) {
    if (producto.nivelDemanda == Producto.demandaAlta) {
      return 0;
    }

    if (producto.nivelDemanda == Producto.demandaMedia) {
      return 1;
    }

    return 2;
  }

  static String unidadPara(Producto producto) {
    return producto.tipoMedida == Producto.medidaPeso ? 'lbs' : 'uds';
  }

  @override
  Widget build(BuildContext context) {
    final productosReposicion =
        productos.where(requiereReposicion).toList(growable: false)..sort((
          a,
          b,
        ) {
          final prioridad = prioridadDemanda(a).compareTo(prioridadDemanda(b));
          if (prioridad != 0) {
            return prioridad;
          }

          return a.cantidad.compareTo(b.cantidad);
        });

    return Scaffold(
      appBar: AppBar(title: const Text('Orden de compra')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentPadding = AdaptiveLayout.contentInset(
              constraints.maxWidth,
            );

            if (productosReposicion.isEmpty) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: contentPadding,
                    vertical: 28,
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 46,
                        color: Color(0xFF1F7A6B),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Stock suficiente',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF17322C),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No hay articulos por debajo del minimo de reposicion.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF66756D)),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: EdgeInsets.fromLTRB(
                contentPadding,
                18,
                contentPadding,
                28,
              ),
              itemCount: productosReposicion.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _ResumenOrden(total: productosReposicion.length);
                }

                final producto = productosReposicion[index - 1];
                final minimo = minimoPara(producto);
                final unidad = unidadPara(producto);
                final sugerido = minimo - producto.cantidad;

                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFF3D6D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDEAE5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.shopping_cart_checkout_outlined,
                              color: Color(0xFFB42318),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  producto.nombre,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF17322C),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  producto.ubicacion,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF66756D),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Demanda ${producto.nivelDemanda}',
                                  style: const TextStyle(
                                    color: Color(0xFFB54708),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 360;
                          final metrics = [
                            _OrdenMetric(
                              label: 'Sistema',
                              value: '${producto.cantidad} $unidad',
                            ),
                            _OrdenMetric(
                              label: 'Minimo',
                              value: '$minimo $unidad',
                            ),
                            _OrdenMetric(
                              label: 'Reponer',
                              value: '${sugerido <= 0 ? 1 : sugerido} $unidad',
                            ),
                          ];

                          if (compact) {
                            return Column(
                              children: [
                                metrics[0],
                                const SizedBox(height: 8),
                                metrics[1],
                                const SizedBox(height: 8),
                                metrics[2],
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: metrics[0]),
                              const SizedBox(width: 10),
                              Expanded(child: metrics[1]),
                              const SizedBox(width: 10),
                              Expanded(child: metrics[2]),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ResumenOrden extends StatelessWidget {
  final int total;

  const _ResumenOrden({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF5B3A00), Color(0xFFE7B04B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        '$total articulos requieren reposicion',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _OrdenMetric extends StatelessWidget {
  final String label;
  final String value;

  const _OrdenMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF17322C),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF66756D), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
