import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/solicitud_autorizacion_sqlite_model.dart';
import '../models/cliente.dart';
import '../models/producto.dart';
import '../presentation/providers/fiado_data_providers.dart';
import '../widgets/adaptive_layout.dart';

class MisSolicitudesScreen extends ConsumerWidget {
  const MisSolicitudesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solicitudesAsync = ref.watch(solicitudesColaboradorProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis solicitudes')),
      body: SafeArea(
        child: solicitudesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 42),
                  const SizedBox(height: 12),
                  const Text('No se pudieron cargar tus solicitudes.'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () =>
                        ref.invalidate(solicitudesColaboradorProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
          data: (solicitudes) {
            if (solicitudes.isEmpty) {
              return const _MisSolicitudesEmptyState();
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final padding = AdaptiveLayout.contentInset(
                  constraints.maxWidth,
                );

                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(padding, 16, padding, 28),
                  itemCount: solicitudes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _MiSolicitudCard(solicitud: solicitudes[index]);
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

class _MiSolicitudCard extends StatelessWidget {
  final SolicitudAutorizacionSqliteModel solicitud;

  const _MiSolicitudCard({required this.solicitud});

  @override
  Widget build(BuildContext context) {
    final producto = _productoDesdeJson(solicitud.datosDespues);
    final cliente = _clienteDesdeJson(solicitud.datosDespues);
    final esCliente =
        solicitud.entidad == SolicitudAutorizacionSqliteModel.entidadCliente;
    final estadoColor = switch (solicitud.estado) {
      SolicitudAutorizacionSqliteModel.estadoAprobado => const Color(
        0xFF1F7A6B,
      ),
      SolicitudAutorizacionSqliteModel.estadoRechazado => const Color(
        0xFFB42318,
      ),
      _ => const Color(0xFFB54708),
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD9E8E3)),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  _tipoLegible(solicitud.tipoSolicitud),
                  style: const TextStyle(
                    color: Color(0xFF17322C),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: estadoColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  solicitud.estado,
                  style: TextStyle(
                    color: estadoColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            esCliente
                ? cliente == null
                      ? 'Cliente no disponible'
                      : '${cliente.nombre} - ${cliente.telefono}'
                : producto == null
                ? 'Producto no disponible'
                : '${producto.nombre} - ${producto.cantidad} uds',
            style: const TextStyle(color: Color(0xFF66756D)),
          ),
          if (solicitud.comentarioNegocio?.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAF8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Comentario: ${solicitud.comentarioNegocio}',
                style: const TextStyle(
                  color: Color(0xFF17322C),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MisSolicitudesEmptyState extends StatelessWidget {
  const _MisSolicitudesEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_turned_in_outlined,
              color: Color(0xFF1F7A6B),
              size: 48,
            ),
            SizedBox(height: 14),
            Text(
              'No has enviado solicitudes',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF17322C),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Cuando solicites modificar o eliminar inventario aparecera aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF66756D)),
            ),
          ],
        ),
      ),
    );
  }
}

Producto? _productoDesdeJson(String source) {
  try {
    return Producto.fromJson(jsonDecode(source) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

Cliente? _clienteDesdeJson(String source) {
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
