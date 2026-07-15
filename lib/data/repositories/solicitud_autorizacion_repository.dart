import 'dart:convert';

import '../../core/database/database_helper.dart';
import '../../core/database/database_schema.dart';
import '../../core/sync/sync_status.dart';
import '../../models/cliente.dart';
import '../../models/producto.dart';
import '../models/solicitud_autorizacion_sqlite_model.dart';
import 'cliente_repository.dart';
import 'movimiento_repository.dart';
import 'producto_repository.dart';
import 'sync_queue_repository.dart';

class SolicitudAutorizacionRepository {
  final DatabaseHelper databaseHelper;
  final ProductoRepository productoRepository;
  final ClienteRepository clienteRepository;
  final MovimientoRepository movimientoRepository;
  final SyncQueueRepository syncQueueRepository;

  SolicitudAutorizacionRepository({
    DatabaseHelper? databaseHelper,
    ProductoRepository? productoRepository,
    ClienteRepository? clienteRepository,
    MovimientoRepository? movimientoRepository,
    SyncQueueRepository? syncQueueRepository,
  }) : databaseHelper = databaseHelper ?? DatabaseHelper.instance,
       productoRepository = productoRepository ?? ProductoRepository(),
       clienteRepository = clienteRepository ?? ClienteRepository(),
       movimientoRepository = movimientoRepository ?? MovimientoRepository(),
       syncQueueRepository = syncQueueRepository ?? SyncQueueRepository();

  Future<SolicitudAutorizacionSqliteModel> crearSolicitud({
    required int negocioId,
    required int colaboradorId,
    required String tipoSolicitud,
    required String entidad,
    int? entidadId,
    String? datosAntes,
    required String datosDespues,
  }) async {
    final db = await databaseHelper.database;
    final now = DateTime.now();
    final solicitud = SolicitudAutorizacionSqliteModel(
      negocioId: negocioId,
      colaboradorId: colaboradorId,
      tipoSolicitud: tipoSolicitud,
      entidad: entidad,
      entidadId: entidadId,
      datosAntes: datosAntes,
      datosDespues: datosDespues,
      createdAt: now,
      updatedAt: now,
    );
    final id = await db.insert(
      DatabaseSchema.solicitudesAutorizacionTable,
      solicitud.toMap(),
    );
    final saved = solicitud.copyWith(id: id);
    await syncQueueRepository.enqueueCreate(
      entityType: DatabaseSchema.solicitudesAutorizacionTable,
      entityId: id,
      payload: saved.toMap(includeId: true),
    );
    return saved;
  }

