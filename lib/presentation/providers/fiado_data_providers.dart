import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../business_copilot/business_copilot_service.dart';
import '../../business_copilot/business_recommendation.dart';
import '../../collections_intelligence/collection_insight.dart';
import '../../collections_intelligence/collections_intelligence_service.dart';
import '../../core/database/database_helper.dart';
import '../../credit_scoring/client_score_service.dart';
import '../../inventory_intelligence/inventory_insight.dart';
import '../../inventory_intelligence/inventory_intelligence_service.dart';
import '../../personal_debt_guidance/personal_debt_guidance_service.dart';
import '../../personal_debt_guidance/personal_debt_reminder.dart';
import '../../data/repositories/cliente_repository.dart';
import '../../data/repositories/auditoria_repository.dart';
import '../../data/repositories/comprobante_repository.dart';
import '../../data/repositories/credito_ciclo_repository.dart';
import '../../data/repositories/deuda_item_repository.dart';
import '../../data/repositories/inventory_product_metrics_repository.dart';
import '../../data/repositories/movimiento_repository.dart';
import '../../data/repositories/producto_imagen_repository.dart';
import '../../data/repositories/producto_repository.dart';
import '../../data/repositories/solicitud_autorizacion_repository.dart';
import '../../data/services/barcode_product_lookup_service.dart';
import '../../data/services/collection_message_service.dart';
import '../../data/models/solicitud_autorizacion_sqlite_model.dart';
import '../../data/models/usuario_sqlite_model.dart';
import '../../data/models/auditoria_sqlite_model.dart';
import '../../data/models/billable_product.dart';
import '../../data/models/comprobante_sqlite_model.dart';
import '../../data/models/credito_ciclo_sqlite_model.dart';
import '../../data/models/credito_recordatorio_sqlite_model.dart';
import '../../data/models/deuda_item_sqlite_model.dart';
import '../../data/models/producto_imagen_sqlite_model.dart';
import '../../models/cliente.dart';
import '../../models/movimiento.dart';
import '../../models/producto.dart';
import '../../utils/auditoria_helper.dart';
import 'auth_providers.dart';
import 'sync_providers.dart';

final clienteRepositoryProvider = Provider<ClienteRepository>((ref) {
  return ClienteRepository(
    syncQueueRepository: ref.read(syncQueueRepositoryProvider),
    syncOutboxRepository: ref.read(syncOutboxRepositoryProvider),
  );
});

final movimientoRepositoryProvider = Provider<MovimientoRepository>((ref) {
  return MovimientoRepository(
    syncQueueRepository: ref.read(syncQueueRepositoryProvider),
    deudaItemRepository: ref.read(deudaItemRepositoryProvider),
    creditoCicloRepository: ref.read(creditoCicloRepositoryProvider),
    inventoryMetricsRepository: ref.read(
      inventoryProductMetricsRepositoryProvider,
    ),
  );
});

final creditoCicloRepositoryProvider = Provider<CreditoCicloRepository>((ref) {
  return CreditoCicloRepository(
    syncQueueRepository: ref.read(syncQueueRepositoryProvider),
  );
});

final deudaItemRepositoryProvider = Provider<DeudaItemRepository>((ref) {
  return DeudaItemRepository(
    syncQueueRepository: ref.read(syncQueueRepositoryProvider),
  );
});

final comprobanteRepositoryProvider = Provider<ComprobanteRepository>((ref) {
  return ComprobanteRepository(
    syncQueueRepository: ref.read(syncQueueRepositoryProvider),
  );
});

final productoRepositoryProvider = Provider<ProductoRepository>((ref) {
  return ProductoRepository(
    syncQueueRepository: ref.read(syncQueueRepositoryProvider),
    productoImagenRepository: ref.read(productoImagenRepositoryProvider),
    inventoryMetricsRepository: ref.read(
      inventoryProductMetricsRepositoryProvider,
    ),
  );
});

