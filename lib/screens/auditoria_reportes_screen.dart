import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/usuario_sqlite_model.dart';
import '../data/repositories/auditoria_repository.dart';
import '../presentation/providers/auth_providers.dart';
import '../presentation/providers/fiado_data_providers.dart';
import '../widgets/adaptive_layout.dart';

class AuditoriaReportesScreen extends ConsumerWidget {
  const AuditoriaReportesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final esNegocio = user?.tipoUsuario == UsuarioSqliteModel.tipoNegocio;
    final auditoriasAsync = esNegocio
        ? ref.watch(auditoriasNegocioProvider)
        : ref.watch(auditoriasColaboradorProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(esNegocio ? 'Reportes de auditoria' : 'Mis auditorias'),
      ),
      body: SafeArea(
        child: auditoriasAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(
            child: Text('No se pudieron cargar las auditorias.'),
          ),
          data: (auditorias) {
            if (auditorias.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    'Todavia no hay auditorias registradas.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final padding = AdaptiveLayout.contentInset(
                  constraints.maxWidth,
                );
                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(padding, 16, padding, 28),
                  itemCount: auditorias.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _AuditoriaReporteCard(
                      resumen: auditorias[index],
                      mostrarDetalleCompleto: esNegocio,
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AuditoriaReporteCard extends ConsumerWidget {
  final AuditoriaResumen resumen;
  final bool mostrarDetalleCompleto;

  const _AuditoriaReporteCard({
    required this.resumen,
    required this.mostrarDetalleCompleto,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditoria = resumen.auditoria;
    final fecha =
        '${auditoria.fecha.day.toString().padLeft(2, '0')}/${auditoria.fecha.month.toString().padLeft(2, '0')}/${auditoria.fecha.year}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: resumen.diferencias > 0
              ? const Color(0xFFE7B04B)
              : const Color(0xFFD9E8E3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Auditoria ${auditoria.tipo}',
            style: const TextStyle(
              color: Color(0xFF17322C),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text('Fecha: $fecha'),
          Text('Realizada por: ${resumen.ejecutadaPor}'),
          Text(
            'Productos revisados: ${auditoria.productosValidados}/${auditoria.totalProductos}',
          ),
          Text('Diferencias encontradas: ${resumen.diferencias}'),
          if (auditoria.observaciones?.isNotEmpty ?? false)
            Text('Observaciones: ${auditoria.observaciones}'),
          if (mostrarDetalleCompleto && auditoria.id != null) ...[
            const SizedBox(height: 12),
            _AuditoriaItemsDetalle(auditoriaId: auditoria.id!),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              'Estado: ${auditoria.estado}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

class _AuditoriaItemsDetalle extends ConsumerWidget {
  final int auditoriaId;

  const _AuditoriaItemsDetalle({required this.auditoriaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(auditoriaItemsProvider(auditoriaId));

    return itemsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const Text('No se pudo cargar el detalle.'),
      data: (items) {
        return Column(
          children: items
              .map((detalle) {
                final diferencia = detalle.diferencia;
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAF8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${detalle.productoNombre}: sistema ${detalle.item.stockSistema}, fisico ${detalle.item.stockFisico ?? '-'}, diferencia ${diferencia == null
                        ? '-'
                        : diferencia > 0
                        ? '+$diferencia'
                        : '$diferencia'}',
                    style: const TextStyle(
                      color: Color(0xFF17322C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }
}
