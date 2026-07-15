import '../models/sync_outbox_item.dart';
import '../models/usuario_sqlite_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/cliente_repository.dart';
import 'sync_module_adapter.dart';

class ClientSyncAdapter extends SyncModuleAdapter {
  final ClienteRepository clienteRepository;
  final AuthRepository authRepository;

  ClientSyncAdapter({
    required this.clienteRepository,
    required this.authRepository,
  });

  @override
  String get module => 'clients';

  @override
  Future<void> onPushAccepted({
    required List<SyncOutboxItem> items,
    required DateTime serverTime,
  }) async {
    for (final item in items) {
      await clienteRepository.markClientSyncedByUuid(
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
      await clienteRepository.upsertFromSync(
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