final inventoryProductMetricsRepositoryProvider =
    Provider<InventoryProductMetricsRepository>((ref) {
      return InventoryProductMetricsRepository();
    });

final productoImagenRepositoryProvider = Provider<ProductoImagenRepository>((
  ref,
) {
  return ProductoImagenRepository(
    syncQueueRepository: ref.read(syncQueueRepositoryProvider),
  );
});

final barcodeProductLookupServiceProvider =
    Provider<BarcodeProductLookupService>((ref) {
      return BarcodeProductLookupService(
        productoRepository: ref.read(productoRepositoryProvider),
      );
    });

final inventoryIntelligenceServiceProvider =
    Provider<InventoryIntelligenceService>((ref) {
      return InventoryIntelligenceService(
        metricsRepository: ref.read(inventoryProductMetricsRepositoryProvider),
      );
    });

final inventoryInsightsProvider = FutureProvider<List<InventoryInsight>>((
  ref,
) async {
  ref.watch(productosProvider);
  final businessId = ref.watch(currentBusinessIdProvider);
  if (businessId == null) return const <InventoryInsight>[];
  return ref
      .read(inventoryIntelligenceServiceProvider)
      .calculateInsights(businessId: businessId);
});

final inventoryCriticalProductsProvider =
    Provider<AsyncValue<List<InventoryInsight>>>((ref) {
      final insights = ref.watch(inventoryInsightsProvider);
      return insights.whenData(
        ref.read(inventoryIntelligenceServiceProvider).criticalProducts,
      );
    });

final inventoryRestockSuggestionsProvider =
    Provider<AsyncValue<List<InventoryInsight>>>((ref) {
      final insights = ref.watch(inventoryInsightsProvider);
      return insights.whenData(
        ref.read(inventoryIntelligenceServiceProvider).restockSuggestions,
      );
    });

final inventoryNoMovementProvider =
    Provider<AsyncValue<List<InventoryInsight>>>((ref) {
      final insights = ref.watch(inventoryInsightsProvider);
      return insights.whenData(
        ref.read(inventoryIntelligenceServiceProvider).noMovementProducts,
      );
    });

final inventoryDirtyMetricsCountProvider = FutureProvider<int>((ref) {
  final businessId = ref.watch(currentBusinessIdProvider);
  if (businessId == null) return Future.value(0);
  return ref.read(inventoryIntelligenceServiceProvider).dirtyCount(businessId);
});

final inventoryActiveProductsCountProvider = FutureProvider<int>((ref) {
  ref.watch(productosProvider);
  final businessId = ref.watch(currentBusinessIdProvider);
  if (businessId == null) return Future.value(0);
  return ref
      .read(inventoryIntelligenceServiceProvider)
      .activeProductCount(businessId);
});

final inventoryCachedMetricsCountProvider = FutureProvider<int>((ref) {
  final businessId = ref.watch(currentBusinessIdProvider);
  if (businessId == null) return Future.value(0);
  return ref
      .read(inventoryIntelligenceServiceProvider)
      .metricsCount(businessId);
});

final billableProductsProvider = FutureProvider<List<BillableProduct>>((
  ref,
) async {
  final negocioId = ref.watch(currentBusinessIdProvider);
  if (negocioId == null) {
    throw StateError('No se pudo identificar el negocio activo.');
  }
  return ref
      .read(productoRepositoryProvider)
      .obtenerProductosFacturables(negocioId: negocioId);
});

final auditoriaRepositoryProvider = Provider<AuditoriaRepository>((ref) {
  return AuditoriaRepository(
    productoRepository: ref.read(productoRepositoryProvider),
    syncQueueRepository: ref.read(syncQueueRepositoryProvider),
  );
});

final solicitudAutorizacionRepositoryProvider =
    Provider<SolicitudAutorizacionRepository>((ref) {
      return SolicitudAutorizacionRepository(
        clienteRepository: ref.read(clienteRepositoryProvider),
        movimientoRepository: ref.read(movimientoRepositoryProvider),
        productoRepository: ref.read(productoRepositoryProvider),
        syncQueueRepository: ref.read(syncQueueRepositoryProvider),
      );
    });

