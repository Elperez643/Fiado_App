import '../../core/database/database_schema.dart';
import '../services/sync_endpoint_registry.dart';

enum DataContractDisposition {
  outboxV2,
  legacyQueue,
  localOnly,
  serverManagedCache,
  infrastructure,
  legacyInactive,
}

class DataEntityContract {
  final String entity;
  final String table;
  final DataContractDisposition disposition;
  final String modelFile;
  final String repositoryFile;
  final String? outboxModule;
  final String? legacyHandler;
  final String justification;

  const DataEntityContract({
    required this.entity,
    required this.table,
    required this.disposition,
    required this.modelFile,
    required this.repositoryFile,
    this.outboxModule,
    this.legacyHandler,
    required this.justification,
  });
}

class DataContractRegistry {
  static const contracts = <DataEntityContract>[
    DataEntityContract(
      entity: 'clientes',
      table: DatabaseSchema.clientesTable,
      disposition: DataContractDisposition.outboxV2,
      modelFile: 'lib/data/models/cliente_sqlite_model.dart',
      repositoryFile: 'lib/data/repositories/cliente_repository.dart',
      outboxModule: 'clients',
      legacyHandler: 'clients',
      justification: 'Outbox v2 activo; handler legacy conservado.',
    ),
    DataEntityContract(
      entity: 'movimientos',
      table: DatabaseSchema.movimientosTable,
      disposition: DataContractDisposition.legacyQueue,
      modelFile: 'lib/data/models/movimiento_sqlite_model.dart',
      repositoryFile: 'lib/data/repositories/movimiento_repository.dart',
      legacyHandler: 'movements',
      justification: 'Sincroniza deudas y pagos mediante movimientos.',
    ),
    DataEntityContract(
      entity: 'pagos',
      table: DatabaseSchema.pagosTable,
      disposition: DataContractDisposition.legacyInactive,
      modelFile: 'lib/data/models/pago_sqlite_model.dart',
      repositoryFile: 'sin repository activo',
      justification:
          'Tabla de compatibilidad; los pagos activos se registran como movimientos.',
    ),
    DataEntityContract(
      entity: 'productos',
      table: DatabaseSchema.productosTable,
      disposition: DataContractDisposition.outboxV2,
      modelFile: 'lib/data/models/producto_sqlite_model.dart',
      repositoryFile: 'lib/data/repositories/producto_repository.dart',
      outboxModule: 'inventory',
      legacyHandler: 'products',
      justification: 'Outbox v2 activo; handler legacy conservado.',
    ),
    DataEntityContract(
      entity: 'producto_imagenes',
      table: DatabaseSchema.productoImagenesTable,
      disposition: DataContractDisposition.outboxV2,
      modelFile: 'lib/data/models/producto_imagen_sqlite_model.dart',
      repositoryFile: 'lib/data/repositories/producto_imagen_repository.dart',
      outboxModule: 'inventory_images',
      legacyHandler: 'product_images',
      justification: 'Metadata por outbox; contenido lazy y paginado.',
    ),
    DataEntityContract(
      entity: 'deuda_items',
      table: DatabaseSchema.deudaItemsTable,
      disposition: DataContractDisposition.legacyQueue,
      modelFile: 'lib/data/models/deuda_item_sqlite_model.dart',
      repositoryFile: 'lib/data/repositories/deuda_item_repository.dart',
      legacyHandler: 'debt_items',
      justification: 'Detalle de deuda sincronizado junto a movimientos.',
    ),
    DataEntityContract(
      entity: 'comprobantes',
      table: DatabaseSchema.comprobantesTable,
      disposition: DataContractDisposition.legacyQueue,
      modelFile: 'lib/data/models/comprobante_sqlite_model.dart',
      repositoryFile: 'lib/data/repositories/comprobante_repository.dart',
      legacyHandler: 'receipts',
      justification: 'Sincronizacion dedicada de comprobantes.',
    ),
    DataEntityContract(
      entity: 'credito_ciclos',
      table: DatabaseSchema.creditoCiclosTable,
      disposition: DataContractDisposition.legacyQueue,
      modelFile: 'lib/data/models/credito_ciclo_sqlite_model.dart',
      repositoryFile: 'lib/data/repositories/credito_ciclo_repository.dart',
      legacyHandler: 'credit_cycles',
      justification: 'Contrato cloud de ciclos de credito.',
    ),
    DataEntityContract(
      entity: 'credito_ciclo_movimientos',
      table: DatabaseSchema.creditoCicloMovimientosTable,
      disposition: DataContractDisposition.localOnly,
      modelFile: 'lib/data/models/credito_ciclo_movimiento_sqlite_model.dart',
      repositoryFile: 'lib/data/repositories/credito_ciclo_repository.dart',
      justification:
          'Relacion local derivada; nube usa CreditCycle y Movement como fuentes.',
    ),
    DataEntityContract(
      entity: 'credito_recordatorios',
      table: DatabaseSchema.creditoRecordatoriosTable,
      disposition: DataContractDisposition.legacyQueue,
      modelFile: 'lib/data/models/credito_recordatorio_sqlite_model.dart',
      repositoryFile: 'lib/data/repositories/credito_ciclo_repository.dart',
      legacyHandler: 'credit_cycles',
      justification: 'Incluido en contrato cloud de ciclos.',
    ),
    DataEntityContract(
      entity: 'credito_excepciones',
      table: DatabaseSchema.creditoExcepcionesTable,
      disposition: DataContractDisposition.legacyQueue,
      modelFile: 'lib/data/models/credito_excepcion_sqlite_model.dart',
      repositoryFile: 'lib/data/repositories/credito_ciclo_repository.dart',
      legacyHandler: 'credit_cycles',
      justification: 'Incluido en contrato cloud de ciclos.',
    ),
    DataEntityContract(
      entity: 'auditorias',
      table: DatabaseSchema.auditoriasTable,
      disposition: DataContractDisposition.legacyQueue,
      modelFile: 'lib/data/models/auditoria_sqlite_model.dart',
      repositoryFile: 'lib/data/repositories/auditoria_repository.dart',
      legacyHandler: 'audits',
      justification: 'Push/pull dedicado.',
    ),
    DataEntityContract(
      entity: 'auditoria_items',
      table: DatabaseSchema.auditoriaItemsTable,
      disposition: DataContractDisposition.legacyQueue,
      modelFile: 'lib/data/models/auditoria_item_sqlite_model.dart',
      repositoryFile: 'lib/data/repositories/auditoria_repository.dart',
      legacyHandler: 'audit_items',
      justification: 'Push/pull dedicado.',
    ),
    DataEntityContract(
      entity: 'solicitudes_autorizacion',
      table: DatabaseSchema.solicitudesAutorizacionTable,
      disposition: DataContractDisposition.legacyQueue,
      modelFile: 'lib/data/models/solicitud_autorizacion_sqlite_model.dart',
      repositoryFile:
          'lib/data/repositories/solicitud_autorizacion_repository.dart',
      legacyHandler: 'authorization_requests',
      justification: 'Push/pull y acciones dedicadas.',
    ),
    DataEntityContract(
      entity: 'client_scores',
      table: DatabaseSchema.clientScoresTable,
      disposition: DataContractDisposition.legacyQueue,
      modelFile: 'lib/data/models/client_score_sync_model.dart',
      repositoryFile: 'integrado con cliente/movimientos',
      legacyHandler: 'client_scores',
      justification: 'Push/pull dedicado de score.',
    ),
    DataEntityContract(
      entity: 'whatsapp_campaign_publications',
      table: DatabaseSchema.whatsappCampaignPublicationsTable,
      disposition: DataContractDisposition.legacyQueue,
      modelFile: 'lib/data/models/whatsapp_campaign_publication.dart',
      repositoryFile: 'lib/data/repositories/whatsapp_campaign_repository.dart',
      legacyHandler: 'whatsapp_campaigns',
      justification: 'Push/pull dedicado de publicaciones.',
    ),
    DataEntityContract(
      entity: 'usuarios',
      table: DatabaseSchema.usuariosTable,
      disposition: DataContractDisposition.serverManagedCache,
      modelFile: 'lib/data/models/usuario_sqlite_model.dart',
      repositoryFile: 'lib/data/repositories/auth_repository.dart',
      justification: 'Espejo local administrado por endpoints de auth.',
    ),
    DataEntityContract(
      entity: 'sesiones',
      table: DatabaseSchema.sesionesTable,
      disposition: DataContractDisposition.localOnly,
      modelFile: 'lib/data/models/session_sqlite_model.dart',
      repositoryFile: 'lib/data/repositories/auth_repository.dart',
      justification:
          'Sesion y seleccion local; token vive en almacenamiento seguro.',
    ),
    DataEntityContract(
      entity: 'subscriptions',
      table: DatabaseSchema.subscriptionsTable,
      disposition: DataContractDisposition.serverManagedCache,
      modelFile: 'lib/data/models/subscription_sqlite_model.dart',
      repositoryFile: 'lib/data/repositories/subscription_repository.dart',
      justification: 'Cache local de estado administrado por backend de pagos.',
    ),
    DataEntityContract(
      entity: 'user_onboarding',
      table: DatabaseSchema.userOnboardingTable,
      disposition: DataContractDisposition.localOnly,
      modelFile: 'lib/data/models/user_onboarding_sqlite_model.dart',
      repositoryFile: 'lib/data/repositories/user_onboarding_repository.dart',
      justification: 'Preferencias de onboarding del dispositivo.',
    ),
    DataEntityContract(
      entity: 'inventory_product_metrics',
      table: DatabaseSchema.inventoryProductMetricsTable,
      disposition: DataContractDisposition.localOnly,
      modelFile: 'lib/data/models/inventory_product_metric_sqlite_model.dart',
      repositoryFile:
          'lib/data/repositories/inventory_product_metrics_repository.dart',
      justification:
          'Proyeccion recalculable derivada de inventario y movimientos.',
    ),
    DataEntityContract(
      entity: 'business_recommendations_cache',
      table: DatabaseSchema.businessRecommendationsCacheTable,
      disposition: DataContractDisposition.localOnly,
      modelFile: 'modelo interno de Business Copilot',
      repositoryFile: 'lib/business_copilot/business_copilot_service.dart',
      justification: 'Cache derivada y expirable; no es fuente de verdad.',
    ),
    DataEntityContract(
      entity: 'sync_queue',
      table: DatabaseSchema.syncQueueTable,
      disposition: DataContractDisposition.infrastructure,
      modelFile: 'lib/data/models/sync_queue_item_model.dart',
      repositoryFile: 'lib/data/repositories/sync_queue_repository.dart',
      justification: 'Infraestructura legacy, no entidad de negocio.',
    ),
    DataEntityContract(
      entity: 'sync_outbox',
      table: DatabaseSchema.syncOutboxTable,
      disposition: DataContractDisposition.infrastructure,
      modelFile: 'lib/data/models/sync_outbox_item.dart',
      repositoryFile: 'lib/data/repositories/sync_outbox_repository.dart',
      justification: 'Outbox v2, no entidad de negocio.',
    ),
    DataEntityContract(
      entity: 'sync_state',
      table: DatabaseSchema.syncStateTable,
      disposition: DataContractDisposition.infrastructure,
      modelFile: 'lib/data/models/sync_state_model.dart',
      repositoryFile: 'lib/data/repositories/sync_state_repository.dart',
      justification: 'Estado tecnico de sync.',
    ),
  ];

