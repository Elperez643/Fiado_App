class DatabaseSchema {
  static const int version = 29;
  static const String databaseName = 'fiado_app.db';

  static const String clientesTable = 'clientes';
  static const String movimientosTable = 'movimientos';
  static const String pagosTable = 'pagos';
  static const String productosTable = 'productos';
  static const String usuariosTable = 'usuarios';
  static const String sesionesTable = 'sesiones';
  static const String subscriptionsTable = 'subscriptions';
  static const String solicitudesAutorizacionTable = 'solicitudes_autorizacion';
  static const String auditoriasTable = 'auditorias';
  static const String auditoriaItemsTable = 'auditoria_items';
  static const String productoImagenesTable = 'producto_imagenes';
  static const String deudaItemsTable = 'deuda_items';
  static const String comprobantesTable = 'comprobantes';
  static const String creditoCiclosTable = 'credito_ciclos';
  static const String creditoCicloMovimientosTable =
      'credito_ciclo_movimientos';
  static const String creditoRecordatoriosTable = 'credito_recordatorios';
  static const String creditoExcepcionesTable = 'credito_excepciones';
  static const String clientScoresTable = 'client_scores';
  static const String inventoryProductMetricsTable =
      'inventory_product_metrics';
  static const String businessRecommendationsCacheTable =
      'business_recommendations_cache';
  static const String userOnboardingTable = 'user_onboarding';
  static const String whatsappCampaignPublicationsTable =
      'whatsapp_campaign_publications';
  static const String syncQueueTable = 'sync_queue';
  static const String syncOutboxTable = 'sync_outbox';
  static const String syncStateTable = 'sync_state';

  static const Set<String> allTables = {
    clientesTable,
    movimientosTable,
    pagosTable,
    productosTable,
    usuariosTable,
    sesionesTable,
    subscriptionsTable,
    solicitudesAutorizacionTable,
    auditoriasTable,
    auditoriaItemsTable,
    productoImagenesTable,
    deudaItemsTable,
    comprobantesTable,
    creditoCiclosTable,
    creditoCicloMovimientosTable,
    creditoRecordatoriosTable,
    creditoExcepcionesTable,
    clientScoresTable,
    inventoryProductMetricsTable,
    businessRecommendationsCacheTable,
    userOnboardingTable,
    whatsappCampaignPublicationsTable,
    syncQueueTable,
    syncOutboxTable,
    syncStateTable,
  };

  static const String createClientesTable = '''
CREATE TABLE clientes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  negocio_id INTEGER,
  uuid TEXT NOT NULL,
  nombre TEXT NOT NULL COLLATE NOCASE,
  telefono TEXT NOT NULL,
  address TEXT,
  deuda REAL NOT NULL DEFAULT 0,
  is_active INTEGER DEFAULT 1,
  deleted_at TEXT,
  last_synced_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  sync_version INTEGER NOT NULL DEFAULT 0,
  sync_status TEXT NOT NULL DEFAULT 'pending',
  remote_id TEXT,
  FOREIGN KEY (negocio_id) REFERENCES usuarios (id) ON DELETE CASCADE
)
''';

  static const String createMovimientosTable = '''
CREATE TABLE movimientos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  negocio_id INTEGER,
  personal_user_id INTEGER,
  cliente_id INTEGER,
  cliente_nombre TEXT NOT NULL COLLATE NOCASE,
  cliente_telefono TEXT,
  cliente_nombre_snapshot TEXT,
  cliente_telefono_snapshot TEXT,
  tipo TEXT NOT NULL,
  monto REAL NOT NULL,
  concepto TEXT,
  fecha TEXT NOT NULL,
  updated_at TEXT,
  is_active INTEGER DEFAULT 1,
  deleted_at TEXT,
  last_synced_at TEXT,
  created_at TEXT NOT NULL,
  sync_status TEXT NOT NULL DEFAULT 'pending',
  local_uuid TEXT,
  remote_id TEXT,
  FOREIGN KEY (negocio_id) REFERENCES usuarios (id) ON DELETE CASCADE,
  FOREIGN KEY (personal_user_id) REFERENCES usuarios (id) ON DELETE SET NULL,
  FOREIGN KEY (cliente_id) REFERENCES clientes (id) ON DELETE SET NULL
)
''';

  static const String createPagosTable = '''
CREATE TABLE pagos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  negocio_id INTEGER,
  cliente_nombre TEXT NOT NULL COLLATE NOCASE,
  cliente_telefono TEXT,
  monto REAL NOT NULL,
  fecha TEXT NOT NULL,
  movimiento_id INTEGER,
  created_at TEXT NOT NULL,
  sync_status TEXT NOT NULL DEFAULT 'pending',
  remote_id TEXT,
  FOREIGN KEY (negocio_id) REFERENCES usuarios (id) ON DELETE CASCADE,
  FOREIGN KEY (movimiento_id) REFERENCES movimientos (id) ON DELETE SET NULL
)
''';

  static const String createProductosTable = '''
CREATE TABLE IF NOT EXISTS productos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  negocio_id INTEGER,
  remote_id TEXT,
  nombre TEXT NOT NULL,
  categoria TEXT,
  descripcion TEXT,
  cantidad INTEGER NOT NULL DEFAULT 0,
  costo_unitario REAL DEFAULT 0,
  precio_compra REAL DEFAULT 0,
  precio_venta REAL DEFAULT 0,
  porcentaje_ganancia REAL DEFAULT 0,
  stock_minimo INTEGER DEFAULT 0,
  codigo_referencia TEXT,
  activo INTEGER DEFAULT 1,
  deleted_at TEXT,
  last_synced_at TEXT,
  sync_status TEXT DEFAULT 'pending',
  sync_version INTEGER NOT NULL DEFAULT 0,
  created_at TEXT,
  updated_at TEXT,
  legacy_id TEXT UNIQUE,
  ubicacion TEXT,
  tipo_medida TEXT,
  nivel_demanda TEXT,
  es_clave INTEGER DEFAULT 0,
  ultima_verificacion TEXT,
  disponibilidad_confirmada INTEGER DEFAULT 0,
  disponibilidad_corregida INTEGER DEFAULT 0,
  requiere_verificacion_administrador INTEGER DEFAULT 0,
  rotacion_semana_anterior INTEGER DEFAULT 0,
  FOREIGN KEY (negocio_id) REFERENCES usuarios (id) ON DELETE CASCADE
)
''';

  static const String createProductoImagenesTable = '''
CREATE TABLE IF NOT EXISTS producto_imagenes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  negocio_id INTEGER,
  producto_id INTEGER NOT NULL,
  uuid TEXT,
  product_uuid TEXT,
  remote_id TEXT,
  local_path TEXT NOT NULL,
  remote_url TEXT,
  storage_key TEXT,
  orden INTEGER DEFAULT 0,
  mime_type TEXT,
  size_bytes INTEGER DEFAULT 0,
  width INTEGER,
  height INTEGER,
  content_hash TEXT,
  content_available INTEGER DEFAULT 1,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT,
  last_synced_at TEXT,
  sync_status TEXT DEFAULT 'pending',
  FOREIGN KEY (negocio_id) REFERENCES usuarios (id) ON DELETE CASCADE,
  FOREIGN KEY (producto_id) REFERENCES productos (id) ON DELETE CASCADE
)
''';

  static const String createDeudaItemsTable = '''
CREATE TABLE IF NOT EXISTS deuda_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  negocio_id INTEGER,
  remote_id TEXT,
  movimiento_id INTEGER NOT NULL,
  producto_id INTEGER,
  nombre_producto TEXT NOT NULL,
  codigo_referencia TEXT,
  cantidad INTEGER NOT NULL,
  precio_unitario REAL NOT NULL,
  subtotal REAL NOT NULL,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT,
  last_synced_at TEXT,
  sync_status TEXT DEFAULT 'pending',
  local_uuid TEXT,
  FOREIGN KEY (negocio_id) REFERENCES usuarios (id) ON DELETE CASCADE,
  FOREIGN KEY (movimiento_id) REFERENCES movimientos (id) ON DELETE CASCADE,
  FOREIGN KEY (producto_id) REFERENCES productos (id) ON DELETE SET NULL
)
''';

  static const String createInventoryProductMetricsTable = '''
CREATE TABLE IF NOT EXISTS inventory_product_metrics (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  negocio_id INTEGER NOT NULL,
  producto_id INTEGER NOT NULL,
  product_name TEXT,
  code_reference TEXT,
  category TEXT,
  location TEXT,
  current_stock INTEGER DEFAULT 0,
  minimum_stock INTEGER DEFAULT 0,
  unit_cost REAL DEFAULT 0,
  sale_price REAL DEFAULT 0,
  profit_margin_percent REAL DEFAULT 0,
  inventory_cost_value REAL DEFAULT 0,
  inventory_sale_value REAL DEFAULT 0,
  potential_profit REAL DEFAULT 0,
  sold_quantity_30_days REAL DEFAULT 0,
  average_daily_movement REAL DEFAULT 0,
  coverage_days REAL,
  recommended_restock_quantity REAL DEFAULT 0,
  status TEXT NOT NULL,
  last_movement_at TEXT,
  last_calculated_at TEXT,
  dirty INTEGER DEFAULT 1,
  created_at TEXT,
  updated_at TEXT,
  UNIQUE(negocio_id, producto_id),
  FOREIGN KEY (negocio_id) REFERENCES usuarios (id) ON DELETE CASCADE,
  FOREIGN KEY (producto_id) REFERENCES productos (id) ON DELETE CASCADE
)
''';

  static const String createBusinessRecommendationsCacheTable = '''
CREATE TABLE IF NOT EXISTS business_recommendations_cache (
  id TEXT PRIMARY KEY,
  business_id INTEGER NOT NULL,
  type TEXT NOT NULL,
  priority TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  action_label TEXT NOT NULL,
  action_route TEXT NOT NULL,
  score INTEGER DEFAULT 0,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  dismissed INTEGER DEFAULT 0,
  FOREIGN KEY (business_id) REFERENCES usuarios (id) ON DELETE CASCADE
)
''';

  static const String createComprobantesTable = '''
CREATE TABLE IF NOT EXISTS comprobantes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  negocio_id INTEGER,
  remote_id TEXT,
  tipo TEXT NOT NULL,
  movimiento_id INTEGER NOT NULL,
  cliente_nombre TEXT NOT NULL,
  cliente_telefono TEXT,
  negocio_nombre TEXT,
  codigo_comprobante TEXT NOT NULL UNIQUE,
  fecha TEXT NOT NULL,
  subtotal REAL DEFAULT 0,
  total REAL NOT NULL,
  saldo_anterior REAL,
  saldo_nuevo REAL,
  creado_por_usuario_id INTEGER,
  payload_json TEXT NOT NULL,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT,
  last_synced_at TEXT,
  sync_status TEXT DEFAULT 'pending',
  FOREIGN KEY (negocio_id) REFERENCES usuarios (id) ON DELETE CASCADE,
  FOREIGN KEY (movimiento_id) REFERENCES movimientos (id) ON DELETE CASCADE,
  FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios (id) ON DELETE SET NULL
)
''';

  static const String createUsuariosTable = '''
CREATE TABLE IF NOT EXISTS usuarios (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  remote_id TEXT,
  nombre TEXT NOT NULL,
  telefono TEXT NOT NULL UNIQUE,
  tipo_usuario TEXT NOT NULL,
  negocio_id INTEGER,
  password_hash TEXT NOT NULL,
  activo INTEGER DEFAULT 1,
  created_at TEXT,
  updated_at TEXT,
  last_synced_at TEXT,
  sync_status TEXT DEFAULT 'pending',
  FOREIGN KEY (negocio_id) REFERENCES usuarios (id) ON DELETE SET NULL
)
''';

  static const String createSesionesTable = '''
CREATE TABLE IF NOT EXISTS sesiones (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  usuario_id INTEGER NOT NULL,
  started_at TEXT,
  last_active_at TEXT,
  is_active INTEGER DEFAULT 1,
  jwt_token TEXT,
  FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE
)
''';

  static const String createSubscriptionsTable = '''
CREATE TABLE IF NOT EXISTS subscriptions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  usuario_id INTEGER NOT NULL,
  plan_id TEXT,
  plan_nombre TEXT,
  precio_mensual REAL,
  max_colaboradores INTEGER,
  billing_cycle TEXT DEFAULT 'mensual',
  discount_percent INTEGER DEFAULT 0,
  original_price REAL,
  final_price REAL,
  currency_code TEXT DEFAULT 'USD',
  status TEXT DEFAULT 'trial',
  trial_started_at TEXT,
  trial_ends_at TEXT,
  current_period_started_at TEXT,
  current_period_ends_at TEXT,
  payment_provider TEXT,
  provider_subscription_id TEXT,
  created_at TEXT,
  updated_at TEXT,
  sync_status TEXT DEFAULT 'pending',
  FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE
)
''';

  static const String createSolicitudesAutorizacionTable = '''
CREATE TABLE IF NOT EXISTS solicitudes_autorizacion (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  remote_id TEXT,
  negocio_id INTEGER NOT NULL,
  colaborador_id INTEGER NOT NULL,
  tipo_solicitud TEXT NOT NULL,
  entidad TEXT NOT NULL,
  entidad_id INTEGER,
  datos_antes TEXT,
  datos_despues TEXT NOT NULL,
  estado TEXT DEFAULT 'pendiente',
  comentario_negocio TEXT,
  aprobado_por_usuario_id INTEGER,
  resolved_at TEXT,
  deleted_at TEXT,
  last_synced_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  sync_status TEXT DEFAULT 'pending',
  FOREIGN KEY (negocio_id) REFERENCES usuarios (id) ON DELETE CASCADE,
  FOREIGN KEY (colaborador_id) REFERENCES usuarios (id) ON DELETE CASCADE
)
''';

  static const String createAuditoriasTable = '''
CREATE TABLE IF NOT EXISTS auditorias (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  remote_id TEXT,
  negocio_id INTEGER NOT NULL,
  colaborador_id INTEGER,
  tipo TEXT NOT NULL,
  fecha TEXT NOT NULL,
  estado TEXT DEFAULT 'pendiente',
  total_productos INTEGER DEFAULT 0,
  productos_validados INTEGER DEFAULT 0,
  observaciones TEXT,
  deleted_at TEXT,
  last_synced_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  sync_status TEXT DEFAULT 'pending',
  FOREIGN KEY (negocio_id) REFERENCES usuarios (id) ON DELETE CASCADE,
  FOREIGN KEY (colaborador_id) REFERENCES usuarios (id) ON DELETE SET NULL
)
''';

  static const String createAuditoriaItemsTable = '''
CREATE TABLE IF NOT EXISTS auditoria_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  negocio_id INTEGER,
  remote_id TEXT,
  auditoria_id INTEGER NOT NULL,
  producto_id INTEGER NOT NULL,
  stock_sistema INTEGER NOT NULL,
  stock_fisico INTEGER,
  estado_validacion TEXT DEFAULT 'pendiente',
  observacion TEXT,
  deleted_at TEXT,
  last_synced_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  sync_status TEXT DEFAULT 'pending',
  FOREIGN KEY (negocio_id) REFERENCES usuarios (id) ON DELETE CASCADE,
  FOREIGN KEY (auditoria_id) REFERENCES auditorias (id) ON DELETE CASCADE,
  FOREIGN KEY (producto_id) REFERENCES productos (id) ON DELETE CASCADE
)
''';

  static const String createSyncQueueTable = '''
CREATE TABLE IF NOT EXISTS sync_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entity_type TEXT NOT NULL,
  entity_id INTEGER NOT NULL,
  operation TEXT NOT NULL,
  payload TEXT NOT NULL,
  status TEXT DEFAULT 'pending',
  attempts INTEGER DEFAULT 0,
  last_error TEXT,
  created_at TEXT,
  updated_at TEXT
)
''';

  static const String createSyncOutboxTable = '''
CREATE TABLE IF NOT EXISTS sync_outbox (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT NOT NULL UNIQUE,
  business_id TEXT NOT NULL,
  module TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_uuid TEXT NOT NULL,
  operation TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  status TEXT NOT NULL,
  attempt_count INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''';

  static const String createSyncStateTable = '''
CREATE TABLE IF NOT EXISTS sync_state (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  business_id TEXT NOT NULL,
  module TEXT NOT NULL,
  last_pull_at TEXT,
  last_push_at TEXT,
  last_success_at TEXT,
  last_error TEXT,
  pending_count INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL
)
''';

  static const String createCreditoCiclosTable = '''
CREATE TABLE IF NOT EXISTS credito_ciclos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  remote_id TEXT,
  negocio_id INTEGER NOT NULL,
  cliente_id INTEGER NOT NULL,
  fecha_inicio TEXT NOT NULL,
  fecha_limite_30 TEXT NOT NULL,
  fecha_limite_45 TEXT NOT NULL,
  fecha_bloqueo_60 TEXT NOT NULL,
  estado TEXT NOT NULL DEFAULT 'activo',
  monto_total REAL DEFAULT 0,
  monto_pagado REAL DEFAULT 0,
  saldo_pendiente REAL DEFAULT 0,
  bloqueado INTEGER DEFAULT 0,
  fecha_saldado TEXT,
  created_at TEXT,
  updated_at TEXT,
  last_synced_at TEXT,
  sync_status TEXT DEFAULT 'pending',
  FOREIGN KEY (negocio_id) REFERENCES usuarios (id) ON DELETE CASCADE,
  FOREIGN KEY (cliente_id) REFERENCES clientes (id) ON DELETE CASCADE
)
''';

  static const String createCreditoCicloMovimientosTable = '''
CREATE TABLE IF NOT EXISTS credito_ciclo_movimientos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  remote_id TEXT,
  ciclo_id INTEGER NOT NULL,
  movimiento_id INTEGER NOT NULL,
  tipo TEXT NOT NULL,
  monto REAL NOT NULL,
  fecha TEXT NOT NULL,
  created_at TEXT,
  updated_at TEXT,
  FOREIGN KEY (ciclo_id) REFERENCES credito_ciclos (id) ON DELETE CASCADE,
  FOREIGN KEY (movimiento_id) REFERENCES movimientos (id) ON DELETE CASCADE
)
''';

  static const String createCreditoRecordatoriosTable = '''
CREATE TABLE IF NOT EXISTS credito_recordatorios (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  remote_id TEXT,
  ciclo_id INTEGER NOT NULL,
  negocio_id INTEGER NOT NULL,
  cliente_id INTEGER NOT NULL,
  tipo TEXT NOT NULL,
  mensaje TEXT NOT NULL,
  canal TEXT NOT NULL,
  estado TEXT DEFAULT 'pendiente',
  fecha_generado TEXT NOT NULL,
  fecha_enviado TEXT,
  created_at TEXT,
  updated_at TEXT,
  last_synced_at TEXT,
  sync_status TEXT DEFAULT 'pending',
  FOREIGN KEY (ciclo_id) REFERENCES credito_ciclos (id) ON DELETE CASCADE,
  FOREIGN KEY (negocio_id) REFERENCES usuarios (id) ON DELETE CASCADE,
  FOREIGN KEY (cliente_id) REFERENCES clientes (id) ON DELETE CASCADE
)
''';

  static const String createCreditoExcepcionesTable = '''
CREATE TABLE IF NOT EXISTS credito_excepciones (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  remote_id TEXT,
  ciclo_id INTEGER NOT NULL,
  negocio_id INTEGER NOT NULL,
  cliente_id INTEGER NOT NULL,
  usuario_id INTEGER NOT NULL,
  motivo TEXT,
  monto_fiado REAL NOT NULL,
  movimiento_id INTEGER,
  fecha TEXT NOT NULL,
  created_at TEXT,
  updated_at TEXT,
  last_synced_at TEXT,
  sync_status TEXT DEFAULT 'pending',
  FOREIGN KEY (ciclo_id) REFERENCES credito_ciclos (id) ON DELETE CASCADE,
  FOREIGN KEY (negocio_id) REFERENCES usuarios (id) ON DELETE CASCADE,
  FOREIGN KEY (cliente_id) REFERENCES clientes (id) ON DELETE CASCADE,
  FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE,
  FOREIGN KEY (movimiento_id) REFERENCES movimientos (id) ON DELETE SET NULL
)
''';

  static const String createClientScoresTable = '''
CREATE TABLE IF NOT EXISTS client_scores (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  remote_id TEXT,
  negocio_id INTEGER NOT NULL,
  cliente_id INTEGER NOT NULL,
  score INTEGER NOT NULL,
  risk_level TEXT NOT NULL,
  suggested_credit_limit REAL DEFAULT 0,
  payment_compliance_percent REAL DEFAULT 0,
  total_credits REAL DEFAULT 0,
  total_payments REAL DEFAULT 0,
  overdue_30_count INTEGER DEFAULT 0,
  overdue_45_count INTEGER DEFAULT 0,
  blocked_60_count INTEGER DEFAULT 0,
  reasons_json TEXT,
  last_calculated_at TEXT NOT NULL,
  deleted_at TEXT,
  last_synced_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  sync_status TEXT DEFAULT 'pending',
  FOREIGN KEY (negocio_id) REFERENCES usuarios (id) ON DELETE CASCADE,
  FOREIGN KEY (cliente_id) REFERENCES clientes (id) ON DELETE CASCADE
)
''';

  static const String createUserOnboardingTable = '''
CREATE TABLE IF NOT EXISTS user_onboarding (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  usuario_id INTEGER NOT NULL,
  tipo_usuario TEXT NOT NULL,
  onboarding_key TEXT NOT NULL,
  completed INTEGER DEFAULT 0,
  completed_at TEXT,
  skipped INTEGER DEFAULT 0,
  skipped_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  sync_status TEXT DEFAULT 'pending',
  FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE
)
''';

  static const String createWhatsappCampaignPublicationsTable = '''
CREATE TABLE IF NOT EXISTS whatsapp_campaign_publications (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  local_uuid TEXT NOT NULL UNIQUE,
  remote_id TEXT,
  negocio_id INTEGER NOT NULL,
  date_key TEXT NOT NULL,
  mode TEXT NOT NULL DEFAULT 'catalogo',
  product_ids_json TEXT NOT NULL DEFAULT '[]',
  rendered_image_paths_json TEXT NOT NULL DEFAULT '[]',
  status_texts_json TEXT NOT NULL DEFAULT '[]',
  status TEXT NOT NULL DEFAULT 'pendiente',
  campaign_status TEXT NOT NULL DEFAULT 'activo',
  consumes_quota INTEGER DEFAULT 0,
  quota_units INTEGER DEFAULT 1,
  fecha_inicio TEXT NOT NULL,
  duracion_dias INTEGER DEFAULT 7,
  created_at TEXT NOT NULL,
  updated_at TEXT,
  opened_whatsapp_at TEXT,
  confirmed_by_user_at TEXT,
  canceled_by_user_at TEXT,
  failed_at TEXT,
  estimated_expires_at TEXT,
  error TEXT,
  is_active INTEGER DEFAULT 1,
  deleted_at TEXT,
  last_synced_at TEXT,
  sync_status TEXT DEFAULT 'pending',
  FOREIGN KEY (negocio_id) REFERENCES usuarios (id) ON DELETE CASCADE
)
''';

  static const List<String> createTableStatements = [
    createClientesTable,
    createMovimientosTable,
    createPagosTable,
    createProductosTable,
    createUsuariosTable,
    createSesionesTable,
    createSubscriptionsTable,
    createSolicitudesAutorizacionTable,
    createAuditoriasTable,
    createAuditoriaItemsTable,
    createProductoImagenesTable,
    createDeudaItemsTable,
    createComprobantesTable,
    createCreditoCiclosTable,
    createCreditoCicloMovimientosTable,
    createCreditoRecordatoriosTable,
    createCreditoExcepcionesTable,
    createClientScoresTable,
    createInventoryProductMetricsTable,
    createBusinessRecommendationsCacheTable,
    createUserOnboardingTable,
    createWhatsappCampaignPublicationsTable,
    createSyncQueueTable,
    createSyncOutboxTable,
    createSyncStateTable,
  ];

  static const List<String> initialIndexes = [
    'CREATE INDEX IF NOT EXISTS idx_clientes_nombre ON clientes(nombre)',
    'CREATE INDEX IF NOT EXISTS idx_clientes_telefono ON clientes(telefono)',
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_clientes_uuid ON clientes(uuid)',
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_clientes_negocio_uuid ON clientes(negocio_id, uuid)',
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_clientes_negocio_telefono_unique ON clientes(negocio_id, telefono)',
    'CREATE INDEX IF NOT EXISTS idx_clientes_negocio_nombre ON clientes(negocio_id, nombre)',
    'CREATE INDEX IF NOT EXISTS idx_clientes_negocio_updated_at ON clientes(negocio_id, updated_at)',
    'CREATE INDEX IF NOT EXISTS idx_clientes_negocio_deleted_at ON clientes(negocio_id, deleted_at)',
    'CREATE INDEX IF NOT EXISTS idx_movimientos_cliente_fecha ON movimientos(cliente_nombre, fecha DESC)',
    'CREATE INDEX IF NOT EXISTS idx_movimientos_negocio_cliente_id_fecha ON movimientos(negocio_id, cliente_id, fecha DESC)',
    'CREATE INDEX IF NOT EXISTS idx_movimientos_fecha ON movimientos(fecha DESC)',
    'CREATE INDEX IF NOT EXISTS idx_movimientos_negocio_fecha ON movimientos(negocio_id, fecha DESC)',
    'CREATE INDEX IF NOT EXISTS idx_movimientos_negocio_cliente_telefono_fecha ON movimientos(negocio_id, cliente_telefono, fecha DESC)',
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_movimientos_negocio_local_uuid ON movimientos(negocio_id, local_uuid)',
    'CREATE INDEX IF NOT EXISTS idx_movimientos_personal_fecha ON movimientos(personal_user_id, fecha DESC)',
    'CREATE INDEX IF NOT EXISTS idx_pagos_cliente_fecha ON pagos(cliente_nombre, fecha DESC)',
    'CREATE INDEX IF NOT EXISTS idx_pagos_fecha ON pagos(fecha DESC)',
    'CREATE INDEX IF NOT EXISTS idx_productos_nombre ON productos(nombre)',
    'CREATE INDEX IF NOT EXISTS idx_productos_categoria ON productos(categoria)',
    'CREATE INDEX IF NOT EXISTS idx_productos_nombre_activo ON productos(nombre COLLATE NOCASE, activo)',
    'CREATE INDEX IF NOT EXISTS idx_productos_codigo_activo ON productos(codigo_referencia COLLATE NOCASE, activo)',
    'CREATE INDEX IF NOT EXISTS idx_productos_activo ON productos(activo)',
    'CREATE INDEX IF NOT EXISTS idx_productos_negocio_activo ON productos(negocio_id, activo)',
    'CREATE INDEX IF NOT EXISTS idx_productos_negocio_activo_stock ON productos(negocio_id, activo, cantidad)',
    'CREATE INDEX IF NOT EXISTS idx_productos_negocio_activo_stock_minimo ON productos(negocio_id, activo, stock_minimo)',
    'CREATE INDEX IF NOT EXISTS idx_productos_negocio_nombre ON productos(negocio_id, nombre COLLATE NOCASE, activo)',
    'CREATE INDEX IF NOT EXISTS idx_productos_negocio_codigo ON productos(negocio_id, codigo_referencia COLLATE NOCASE, activo)',
    'CREATE INDEX IF NOT EXISTS idx_productos_sync_status ON productos(sync_status)',
    'CREATE INDEX IF NOT EXISTS idx_productos_negocio_legacy_id ON productos(negocio_id, legacy_id)',
    'CREATE INDEX IF NOT EXISTS idx_productos_negocio_updated_at ON productos(negocio_id, updated_at)',
    'CREATE INDEX IF NOT EXISTS idx_productos_negocio_deleted_at ON productos(negocio_id, deleted_at)',
    'CREATE INDEX IF NOT EXISTS idx_usuarios_telefono ON usuarios(telefono)',
    'CREATE INDEX IF NOT EXISTS idx_usuarios_tipo_usuario ON usuarios(tipo_usuario)',
    'CREATE INDEX IF NOT EXISTS idx_usuarios_negocio_id ON usuarios(negocio_id)',
    'CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status)',
    'CREATE INDEX IF NOT EXISTS idx_solicitudes_negocio_estado ON solicitudes_autorizacion(negocio_id, estado)',
    'CREATE INDEX IF NOT EXISTS idx_solicitudes_colaborador ON solicitudes_autorizacion(colaborador_id, created_at DESC)',
    'CREATE INDEX IF NOT EXISTS idx_solicitudes_estado ON solicitudes_autorizacion(estado)',
    'CREATE INDEX IF NOT EXISTS idx_solicitudes_sync_status ON solicitudes_autorizacion(sync_status)',
    'CREATE INDEX IF NOT EXISTS idx_auditorias_negocio_fecha ON auditorias(negocio_id, fecha DESC)',
    'CREATE INDEX IF NOT EXISTS idx_auditorias_colaborador_fecha ON auditorias(colaborador_id, fecha DESC)',
    'CREATE INDEX IF NOT EXISTS idx_auditorias_tipo_estado ON auditorias(tipo, estado)',
    'CREATE INDEX IF NOT EXISTS idx_auditoria_items_auditoria ON auditoria_items(auditoria_id)',
    'CREATE INDEX IF NOT EXISTS idx_auditoria_items_producto ON auditoria_items(producto_id)',
    'CREATE INDEX IF NOT EXISTS idx_auditoria_items_sync_status ON auditoria_items(sync_status)',
    'CREATE INDEX IF NOT EXISTS idx_producto_imagenes_producto ON producto_imagenes(producto_id, orden)',
    'CREATE INDEX IF NOT EXISTS idx_producto_imagenes_negocio_producto ON producto_imagenes(negocio_id, producto_id, orden)',
    'CREATE INDEX IF NOT EXISTS idx_producto_imagenes_uuid ON producto_imagenes(uuid)',
    'CREATE INDEX IF NOT EXISTS idx_producto_imagenes_product_uuid ON producto_imagenes(product_uuid)',
    'CREATE INDEX IF NOT EXISTS idx_producto_imagenes_sync_status ON producto_imagenes(sync_status)',
    'CREATE INDEX IF NOT EXISTS idx_deuda_items_movimiento ON deuda_items(movimiento_id)',
    'CREATE INDEX IF NOT EXISTS idx_deuda_items_negocio_movimiento ON deuda_items(negocio_id, movimiento_id)',
    'CREATE INDEX IF NOT EXISTS idx_deuda_items_producto ON deuda_items(producto_id)',
    'CREATE INDEX IF NOT EXISTS idx_deuda_items_negocio_producto ON deuda_items(negocio_id, producto_id)',
    'CREATE INDEX IF NOT EXISTS idx_deuda_items_sync_status ON deuda_items(sync_status)',
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_deuda_items_negocio_local_uuid ON deuda_items(negocio_id, local_uuid)',
    'CREATE INDEX IF NOT EXISTS idx_inventory_metrics_negocio_status ON inventory_product_metrics(negocio_id, status)',
    'CREATE INDEX IF NOT EXISTS idx_inventory_metrics_negocio_dirty ON inventory_product_metrics(negocio_id, dirty)',
    'CREATE INDEX IF NOT EXISTS idx_inventory_metrics_negocio_restock ON inventory_product_metrics(negocio_id, recommended_restock_quantity)',
    'CREATE INDEX IF NOT EXISTS idx_inventory_metrics_negocio_profit ON inventory_product_metrics(negocio_id, potential_profit)',
    'CREATE INDEX IF NOT EXISTS idx_business_recommendations_business_score ON business_recommendations_cache(business_id, dismissed, expires_at, score DESC)',
    'CREATE INDEX IF NOT EXISTS idx_business_recommendations_business_type ON business_recommendations_cache(business_id, type, dismissed)',
    'CREATE INDEX IF NOT EXISTS idx_business_recommendations_business_priority ON business_recommendations_cache(business_id, priority, dismissed)',
    'CREATE INDEX IF NOT EXISTS idx_comprobantes_movimiento ON comprobantes(movimiento_id)',
    'CREATE INDEX IF NOT EXISTS idx_comprobantes_negocio_fecha ON comprobantes(negocio_id, fecha DESC)',
    'CREATE INDEX IF NOT EXISTS idx_comprobantes_cliente ON comprobantes(cliente_nombre, cliente_telefono)',
    'CREATE INDEX IF NOT EXISTS idx_comprobantes_codigo ON comprobantes(codigo_comprobante)',
    'CREATE INDEX IF NOT EXISTS idx_comprobantes_sync_status ON comprobantes(sync_status)',
    'CREATE INDEX IF NOT EXISTS idx_credito_ciclos_cliente_estado ON credito_ciclos(negocio_id, cliente_id, estado)',
    'CREATE INDEX IF NOT EXISTS idx_credito_ciclos_estado ON credito_ciclos(negocio_id, estado, saldo_pendiente)',
    'CREATE INDEX IF NOT EXISTS idx_credito_ciclos_negocio_saldo_limite ON credito_ciclos(negocio_id, saldo_pendiente, fecha_limite_30)',
    'CREATE INDEX IF NOT EXISTS idx_credito_ciclos_negocio_estado_limites ON credito_ciclos(negocio_id, estado, fecha_limite_30, fecha_limite_45, fecha_bloqueo_60)',
    'CREATE INDEX IF NOT EXISTS idx_credito_ciclo_movimientos_ciclo ON credito_ciclo_movimientos(ciclo_id)',
    'CREATE INDEX IF NOT EXISTS idx_credito_recordatorios_cliente ON credito_recordatorios(negocio_id, cliente_id, estado)',
    'CREATE INDEX IF NOT EXISTS idx_credito_excepciones_cliente ON credito_excepciones(negocio_id, cliente_id, fecha DESC)',
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_client_scores_negocio_cliente ON client_scores(negocio_id, cliente_id)',
    'CREATE INDEX IF NOT EXISTS idx_client_scores_negocio_score ON client_scores(negocio_id, score DESC)',
    'CREATE INDEX IF NOT EXISTS idx_client_scores_sync_status ON client_scores(sync_status)',
    'CREATE INDEX IF NOT EXISTS idx_client_scores_updated_at ON client_scores(updated_at)',
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_user_onboarding_usuario_key ON user_onboarding(usuario_id, onboarding_key)',
    'CREATE INDEX IF NOT EXISTS idx_user_onboarding_sync_status ON user_onboarding(sync_status)',
    'CREATE INDEX IF NOT EXISTS idx_whatsapp_campaigns_negocio_fecha ON whatsapp_campaign_publications(negocio_id, date_key, created_at DESC)',
    'CREATE INDEX IF NOT EXISTS idx_whatsapp_campaigns_negocio_status ON whatsapp_campaign_publications(negocio_id, campaign_status, status)',
    'CREATE INDEX IF NOT EXISTS idx_whatsapp_campaigns_sync_status ON whatsapp_campaign_publications(sync_status)',
    'CREATE INDEX IF NOT EXISTS idx_sync_queue_status_created ON sync_queue(status, created_at)',
    'CREATE INDEX IF NOT EXISTS idx_sync_queue_entity ON sync_queue(entity_type, entity_id)',
    'CREATE INDEX IF NOT EXISTS idx_sync_outbox_business_module_status ON sync_outbox(business_id, module, status)',
    'CREATE INDEX IF NOT EXISTS idx_sync_outbox_entity_uuid ON sync_outbox(entity_uuid)',
    'CREATE INDEX IF NOT EXISTS idx_sync_outbox_updated_at ON sync_outbox(updated_at)',
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_state_business_module ON sync_state(business_id, module)',
  ];
}