final clientScoreServiceProvider = Provider<ClientScoreService>((ref) {
  return ClientScoreService(
    movimientoRepository: ref.read(movimientoRepositoryProvider),
    creditoCicloRepository: ref.read(creditoCicloRepositoryProvider),
    databaseHelper: DatabaseHelper.instance,
    syncQueueRepository: ref.read(syncQueueRepositoryProvider),
  );
});

final collectionsIntelligenceServiceProvider =
    Provider<CollectionsIntelligenceService>((ref) {
      return CollectionsIntelligenceService(
        databaseHelper: DatabaseHelper.instance,
        creditoCicloRepository: ref.read(creditoCicloRepositoryProvider),
      );
    });

final collectionMessageServiceProvider = Provider<CollectionMessageService>((
  ref,
) {
  return const CollectionMessageService();
});

final collectionInsightsProvider = FutureProvider<List<CollectionInsight>>((
  ref,
) async {
  ref.watch(clientesProvider);
  ref.watch(movimientosProvider);
  ref.watch(cuentasPorCobrarProvider);
  ref.watch(ciclosMoraProvider);
  ref.watch(ciclosBloqueadosProvider);
  final businessId = ref.watch(currentBusinessIdProvider);
  if (businessId == null) return const <CollectionInsight>[];
  return ref
      .read(collectionsIntelligenceServiceProvider)
      .calculateInsights(businessId: businessId);
});

final businessCopilotProvider = Provider<BusinessCopilotService>((ref) {
  return BusinessCopilotService(
    databaseHelper: DatabaseHelper.instance,
    collectionsService: ref.read(collectionsIntelligenceServiceProvider),
    inventoryService: ref.read(inventoryIntelligenceServiceProvider),
  );
});

final businessRecommendationsProvider =
    FutureProvider<List<BusinessRecommendation>>((ref) async {
      ref.watch(collectionInsightsProvider);
      ref.watch(inventoryInsightsProvider);
      ref.watch(solicitudesPendientesCountProvider);
      ref.watch(auditoriasPendientesProvider);
      final businessId = ref.watch(currentBusinessIdProvider);
      if (businessId == null) return const <BusinessRecommendation>[];
      return ref
          .read(businessCopilotProvider)
          .getRecommendations(businessId: businessId);
    });

final businessCriticalRecommendationsProvider =
    Provider<AsyncValue<List<BusinessRecommendation>>>((ref) {
      final recommendations = ref.watch(businessRecommendationsProvider);
      return recommendations.whenData(
        (items) => items
            .where(
              (item) =>
                  item.priority == BusinessRecommendationPriority.critical,
            )
            .toList(),
      );
    });

final personalDebtGuidanceServiceProvider =
    Provider<PersonalDebtGuidanceService>((ref) {
      return PersonalDebtGuidanceService(
        databaseHelper: DatabaseHelper.instance,
        creditoCicloRepository: ref.read(creditoCicloRepositoryProvider),
      );
    });

final personalDebtRemindersProvider =
    FutureProvider<List<PersonalDebtReminder>>((ref) {
      final user = ref.watch(currentUserProvider);
      if (user == null ||
          user.tipoUsuario != UsuarioSqliteModel.tipoPersonal ||
          user.telefono.trim().isEmpty) {
        return Future.value(const <PersonalDebtReminder>[]);
      }
      ref.watch(recordatoriosCreditoProvider);
      return ref
          .read(personalDebtGuidanceServiceProvider)
          .getRemindersForPersonal(phone: user.telefono);
    });

final clienteBusquedaProvider = StateProvider<String>((ref) => '');
final productoBusquedaProvider = StateProvider<String>((ref) => '');

final clientesProvider = AsyncNotifierProvider<ClientesNotifier, ClientesState>(
  ClientesNotifier.new,
);

