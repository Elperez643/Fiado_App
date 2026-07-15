enum SyncPushPayloadShape { genericChanges, inventoryImageMetadata }

class SyncEndpointDefinition {
  final String localModule;
  final String httpPath;
  final bool supportsGlobalPull;
  final SyncPushPayloadShape pushPayloadShape;
  final Set<String> allowedPayloadKeys;

  const SyncEndpointDefinition({
    required this.localModule,
    required this.httpPath,
    this.supportsGlobalPull = true,
    this.pushPayloadShape = SyncPushPayloadShape.genericChanges,
    this.allowedPayloadKeys = const {},
  });

  String get pushPath => '$httpPath/push';
  String get pullPath => '$httpPath/pull';

  void validatePayload(Map<String, Object?> payload) {
    if (allowedPayloadKeys.isEmpty) return;
    final unexpected = payload.keys.toSet().difference(allowedPayloadKeys);
    if (unexpected.isNotEmpty) {
      throw ArgumentError(
        'Payload no soportado para $localModule: campos=$unexpected; '
        'corrige el mapper o el DTO backend antes de encolar.',
      );
    }
  }
}

class SyncEndpointRegistry {
  static const clients = SyncEndpointDefinition(
    localModule: 'clients',
    httpPath: '/api/sync/clients',
    allowedPayloadKeys: {
      'uuid',
      'businessId',
      'nombre',
      'name',
      'telefono',
      'phone',
      'direccion',
      'address',
      'deuda',
      'debt',
      'updatedAt',
      'deletedAt',
      'syncVersion',
    },
  );
  static const movements = SyncEndpointDefinition(
    localModule: 'movements',
    httpPath: '/api/sync/movements',
  );
  static const inventory = SyncEndpointDefinition(
    localModule: 'inventory',
    httpPath: '/api/sync/inventory',
    allowedPayloadKeys: {
      'uuid',
      'legacyId',
      'serverId',
      'businessId',
      'nombre',
      'name',
      'codigoReferencia',
      'categoria',
      'descripcion',
      'ubicacion',
      'cantidad',
      'stock',
      'costoUnitario',
      'precioCompra',
      'precioVenta',
      'porcentajeGanancia',
      'stockMinimo',
      'tipoMedida',
      'nivelDemanda',
      'esClave',
      'activo',
      'deletedAt',
      'createdAt',
      'updatedAt',
      'syncVersion',
    },
  );
  static const audits = SyncEndpointDefinition(
    localModule: 'audits',
    httpPath: '/api/sync/audits',
  );
  static const collaborators = SyncEndpointDefinition(
    localModule: 'collaborators',
    httpPath: '/api/sync/collaborators',
  );
  static const whatsapp = SyncEndpointDefinition(
    localModule: 'whatsapp',
    httpPath: '/api/sync/whatsapp',
  );
  static const inventoryImages = SyncEndpointDefinition(
    localModule: 'inventory_images',
    httpPath: '/api/sync/inventory/images',
    supportsGlobalPull: false,
    pushPayloadShape: SyncPushPayloadShape.inventoryImageMetadata,
    allowedPayloadKeys: {
      'uuid',
      'productUuid',
      'businessId',
      'fileName',
      'mimeType',
      'sizeBytes',
      'contentHash',
      'width',
      'height',
      'isCover',
      'sortOrder',
      'createdAt',
      'updatedAt',
      'deletedAt',
      'hasContent',
      'contentBase64',
    },
  );

  static const definitions = <String, SyncEndpointDefinition>{
    'clients': clients,
    'movements': movements,
    'inventory': inventory,
    'audits': audits,
    'collaborators': collaborators,
    'whatsapp': whatsapp,
    'inventory_images': inventoryImages,
  };

  static SyncEndpointDefinition forModule(String localModule) {
    final definition = definitions[localModule];
    if (definition == null) {
      throw UnsupportedError(
        'Modulo de sincronizacion sin endpoint registrado: $localModule',
      );
    }
    return definition;
  }

  static String inventoryImageContentPath(String imageUuid) =>
      '${inventoryImages.httpPath}/$imageUuid/content';

  static String get inventoryImageContentPushPath =>
      '${inventoryImages.httpPath}/content/push';
}

class LegacySyncEndpointDefinition {
  final String handler;
  final String httpPath;
  final Set<String> entityTypes;

  const LegacySyncEndpointDefinition({
    required this.handler,
    required this.httpPath,
    required this.entityTypes,
  });

  String get pushPath => '$httpPath/push';
  String get pullPath => '$httpPath/pull';
}

class LegacySyncEndpointRegistry {
  static const definitions = <String, LegacySyncEndpointDefinition>{
    'clients': LegacySyncEndpointDefinition(
      handler: 'clients',
      httpPath: '/clients/sync',
      entityTypes: {'clientes', 'clients'},
    ),
    'products': LegacySyncEndpointDefinition(
      handler: 'products',
      httpPath: '/products/sync',
      entityTypes: {'productos'},
    ),
    'product_images': LegacySyncEndpointDefinition(
      handler: 'product_images',
      httpPath: '/products/images/sync',
      entityTypes: {'producto_imagenes'},
    ),
    'movements': LegacySyncEndpointDefinition(
      handler: 'movements',
      httpPath: '/movements/sync',
      entityTypes: {'movimientos'},
    ),
    'debt_items': LegacySyncEndpointDefinition(
      handler: 'debt_items',
      httpPath: '/debt-items/sync',
      entityTypes: {'deuda_items'},
    ),
    'receipts': LegacySyncEndpointDefinition(
      handler: 'receipts',
      httpPath: '/receipts/sync',
      entityTypes: {'comprobantes'},
    ),
    'credit_cycles': LegacySyncEndpointDefinition(
      handler: 'credit_cycles',
      httpPath: '/credit-cycles/sync',
      entityTypes: {
        'credito_ciclos',
        'credito_recordatorios',
        'credito_excepciones',
      },
    ),
    'audits': LegacySyncEndpointDefinition(
      handler: 'audits',
      httpPath: '/audits/sync',
      entityTypes: {'auditorias'},
    ),
    'audit_items': LegacySyncEndpointDefinition(
      handler: 'audit_items',
      httpPath: '/audit-items/sync',
      entityTypes: {'auditoria_items'},
    ),
    'authorization_requests': LegacySyncEndpointDefinition(
      handler: 'authorization_requests',
      httpPath: '/authorization-requests/sync',
      entityTypes: {'solicitudes_autorizacion'},
    ),
    'client_scores': LegacySyncEndpointDefinition(
      handler: 'client_scores',
      httpPath: '/client-scores/sync',
      entityTypes: {'client_scores'},
    ),
    'whatsapp_campaigns': LegacySyncEndpointDefinition(
      handler: 'whatsapp_campaigns',
      httpPath: '/whatsapp-campaigns/sync',
      entityTypes: {'whatsapp_campaign_publications'},
    ),
  };

  static Set<String> get entityTypes =>
      definitions.values.expand((definition) => definition.entityTypes).toSet();

  static LegacySyncEndpointDefinition forHandler(String handler) {
    final definition = definitions[handler];
    if (definition == null) {
      throw UnsupportedError('Handler legacy sin endpoint: $handler');
    }
    return definition;
  }

  static LegacySyncEndpointDefinition forEntityType(String entityType) =>
      definitions.values.firstWhere(
        (definition) => definition.entityTypes.contains(entityType),
        orElse: () => throw UnsupportedError(
          'Entidad sync_queue sin handler registrado: $entityType',
        ),
      );
}