  static const localOnlyQueueEntityTypes = {
    DatabaseSchema.usuariosTable,
    DatabaseSchema.subscriptionsTable,
    DatabaseSchema.userOnboardingTable,
  };

  static Set<String> get knownQueueEntityTypes => {
    ...localOnlyQueueEntityTypes,
    ...LegacySyncEndpointRegistry.entityTypes,
  };

  static DataEntityContract forTable(String table) => contracts.firstWhere(
    (contract) => contract.table == table,
    orElse: () => throw StateError(
      'Entidad sin contrato: table=$table; archivo probable '
      'lib/data/contracts/data_contract_registry.dart; accion recomendada: '
      'registrar disposicion, handler y justificacion.',
    ),
  );

  static void validateDefinitions() {
    final tables = contracts.map((contract) => contract.table).toList();
    if (tables.toSet().length != tables.length) {
      throw StateError('Hay tablas duplicadas en DataContractRegistry.');
    }
    final missing = DatabaseSchema.allTables.difference(tables.toSet());
    final extra = tables.toSet().difference(DatabaseSchema.allTables);
    if (missing.isNotEmpty || extra.isNotEmpty) {
      throw StateError(
        'Cobertura de tablas incompleta. missing=$missing extra=$extra; '
        'corrige lib/data/contracts/data_contract_registry.dart.',
      );
    }
    for (final contract in contracts) {
      final module = contract.outboxModule;
      if (module != null) SyncEndpointRegistry.forModule(module);
      final handler = contract.legacyHandler;
      if (handler != null) LegacySyncEndpointRegistry.forHandler(handler);
    }
  }
}