final movimientosProvider =
    AsyncNotifierProvider<MovimientosNotifier, List<Movimiento>>(
      MovimientosNotifier.new,
    );

final deudaItemsPorMovimientoProvider =
    FutureProvider.family<List<DeudaItemSqliteModel>, int>((ref, movimientoId) {
      final negocioId = ref.watch(currentBusinessIdProvider);
      return ref
          .read(deudaItemRepositoryProvider)
          .obtenerItemsPorMovimiento(movimientoId, negocioId: negocioId);
    });

final comprobantePorMovimientoProvider =
    FutureProvider.family<ComprobanteSqliteModel?, int>((ref, movimientoId) {
      final negocioId = ref.watch(currentBusinessIdProvider);
      return ref
          .read(comprobanteRepositoryProvider)
          .obtenerComprobantePorMovimiento(movimientoId, negocioId: negocioId);
    });

final comprobantesPorClienteProvider =
    FutureProvider.family<
      List<ComprobanteSqliteModel>,
      ({String nombre, String? telefono})
    >((ref, cliente) {
      final negocioId = ref.watch(currentBusinessIdProvider);
      if (negocioId == null) {
        return Future.value(const <ComprobanteSqliteModel>[]);
      }
      return ref
          .read(comprobanteRepositoryProvider)
          .obtenerComprobantesPorCliente(
            negocioId: negocioId,
            clienteNombre: cliente.nombre,
            clienteTelefono: cliente.telefono,
          );
    });

typedef ClienteNegocioKey = ({String telefono, String nombre});

final cicloActualClienteProvider =
    FutureProvider.family<CreditoCicloSqliteModel?, ClienteNegocioKey>((
      ref,
      cliente,
    ) async {
      final negocioId = ref.watch(currentBusinessIdProvider);
      if (negocioId == null) return null;
      final repository = ref.read(creditoCicloRepositoryProvider);
      final clienteId = await repository.resolverClienteId(
        negocioId: negocioId,
        telefono: cliente.telefono,
        nombre: cliente.nombre,
      );
      if (clienteId == null) return null;
      final actual = await repository.obtenerCicloActual(clienteId, negocioId);
      return actual ?? repository.obtenerUltimoCiclo(clienteId, negocioId);
    });

final ciclosClienteProvider =
    FutureProvider.family<List<CreditoCicloSqliteModel>, ClienteNegocioKey>((
      ref,
      cliente,
    ) async {
      final negocioId = ref.watch(currentBusinessIdProvider);
      if (negocioId == null) return const <CreditoCicloSqliteModel>[];
      final repository = ref.read(creditoCicloRepositoryProvider);
      final clienteId = await repository.resolverClienteId(
        negocioId: negocioId,
        telefono: cliente.telefono,
        nombre: cliente.nombre,
      );
      if (clienteId == null) return const <CreditoCicloSqliteModel>[];
      return repository.obtenerCiclosPorCliente(clienteId, negocioId);
    });

final cuentasPorCobrarProvider = FutureProvider<List<CreditoCicloSqliteModel>>((
  ref,
) {
  final negocioId = ref.watch(currentBusinessIdProvider);
  if (negocioId == null) return Future.value(const <CreditoCicloSqliteModel>[]);
  return ref
      .read(creditoCicloRepositoryProvider)
      .obtenerCiclosVencidos30(negocioId);
});

final ciclosMoraProvider = FutureProvider<List<CreditoCicloSqliteModel>>((ref) {
  final negocioId = ref.watch(currentBusinessIdProvider);
  if (negocioId == null) return Future.value(const <CreditoCicloSqliteModel>[]);
  return ref
      .read(creditoCicloRepositoryProvider)
      .obtenerCiclosMora45(negocioId);
});

final ciclosBloqueadosProvider = FutureProvider<List<CreditoCicloSqliteModel>>((
  ref,
) {
  final negocioId = ref.watch(currentBusinessIdProvider);
  if (negocioId == null) {
    return Future.value(const <CreditoCicloSqliteModel>[]);
  }
  return ref
      .read(creditoCicloRepositoryProvider)
      .obtenerCiclosBloqueados60(negocioId);
});