  Future<List<SolicitudAutorizacionSqliteModel>> obtenerPendientesPorNegocio(
    int negocioId,
  ) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.solicitudesAutorizacionTable,
      where: 'negocio_id = ? AND estado = ?',
      whereArgs: [negocioId, SolicitudAutorizacionSqliteModel.estadoPendiente],
      orderBy: 'created_at ASC',
    );
    return rows.map(SolicitudAutorizacionSqliteModel.fromMap).toList();
  }

  Future<List<SolicitudAutorizacionSqliteModel>>
  obtenerSolicitudesPorColaborador(int colaboradorId) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.solicitudesAutorizacionTable,
      where: 'colaborador_id = ?',
      whereArgs: [colaboradorId],
      orderBy: 'created_at DESC',
    );
    return rows.map(SolicitudAutorizacionSqliteModel.fromMap).toList();
  }

  Future<int> contarPendientesPorNegocio(int negocioId) async {
    final db = await databaseHelper.database;
    final result = await db.rawQuery(
      '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.solicitudesAutorizacionTable}
WHERE negocio_id = ? AND estado = ?
''',
      [negocioId, SolicitudAutorizacionSqliteModel.estadoPendiente],
    );
    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<void> aprobarSolicitud(
    int solicitudId, {
    int? aprobadoPorUsuarioId,
  }) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.solicitudesAutorizacionTable,
      where: 'id = ? AND estado = ?',
      whereArgs: [
        solicitudId,
        SolicitudAutorizacionSqliteModel.estadoPendiente,
      ],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw StateError('La solicitud ya no esta pendiente.');
    }

    final solicitud = SolicitudAutorizacionSqliteModel.fromMap(rows.first);
    await _aplicarCambios(solicitud);

    final now = DateTime.now();

    await db.update(
      DatabaseSchema.solicitudesAutorizacionTable,
      {
        'estado': SolicitudAutorizacionSqliteModel.estadoAprobado,
        'aprobado_por_usuario_id': aprobadoPorUsuarioId,
        'resolved_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'sync_status': SyncStatus.updated,
      },
      where: 'id = ?',
      whereArgs: [solicitudId],
    );
    await _enqueueSolicitudUpdate(solicitudId);
  }

  Future<void> rechazarSolicitud(
    int solicitudId, {
    String? comentarioNegocio,
  }) async {
    final db = await databaseHelper.database;
    await db.update(
      DatabaseSchema.solicitudesAutorizacionTable,
      {
        'estado': SolicitudAutorizacionSqliteModel.estadoRechazado,
        'comentario_negocio': comentarioNegocio?.trim().isEmpty ?? true
            ? null
            : comentarioNegocio!.trim(),
        'resolved_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': SyncStatus.updated,
      },
      where: 'id = ? AND estado = ?',
      whereArgs: [
        solicitudId,
        SolicitudAutorizacionSqliteModel.estadoPendiente,
      ],
    );
    await _enqueueSolicitudUpdate(solicitudId);
  }

  Future<void> _enqueueSolicitudUpdate(int solicitudId) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.solicitudesAutorizacionTable,
      where: 'id = ?',
      whereArgs: [solicitudId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    await syncQueueRepository.enqueueUpdate(
      entityType: DatabaseSchema.solicitudesAutorizacionTable,
      entityId: solicitudId,
      payload: rows.first,
    );
  }

  Future<String> obtenerNombreColaborador(int colaboradorId) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.usuariosTable,
      columns: ['nombre'],
      where: 'id = ?',
      whereArgs: [colaboradorId],
      limit: 1,
    );
    if (rows.isEmpty) return 'Colaborador #$colaboradorId';
    return rows.first['nombre'] as String;
  }

  Future<void> _aplicarCambios(
    SolicitudAutorizacionSqliteModel solicitud,
  ) async {
    if (solicitud.entidad == SolicitudAutorizacionSqliteModel.entidadProducto) {
      await _aplicarCambiosProducto(solicitud);
      return;
    }

    if (solicitud.entidad == SolicitudAutorizacionSqliteModel.entidadCliente) {
      await _aplicarCambiosCliente(solicitud);
      return;
    }

    throw StateError('Entidad no soportada para autorizacion.');
  }

  Future<void> _aplicarCambiosProducto(
    SolicitudAutorizacionSqliteModel solicitud,
  ) async {
    final datos = jsonDecode(solicitud.datosDespues) as Map<String, dynamic>;
    final producto = Producto.fromJson(datos);

    switch (solicitud.tipoSolicitud) {
      case SolicitudAutorizacionSqliteModel.tipoModificarProducto:
        await productoRepository.actualizarProducto(
          producto,
          negocioId: solicitud.negocioId,
        );
        return;
      case SolicitudAutorizacionSqliteModel.tipoAjustarStock:
        await productoRepository.actualizarStock(
          negocioId: solicitud.negocioId,
          legacyId: producto.id,
          cantidad: producto.cantidad,
        );
        return;
      case SolicitudAutorizacionSqliteModel.tipoEliminarProducto:
        await productoRepository.eliminarLogico(
          producto.id,
          negocioId: solicitud.negocioId,
        );
        return;
      default:
        throw StateError('Tipo de solicitud no soportado.');
    }
  }

  Future<void> _aplicarCambiosCliente(
    SolicitudAutorizacionSqliteModel solicitud,
  ) async {
    final datosDespues =
        jsonDecode(solicitud.datosDespues) as Map<String, dynamic>;
    final clienteDespues = Cliente.fromJson(datosDespues);
    final clienteAntes = solicitud.datosAntes == null
        ? null
        : Cliente.fromJson(
            jsonDecode(solicitud.datosAntes!) as Map<String, dynamic>,
          );

    switch (solicitud.tipoSolicitud) {
      case SolicitudAutorizacionSqliteModel.tipoEditarCliente:
        await clienteRepository.actualizarCliente(
          cliente: clienteDespues,
          negocioId: solicitud.negocioId,
          telefonoAnterior: clienteAntes?.telefono,
        );
        return;
      case SolicitudAutorizacionSqliteModel.tipoEliminarCliente:
        final cliente = clienteAntes ?? clienteDespues;
        await movimientoRepository.eliminarPorCliente(
          cliente.nombre,
          negocioId: solicitud.negocioId,
          clienteId: cliente.id,
          clienteTelefono: cliente.telefono,
        );
        await clienteRepository.eliminarPorTelefono(
          cliente.telefono,
          negocioId: solicitud.negocioId,
        );
        return;
      default:
        throw StateError('Tipo de solicitud de cliente no soportado.');
    }
  }
}
