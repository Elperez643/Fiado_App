import '../../core/database/database_schema.dart';
import '../../core/sync/sync_status.dart';
import '../models/sync_queue_item_model.dart';
import '../repositories/sync_queue_repository.dart';

class SyncSimulationResult {
  final int processed;
  final int failed;

  const SyncSimulationResult({required this.processed, required this.failed});
}

class SyncService {
  final SyncQueueRepository syncQueueRepository;

  const SyncService({required this.syncQueueRepository});

  Future<SyncSimulationResult> syncPendingData() async {
    await syncClientes();
    await syncProductos();
    await syncMovimientos();
    await syncAuditorias();
    await syncSolicitudes();
    await syncUsuarios();
    await syncSubscriptions();

    var processed = 0;
    var failed = 0;
    final pending = await syncQueueRepository.obtenerPendientes(limit: 500);

    for (final item in pending) {
      await syncQueueRepository.incrementarIntento(item.id!);
      try {
        await _simulatePush(item);
        await syncQueueRepository.marcarComoProcesado(item.id!);
        processed++;
      } catch (error) {
        await syncQueueRepository.marcarComoFallido(item.id!, '$error');
        failed++;
      }
    }

    return SyncSimulationResult(processed: processed, failed: failed);
  }

  Future<void> syncClientes() async {}

  Future<void> syncProductos() async {}

  Future<void> syncMovimientos() async {}

  Future<void> syncAuditorias() async {}

  Future<void> syncSolicitudes() async {}

  Future<void> syncUsuarios() async {}

  Future<void> syncSubscriptions() async {}

  Future<void> _simulatePush(SyncQueueItemModel item) async {
    if (!SyncOperationType.isValid(item.operation)) {
      throw StateError('Operacion de sync no soportada: ${item.operation}');
    }

    const supportedEntities = {
      DatabaseSchema.clientesTable,
      DatabaseSchema.movimientosTable,
      DatabaseSchema.productosTable,
      DatabaseSchema.auditoriasTable,
      DatabaseSchema.auditoriaItemsTable,
      DatabaseSchema.productoImagenesTable,
      DatabaseSchema.solicitudesAutorizacionTable,
      DatabaseSchema.usuariosTable,
      DatabaseSchema.subscriptionsTable,
    };

    if (!supportedEntities.contains(item.entityType)) {
      throw StateError('Entidad de sync no soportada: ${item.entityType}');
    }

    await Future<void>.delayed(const Duration(milliseconds: 120));
  }
}