final recordatoriosCreditoProvider =
    FutureProvider<List<CreditoRecordatorioSqliteModel>>((ref) {
      final user = ref.watch(currentUserProvider);
      if (user?.telefono == null) {
        return Future.value(const <CreditoRecordatorioSqliteModel>[]);
      }
      return ref
          .read(creditoCicloRepositoryProvider)
          .obtenerRecordatoriosPorTelefono(user!.telefono);
    });

final productosProvider =
    AsyncNotifierProvider<ProductosNotifier, ProductosState>(
      ProductosNotifier.new,
    );

final inventarioResumenProvider = Provider<InventarioResumen>((ref) {
  final productos =
      ref.watch(productosProvider).valueOrNull?.productos ?? const <Producto>[];
  final activos = productos.length;
  final stockBajo = productos
      .where((producto) => producto.cantidad <= 0)
      .length;
  final necesitanRevision = productos
      .where(AuditoriaHelper.necesitaAuditoria)
      .length;
  final validacionesSemanalesPendientes = productos
      .where((producto) => producto.esClave)
      .where(AuditoriaHelper.necesitaAuditoria)
      .length;
  final claves = productos.where((producto) => producto.esClave).length;

  return InventarioResumen(
    productosActivos: activos,
    stockBajo: stockBajo,
    productosNecesitanRevision: necesitanRevision,
    validacionesSemanalesPendientes: validacionesSemanalesPendientes,
    productosClave: claves,
  );
});

final solicitudesPendientesProvider =
    FutureProvider<List<SolicitudAutorizacionSqliteModel>>((ref) {
      final user = ref.watch(currentUserProvider);
      if (user?.id == null ||
          user?.tipoUsuario != UsuarioSqliteModel.tipoNegocio) {
        return Future.value(const <SolicitudAutorizacionSqliteModel>[]);
      }

      return ref
          .read(solicitudAutorizacionRepositoryProvider)
          .obtenerPendientesPorNegocio(user!.id!);
    });

final solicitudesPendientesCountProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user?.id == null || user?.tipoUsuario != UsuarioSqliteModel.tipoNegocio) {
    return 0;
  }

  return ref
      .read(solicitudAutorizacionRepositoryProvider)
      .contarPendientesPorNegocio(user!.id!);
});

final solicitudesColaboradorProvider =
    FutureProvider<List<SolicitudAutorizacionSqliteModel>>((ref) {
      final user = ref.watch(currentUserProvider);
      if (user?.id == null ||
          user?.tipoUsuario != UsuarioSqliteModel.tipoColaborador) {
        return Future.value(const <SolicitudAutorizacionSqliteModel>[]);
      }

      return ref
          .read(solicitudAutorizacionRepositoryProvider)
          .obtenerSolicitudesPorColaborador(user!.id!);
    });

final auditoriaActualProvider =
    FutureProvider.family<AuditoriaSqliteModel?, String>((ref, tipo) {
      final user = ref.watch(currentUserProvider);
      if (user?.id == null) return Future.value(null);
      final negocioId = user!.tipoUsuario == UsuarioSqliteModel.tipoColaborador
          ? user.negocioId
          : user.id;
      if (negocioId == null) return Future.value(null);
      return ref
          .read(auditoriaRepositoryProvider)
          .obtenerAuditoriaActual(
            negocioId: negocioId,
            colaboradorId:
                user.tipoUsuario == UsuarioSqliteModel.tipoColaborador
                ? user.id
                : null,
            tipo: tipo,
          );
    });

final auditoriasNegocioProvider = FutureProvider<List<AuditoriaResumen>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user?.id == null || user?.tipoUsuario != UsuarioSqliteModel.tipoNegocio) {
    return Future.value(const <AuditoriaResumen>[]);
  }
  return ref
      .read(auditoriaRepositoryProvider)
      .obtenerAuditoriasPorNegocio(user!.id!);
});

