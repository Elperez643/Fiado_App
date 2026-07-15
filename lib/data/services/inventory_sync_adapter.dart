import '../models/sync_outbox_item.dart';
import '../models/usuario_sqlite_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/producto_repository.dart';
import 'sync_module_adapter.dart';

class InventorySyncAdapter extends SyncModuleAdapter {
  final ProductoRepository productoRepository;
  final AuthRepository authRepository;

  InventorySyncAdapter({
    required this.productoRepository,
    required this.authRepository,
  });

  @override
  String get module => 'inventory';

  @override
  Future<void> onPushAccepted({
    required List<SyncOutboxItem> items,
    required DateTime serverTime,
  }) async {
    for (final item in items.where((item) => item.entityType == 'product')) {
      await productoRepository.markProductSyncedByUuid(
        uuid: item.entityUuid,
        serverTime: serverTime,
      );
    }
  }

  @override
  Future<int> applyPullChanges(List<Map<String, Object?>> changes) async {
    final negocioId = await _resolveNegocioId();
    if (negocioId == null) return 0;
    var applied = 0;
    for (final change in changes) {
      final entityType = change['entityType']?.toString() ?? 'product';
      if (entityType != 'product') continue;
      await productoRepository.upsertFromSync(
        negocioId: negocioId,
        payload: change,
      );
      applied++;
    }
    return applied;
  }

  Future<int?> _resolveNegocioId() async {
    final user = await authRepository.obtenerUsuarioActual();
    if (user == null) return null;
    return user.tipoUsuario == UsuarioSqliteModel.tipoColaborador
        ? user.negocioId
        : user.id;
  }
}
