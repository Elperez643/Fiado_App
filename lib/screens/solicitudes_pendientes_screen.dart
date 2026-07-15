import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/money_formatter.dart';
import '../data/models/solicitud_autorizacion_sqlite_model.dart';
import '../models/cliente.dart';
import '../models/producto.dart';
import '../presentation/providers/auth_providers.dart';
import '../presentation/providers/fiado_data_providers.dart';
import '../widgets/adaptive_layout.dart';

class SolicitudesPendientesScreen extends ConsumerWidget {
  const SolicitudesPendientesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(currentPermissionsProvider);
    if (!permissions.canApproveCollaboratorChanges) {
      return Scaffold(
        appBar: AppBar(title: const Text('Solicitudes pendientes')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Solo el usuario Negocio puede aprobar solicitudes.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final solicitudesAsync = ref.watch(solicitudesPendientesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes pendientes')),
      body: SafeArea(
        child: solicitudesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(
            message: 'No se pudieron cargar las solicitudes.',
            onRetry: () => ref.invalidate(solicitudesPendientesProvider),
          ),
          data: (solicitudes) {
            if (solicitudes.isEmpty) {
              return const _EmptyState(
                icon: Icons.verified_outlined,
                title: 'No hay solicitudes pendientes',
                message: 'Los cambios de colaboradores apareceran aqui.',
              );
            }

            final solicitudesOrdenadas =
                List<SolicitudAutorizacionSqliteModel>.from(solicitudes)
                  ..sort(_compararPrioridad);

            return LayoutBuilder(
              builder: (context, constraints) {
                final padding = AdaptiveLayout.contentInset(
                  constraints.maxWidth,
                );

                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(padding, 16, padding, 28),
                  itemCount: solicitudesOrdenadas.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final solicitud = solicitudesOrdenadas[index];
                    return _SolicitudPendienteCard(
                      solicitud: solicitud,
                      onApprove: () => _aprobar(context, ref, solicitud),
                      onReject: () => _rechazar(context, ref, solicitud),
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

  Future<void> _aprobar(
    BuildContext context,
    WidgetRef ref,
    SolicitudAutorizacionSqliteModel solicitud,
  ) async {
    final user = ref.read(currentUserProvider);
    await ref
        .read(solicitudAutorizacionRepositoryProvider)
        .aprobarSolicitud(solicitud.id!, aprobadoPorUsuarioId: user?.id);
    ref.invalidate(solicitudesPendientesProvider);
    ref.invalidate(solicitudesPendientesCountProvider);
    ref.invalidate(productosProvider);
    ref.invalidate(clientesProvider);
    ref.invalidate(movimientosProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Solicitud aprobada.')));
    }
  }

  Future<void> _rechazar(
    BuildContext context,
    WidgetRef ref,
    SolicitudAutorizacionSqliteModel solicitud,
  ) async {
    final controller = TextEditingController();
    final comentario = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rechazar solicitud'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Comentario opcional'),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Rechazar'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (comentario == null) {
      return;
    }

    await ref
        .read(solicitudAutorizacionRepositoryProvider)
        .rechazarSolicitud(solicitud.id!, comentarioNegocio: comentario);
    ref.invalidate(solicitudesPendientesProvider);
    ref.invalidate(solicitudesPendientesCountProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Solicitud rechazada.')));
    }
  }

  int _compararPrioridad(
    SolicitudAutorizacionSqliteModel a,
    SolicitudAutorizacionSqliteModel b,
  ) {
    final prioridadA = _esPrioritaria(a) ? 0 : 1;
    final prioridadB = _esPrioritaria(b) ? 0 : 1;
    if (prioridadA != prioridadB) {
      return prioridadA.compareTo(prioridadB);
    }

    return a.createdAt.compareTo(b.createdAt);
  }
}

class _SolicitudPendienteCard extends ConsumerWidget {
  final SolicitudAutorizacionSqliteModel solicitud;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _SolicitudPendienteCard({
    required this.solicitud,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final antes = _productoDesdeJson(solicitud.datosAntes);
    final despues = _productoDesdeJson(solicitud.datosDespues);
    final clienteAntes = _clienteDesdeJson(solicitud.datosAntes);
    final clienteDespues = _clienteDesdeJson(solicitud.datosDespues);
    final esCliente =
        solicitud.entidad == SolicitudAutorizacionSqliteModel.entidadCliente;
    final esPrioritaria = _esPrioritaria(solicitud);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: esPrioritaria ? const Color(0xFFFFFBF0) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: esPrioritaria
              ? const Color(0xFFE7B04B)
              : const Color(0xFFD9E8E3),
          width: esPrioritaria ? 1.6 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<String>(
            future: ref
                .read(solicitudAutorizacionRepositoryProvider)
                .obtenerNombreColaborador(solicitud.colaboradorId),
            builder: (context, snapshot) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      snapshot.data ??
                          'Colaborador #${solicitud.colaboradorId}',
                      style: const TextStyle(
                        color: Color(0xFF17322C),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (esPrioritaria) ...[
                    const SizedBox(width: 10),
                    const _PriorityBadge(),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            '${_tipoLegible(solicitud.tipoSolicitud)} - ${esCliente ? (clienteDespues?.nombre ?? 'Cliente') : (despues?.nombre ?? 'Producto')}',
            style: const TextStyle(color: Color(0xFF66756D)),
          ),
          const SizedBox(height: 14),
          esCliente
              ? _CambioClienteResumen(
                  antes: clienteAntes,
                  despues: clienteDespues,
                )
              : _CambioProductoResumen(antes: antes, despues: despues),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Rechazar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Aprobar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CambioClienteResumen extends StatelessWidget {
  final Cliente? antes;
  final Cliente? despues;

  const _CambioClienteResumen({required this.antes, required this.despues});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DatoCambioTile(
          label: 'Antes',
          value: antes == null
              ? 'Sin datos anteriores'
              : '${antes!.nombre} - ${antes!.telefono} - ${MoneyFormatter.formatCurrency(antes!.deuda)}',
        ),
        const SizedBox(height: 8),
        _DatoCambioTile(
          label: 'Despues',
          value: despues == null
              ? 'Sin datos nuevos'
              : '${despues!.nombre} - ${despues!.telefono} - ${MoneyFormatter.formatCurrency(despues!.deuda)}',
        ),
      ],
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4DB),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFE7B04B)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.priority_high_rounded, size: 16, color: Color(0xFFB54708)),
          SizedBox(width: 4),
          Text(
            'Prioritaria',
            style: TextStyle(
              color: Color(0xFFB54708),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CambioProductoResumen extends StatelessWidget {
  final Producto? antes;
  final Producto? despues;

  const _CambioProductoResumen({required this.antes, required this.despues});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DatoCambioTile(
          label: 'Antes',
          value: antes == null
              ? 'Sin datos anteriores'
              : '${antes!.nombre} - ${antes!.cantidad} uds - ${antes!.ubicacion}',
        ),
        const SizedBox(height: 8),
        _DatoCambioTile(
          label: 'Despues',
          value: despues == null
              ? 'Sin datos nuevos'
              : '${despues!.nombre} - ${despues!.cantidad} uds - ${despues!.ubicacion}',
        ),
      ],
    );
  }
}

class _DatoCambioTile extends StatelessWidget {
  final String label;
  final String value;

  const _DatoCambioTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Color(0xFF17322C),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF1F7A6B), size: 48),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF17322C),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF66756D)),
            ),
          ],
        ),
      ),
    );
  }
}