final auditoriasColaboradorProvider = FutureProvider<List<AuditoriaResumen>>((
  ref,
) {
  final user = ref.watch(currentUserProvider);
  if (user?.id == null ||
      user?.tipoUsuario != UsuarioSqliteModel.tipoColaborador) {
    return Future.value(const <AuditoriaResumen>[]);
  }
  return ref
      .read(auditoriaRepositoryProvider)
      .obtenerAuditoriasPorColaborador(user!.id!);
});

final auditoriaItemsProvider =
    FutureProvider.family<List<AuditoriaDetalleItem>, int>((ref, auditoriaId) {
      return ref
          .read(auditoriaRepositoryProvider)
          .obtenerItemsPorAuditoria(auditoriaId);
    });

final auditoriasPendientesProvider = FutureProvider<int>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user?.id == null) return Future.value(0);
  final negocioId = user!.tipoUsuario == UsuarioSqliteModel.tipoColaborador
      ? user.negocioId
      : user.id;
  if (negocioId == null) return Future.value(0);
  return ref.read(auditoriaRepositoryProvider).contarPendientes(negocioId);
});

class ClientesState {
  final List<Cliente> clientes;
  final int limit;
  final int offset;
  final bool hasMore;
  final bool isLoadingMore;
  final String query;

  const ClientesState({
    required this.clientes,
    this.limit = 50,
    this.offset = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.query = '',
  });

  ClientesState copyWith({
    List<Cliente>? clientes,
    int? limit,
    int? offset,
    bool? hasMore,
    bool? isLoadingMore,
    String? query,
  }) {
    return ClientesState(
      clientes: clientes ?? this.clientes,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      query: query ?? this.query,
    );
  }
}

class ClientesNotifier extends AsyncNotifier<ClientesState> {
  static const int _pageSize = 50;

  ClienteRepository get _repository => ref.read(clienteRepositoryProvider);

  @override
  Future<ClientesState> build() async {
    final query = ref.watch(clienteBusquedaProvider).trim();
    final negocioId = ref.watch(currentBusinessIdProvider);
    if (negocioId == null) {
      return ClientesState(
        clientes: const <Cliente>[],
        limit: _pageSize,
        offset: 0,
        hasMore: false,
        query: query,
      );
    }
    final clientes = await _repository.obtenerClientes(
      negocioId: negocioId,
      limit: _pageSize,
      offset: 0,
      busqueda: query,
    );

    return ClientesState(
      clientes: clientes,
      limit: _pageSize,
      offset: clientes.length,
      hasMore: clientes.length == _pageSize,
      query: query,
    );
  }

  Future<void> recargar() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> cargarMas() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));

    final nuevosClientes = await _repository.obtenerClientes(
      negocioId: _requireBusinessId(),
      limit: current.limit,
      offset: current.offset,
      busqueda: current.query,
    );

    state = AsyncData(
      current.copyWith(
        clientes: [...current.clientes, ...nuevosClientes],
        offset: current.offset + nuevosClientes.length,
        hasMore: nuevosClientes.length == current.limit,
        isLoadingMore: false,
      ),
    );
  }

  Future<void> guardarCliente(Cliente cliente) async {
    await _repository.guardarCliente(cliente, negocioId: _requireBusinessId());
    await _syncClientsBestEffort();
    await recargar();
  }

  Future<void> actualizarCliente({
    required Cliente cliente,
    String? telefonoAnterior,
  }) async {
    await _repository.actualizarCliente(
      cliente: cliente,
      negocioId: _requireBusinessId(),
      telefonoAnterior: telefonoAnterior,
    );
    await _syncClientsBestEffort();
    await recargar();
  }

  Future<void> eliminarCliente(Cliente cliente) async {
    await _repository.eliminarPorTelefono(
      cliente.telefono,
      negocioId: _requireBusinessId(),
    );
    await _syncClientsBestEffort();
    await recargar();
  }

  int _requireBusinessId() {
    final negocioId = ref.read(currentBusinessIdProvider);
    if (negocioId == null) {
      throw StateError('No hay un negocio activo para esta operacion.');
    }
    return negocioId;
  }

  Future<void> _syncClientsBestEffort() async {
    try {
      await ref.read(syncEngineProvider).syncNow(module: 'clients');
    } catch (_) {
      // Offline-first: el cliente ya quedo guardado local y en sync_outbox.
    } finally {
      ref.invalidate(newSyncStatusProvider);
      ref.invalidate(syncUserStatusProvider);
    }
  }
}