Producto? _productoDesdeJson(String? source) {
  if (source == null || source.isEmpty) {
    return null;
  }

  try {
    return Producto.fromJson(jsonDecode(source) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

Cliente? _clienteDesdeJson(String? source) {
  if (source == null || source.isEmpty) {
    return null;
  }

  try {
    return Cliente.fromJson(jsonDecode(source) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

String _tipoLegible(String tipo) {
  switch (tipo) {
    case SolicitudAutorizacionSqliteModel.tipoModificarProducto:
      return 'Modificar producto';
    case SolicitudAutorizacionSqliteModel.tipoAjustarStock:
      return 'Ajustar stock';
    case SolicitudAutorizacionSqliteModel.tipoEliminarProducto:
      return 'Eliminar producto';
    case SolicitudAutorizacionSqliteModel.tipoEditarCliente:
      return 'Editar cliente';
    case SolicitudAutorizacionSqliteModel.tipoEliminarCliente:
      return 'Eliminar cliente';
    default:
      return tipo;
  }
}

bool _esPrioritaria(SolicitudAutorizacionSqliteModel solicitud) {
  return solicitud.entidad == SolicitudAutorizacionSqliteModel.entidadCliente &&
      solicitud.tipoSolicitud ==
          SolicitudAutorizacionSqliteModel.tipoEditarCliente;
}