class MovimientosNotifier extends AsyncNotifier<List<Movimiento>> {
  MovimientoRepository get _repository =>
      ref.read(movimientoRepositoryProvider);

  @override
  Future<List<Movimiento>> build() {
    final negocioId = ref.watch(currentBusinessIdProvider);
    if (negocioId == null) return Future.value(const <Movimiento>[]);
    return _repository.obtenerMovimientos(negocioId: negocioId, limit: 10000);
  }

  Future<void> recargar() async {
    ref.invalidateSelf();
    await future;
  }

  Future<int> guardarMovimiento(
    Movimiento movimiento, {
    List<DeudaItemSqliteModel> deudaItems = const [],
    String? clienteTelefono,
    bool fiarDeTodosModos = false,
    String? motivoExcepcion,
  }) async {
    final user = ref.read(currentUserProvider);
    final id = await _repository.guardarMovimiento(
      movimiento,
      negocioId: _requireBusinessId(),
      deudaItems: deudaItems,
      clienteTelefono: clienteTelefono,
      fiarDeTodosModos: fiarDeTodosModos,
      motivoExcepcion: motivoExcepcion,
      usuarioIdExcepcion: user?.id,
      personalUserId: user?.tipoUsuario == UsuarioSqliteModel.tipoPersonal
          ? user?.id
          : null,
    );
    await ref
        .read(clienteRepositoryProvider)
        .recalcularDeudasDesdeMovimientos(negocioId: _requireBusinessId());
    try {
      await ref
          .read(cloudMovementSyncServiceProvider)
          .syncMovementsAndDebtItems();
    } catch (error) {
      debugPrint('[sync-contable] sync inmediato diferido: $error');
    }
    await recargar();
    ref.invalidate(clientesProvider);
    ref.invalidate(cuentasPorCobrarProvider);
    ref.invalidate(ciclosMoraProvider);
    ref.invalidate(ciclosBloqueadosProvider);
    ref.invalidate(collectionInsightsProvider);
    return id;
  }

  Future<int> guardarMovimientoInformativo(Movimiento movimiento) async {
    final user = ref.read(currentUserProvider);
    final id = await _repository.guardarMovimientoInformativo(
      movimiento: movimiento,
      negocioId: _requireBusinessId(),
      personalUserId: user?.tipoUsuario == UsuarioSqliteModel.tipoPersonal
          ? user?.id
          : null,
    );
    await recargar();
    return id;
  }

  Future<void> renombrarCliente({
    required String nombreAnterior,
    required String nombreNuevo,
  }) async {
    await _repository.renombrarCliente(
      negocioId: _requireBusinessId(),
      nombreAnterior: nombreAnterior,
      nombreNuevo: nombreNuevo,
    );
    await recargar();
  }

  Future<void> eliminarPorCliente(
    String nombreCliente, {
    int? clienteId,
    String? clienteTelefono,
  }) async {
    await _repository.eliminarPorCliente(
      nombreCliente,
      negocioId: _requireBusinessId(),
      clienteId: clienteId,
      clienteTelefono: clienteTelefono,
    );
    await recargar();
  }

  int _requireBusinessId() {
    final negocioId = ref.read(currentBusinessIdProvider);
    if (negocioId == null) {
      throw StateError('No hay un negocio activo para esta operacion.');
    }
    return negocioId;
  }
}

class ProductosState {
  final List<Producto> productos;
  final int limit;
  final int offset;
  final bool hasMore;
  final bool isLoadingMore;
  final String query;

  const ProductosState({
    required this.productos,
    this.limit = 50,
    this.offset = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.query = '',
  });

  ProductosState copyWith({
    List<Producto>? productos,
    int? limit,
    int? offset,
    bool? hasMore,
    bool? isLoadingMore,
    String? query,
  }) {
    return ProductosState(
      productos: productos ?? this.productos,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      query: query ?? this.query,
    );
  }
}

class InventarioResumen {
  final int productosActivos;
  final int stockBajo;
  final int productosNecesitanRevision;
  final int validacionesSemanalesPendientes;
  final int productosClave;

  const InventarioResumen({
    required this.productosActivos,
    required this.stockBajo,
    required this.productosNecesitanRevision,
    required this.validacionesSemanalesPendientes,
    required this.productosClave,
  });
}

class ProductosNotifier extends AsyncNotifier<ProductosState> {
  static const int _pageSize = 50;

  ProductoRepository get _repository => ref.read(productoRepositoryProvider);

  @override
  Future<ProductosState> build() async {
    final query = ref.watch(productoBusquedaProvider).trim();
    final negocioId = ref.watch(currentBusinessIdProvider);
    if (negocioId == null) {
      return ProductosState(
        productos: const <Producto>[],
        limit: _pageSize,
        offset: 0,
        hasMore: false,
        query: query,
      );
    }
    final productos = await _repository.obtenerProductos(
      negocioId: negocioId,
      limit: _pageSize,
      offset: 0,
      busqueda: query,
    );

    return ProductosState(
      productos: productos,
      limit: _pageSize,
      offset: productos.length,
      hasMore: productos.length == _pageSize,
      query: query,
    );
  }

  Future<void> recargar() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> cargarMas() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));
    final nuevosProductos = await _repository.obtenerProductos(
      negocioId: _requireBusinessId(),
      limit: current.limit,
      offset: current.offset,
      busqueda: current.query,
    );

    state = AsyncData(
      current.copyWith(
        productos: [...current.productos, ...nuevosProductos],
        offset: current.offset + nuevosProductos.length,
        hasMore: nuevosProductos.length == current.limit,
        isLoadingMore: false,
      ),
    );
  }

  Future<void> guardarProducto(
    Producto producto, {
    List<ProductoImagenSqliteModel> imagenes = const [],
  }) async {
    await _repository.crearProducto(
      producto,
      negocioId: _requireBusinessId(),
      imagenes: imagenes,
    );
    _invalidarProductosFacturables();
    await recargar();
  }

  Future<void> actualizarProducto(Producto producto) async {
    await _repository.actualizarProducto(
      producto,
      negocioId: _requireBusinessId(),
    );
    _invalidarProductosFacturables();
    await recargar();
  }

  Future<void> actualizarStock({
    required String productoId,
    required int cantidad,
  }) async {
    await _repository.actualizarStock(
      negocioId: _requireBusinessId(),
      legacyId: productoId,
      cantidad: cantidad,
    );
    _invalidarProductosFacturables();
    await recargar();
  }

  Future<void> eliminarProducto(String productoId) async {
    await _repository.eliminarLogico(
      productoId,
      negocioId: _requireBusinessId(),
    );
    _invalidarProductosFacturables();
    await recargar();
  }

  Future<void> guardarProductos(List<Producto> productos) async {
    await _repository.guardarProductos(
      productos,
      negocioId: _requireBusinessId(),
    );
    _invalidarProductosFacturables();
    await recargar();
  }

  void _invalidarProductosFacturables() {
    ref.invalidate(billableProductsProvider);
  }

  int _requireBusinessId() {
    final negocioId = ref.read(currentBusinessIdProvider);
    if (negocioId == null) {
      throw StateError('No hay un negocio activo para esta operacion.');
    }
    return negocioId;
  }
}
