# Manual completo de Fiado App

## 1. Portada

- Nombre del documento: Manual completo de Fiado App, step by step.
- Nombre de la app: Fiado App.
- Fecha de generacion: 7 de julio de 2026.
- Proposito del manual: explicar de forma funcional y tecnica como trabaja Fiado App desde el registro inicial hasta la sincronizacion cloud, incluyendo modulos, reglas, relaciones, riesgos y validaciones QA.
- Alcance del documento: app Flutter, SQLite local, repositorios, providers, servicios de sincronizacion, backend ASP.NET Core, SQL Server, roles Personal, Negocio y Colaborador, flujos principales, riesgos y mantenimiento.

## 2. Indice general

- 1. Portada
- 2. Indice general
- 3. Resumen ejecutivo
- 4. Contexto general de Fiado App
- 5. Arquitectura general del sistema
- 6. Roles del sistema
- 7. Reglas de acceso y permisos
- 8. Login, registro y sesion
- 9. Suscripciones y planes
- 10. Clientes
- 11. Deudas / Fiado
- 12. Pagos
- 13. Inventario
- 14. Imagenes de inventario
- 15. Auditorias
- 16. Solicitudes de autorizacion
- 17. Colaboradores
- 18. Portal Personal
- 19. Comprobantes PDF
- 20. Campanas WhatsApp
- 21. Sincronizacion automatica
- 22. Sync queue legacy y sync v2
- 23. Backend
- 24. SQLite local
- 25. Multi-negocio
- 26. Mapa general de datos
- 27. Flujos principales step by step
- 28. Riesgos y puntos criticos
- 29. Checklist QA completo
- 30. Glosario
- 31. Resumen tecnico final
- 32. Resumen funcional final

## 3. Resumen ejecutivo

Fiado App resuelve un problema muy concreto: muchos negocios pequenos venden fiado, cobran por partes, manejan inventario y dependen de memoria, cuadernos o hojas sueltas para recordar quien debe, cuanto debe y que productos salieron. La aplicacion transforma ese flujo informal en un sistema ordenado, auditable y sincronizable.

- Esta disenada para negocios que venden a credito, clientes personales que quieren consultar lo que deben y colaboradores que ayudan a operar inventario o auditorias.
- Aporta control de clientes, deudas, pagos, inventario, comprobantes, auditorias, solicitudes de autorizacion y campanas comerciales.
- Funciona con enfoque offline-first: los datos se guardan primero en el dispositivo y luego se sincronizan cuando hay backend y conexion.
- Ayuda a reducir perdida de informacion, duplicados, cobros olvidados, stock inconsistente y dependencia de un solo dispositivo.

## 4. Contexto general de Fiado App

### 4.1 Objetivo principal

El objetivo principal es permitir que un negocio controle su cartera de fiado y su inventario desde una app local, con capacidad de sincronizar datos hacia un backend ASP.NET Core y SQL Server. El sistema busca que el negocio pueda operar aun sin internet y que los cambios pendientes se confirmen en cloud cuando sea posible.
### 4.2 Tipos de usuarios

- Personal: persona que consulta sus deudas y recordatorios asociados a su telefono.
- Negocio: propietario o administrador que controla clientes, deudas, pagos, inventario, colaboradores, auditorias, suscripcion y reportes.
- Colaborador: usuario asociado a un negocio que ejecuta tareas operativas con permisos limitados.
### 4.3 Problemas que busca resolver

- Clientes duplicados o mezclados entre negocios.
- Deudas sin detalle, sin comprobante o sin historial confiable.
- Pagos que no actualizan saldo correctamente.
- Inventario desactualizado al vender fiado con productos.
- Colaboradores con acciones sensibles sin supervision.
- Datos atrapados en un solo dispositivo sin sincronizacion.
### 4.4 Offline-first y varios dispositivos

SQLite local es la fuente inmediata de trabajo. La nube no reemplaza la operacion local: la complementa. El flujo esperado es guardar en SQLite, registrar una operacion pendiente en una cola de sincronizacion, hacer push al backend y luego hacer pull desde otros dispositivos.
### 4.5 Relacion app local, SQLite, backend y sincronizacion

La app Flutter se comunica con providers Riverpod. Los providers llaman repositorios y servicios. Los repositorios escriben en SQLite y registran pendientes. Los servicios de sincronizacion envian y reciben datos del backend. El backend persiste en SQL Server usando Entity Framework Core.
## 5. Arquitectura general del sistema

### 5.1 Componentes

- UI/Pantallas: pantallas en lib/screens y lib/presentation que muestran formularios, dashboards, reportes y estados.
- Providers/estado: auth_providers.dart, fiado_data_providers.dart y sync_providers.dart conectan UI con datos y servicios.
- Repositorios: capa de acceso a SQLite para clientes, movimientos, productos, imagenes, auditorias, solicitudes, comprobantes, sync y suscripciones.
- SQLite local: fiado_app.db con version de schema 29, tablas de negocio y colas de sincronizacion.
- Sync queue legacy: tabla sync_queue para cambios pendientes por entity_type, entity_id, operation y payload.
- Sync v2: sync_outbox y sync_state para sincronizacion generica por business_id, modulo y entity_uuid.
- Servicios de sincronizacion: AutoSyncService, SyncEngine y servicios Cloud*SyncService.
- Backend ASP.NET Core: controllers, services, DTOs, JWT, CORS, health checks y EF Core.
- SQL Server/backend cloud: persistencia remota con BusinessId, RemoteId, LocalId e indices para pull incremental.
### 5.2 Viaje de datos desde pantalla hasta nube

1. La pantalla recibe una accion del usuario.
2. El provider o notifier valida contexto: usuario, rol y negocio activo.
3. El repositorio ejecuta la escritura en SQLite.
4. Si el cambio es sincronizable, se registra en sync_queue o sync_outbox.
5. AutoSyncService o SyncEngine detecta pendientes.
6. El servicio cloud prepara payload JSON y lo envia al endpoint del backend.
7. El backend valida JWT, obtiene BusinessId, guarda en SQL Server y responde con serverId/estado.
8. La app actualiza remote_id, sync_status y last_synced_at.
9. Otros dispositivos hacen pull y actualizan su SQLite local.
10. La UI refresca providers y muestra datos actualizados.
### 5.3 Archivos principales

- lib/core/database/database_schema.dart: tablas, indices y version SQLite.
- lib/core/database/database_helper.dart: apertura de DB, migraciones y backfills.
- lib/data/repositories/*: repositorios locales.
- lib/data/services/*sync*.dart: servicios de sincronizacion.
- backend/src/FiadoApp.Api/Program.cs: configuracion backend.
- backend/src/FiadoApp.Api/Data/FiadoDbContext.cs: modelo cloud.
- backend/src/FiadoApp.Api/Controllers/*.cs: endpoints.

## 6. Roles del sistema

### 6.1 Personal

- Que es: usuario final que quiere consultar deudas propias registradas por negocios.
- Como se registra: mediante flujo de registro Personal, usando telefono y credenciales.
- Que puede ver: deudas asociadas a su telefono, saldos por negocio, vencimientos y comprobantes propios cuando aplican.
- Que no puede hacer: no administra clientes, inventario, auditorias, colaboradores, suscripciones ni datos internos del negocio.
- Relacion con negocios: su telefono conecta con movimientos y ciclos generados por negocios; no le da control sobre esos negocios.
### 6.2 Negocio

- Que es: propietario o administrador del negocio.
- Permisos: acceso completo a clientes, deudas, pagos, inventario, imagenes, auditorias, solicitudes, colaboradores, suscripcion, reportes y sync.
- Modulos que administra: clientes, movimientos, productos, comprobantes, campanas WhatsApp, auditorias, autorizaciones, colaboradores, billing y dashboards.
- Regla central: sus datos se separan por negocio_id local y BusinessId en backend.
### 6.3 Colaborador

- Que es: usuario creado por un negocio para apoyar operacion.
- Como se crea: el negocio lo registra y queda asociado por negocio_id.
- Que puede hacer: operar inventario permitido, realizar auditorias, crear solicitudes y ver su panel operativo.
- Que no puede ver: datos administrativos completos, suscripcion del negocio y acciones sensibles fuera de su permiso.
- Acciones con autorizacion: cambios sensibles en productos existentes como costo, margen o precio de venta, y otras ediciones que el negocio deba aprobar.

## 7. Reglas de acceso y permisos

| Modulo | Personal | Negocio | Colaborador | Observaciones |
|---|---|---|---|---|
| Login/registro | Permitido para su tipo | Permitido | Login permitido si fue creado | Cada rol carga dashboard distinto. |
| Clientes | No administra | Crear, editar, listar y sincronizar | Acceso operativo segun permisos | Siempre filtrar por negocio_id. |
| Deudas/pagos | Ve deudas propias | Crear y cobrar | Puede operar si el negocio lo permite | Saldos y ciclos son criticos. |
| Inventario | No permitido | Control completo | Agregar/operar con restricciones | Cambios sensibles pueden requerir solicitud. |
| Imagenes de productos | No permitido | Agregar/editar | Puede agregar en flujos permitidos | Maximo 3 imagenes por producto. |
| Auditorias | No permitido | Ver reportes | Ejecutar auditorias | Colaborador ve sus auditorias. |
| Solicitudes | No aplica | Aprobar/rechazar | Crear/ver las propias | Evitan permisos indebidos. |
| Suscripciones | No paga | Administra plan/trial/pagos | Depende del plan del negocio | Limites de colaboradores por plan. |
| Campanas WhatsApp | No permitido | Crear/publicar | Segun permisos | Publicacion es manual, no API oficial. |
| Sync | Indirecto | Sincroniza datos del negocio | Sincroniza datos autorizados | Requiere JWT y businessId para cloud. |

## 8. Login, registro y sesion

### 8.1 Registro Personal

1. El usuario elige tipo Personal.
2. Ingresa datos como nombre, telefono y credenciales.
3. La app crea o vincula usuario local y, si hay backend, puede registrar en cloud.
4. Se inicia sesion local y se muestra Portal Personal.
5. La app consulta deudas asociadas al telefono autenticado.
### 8.2 Registro Negocio

1. El usuario elige tipo Negocio.
2. Ingresa datos de negocio, administrador, telefono y plan.
3. La app/backend crea usuario Negocio y entidad Business.
4. Se activa trial o suscripcion inicial.
5. Se guarda sesion local y JWT cloud si aplica.
6. Se abre dashboard Negocio.
### 8.3 Creacion de Colaborador

1. El Negocio abre gestion de colaboradores.
2. Registra nombre, telefono y credenciales del colaborador.
3. El colaborador queda asociado al negocio_id del negocio.
4. El colaborador inicia sesion y ve ColaboradorDashboardScreen.
### 8.4 Login local y login cloud

- Login local: usa datos persistidos en SQLite para permitir entrada y sesion del dispositivo.
- Login cloud: usa CloudAuthService y backend /api/auth/login para obtener JWT, businessId y sessionVersion.
- Vinculacion local/cloud: relaciona usuario local con identidad cloud y permite sincronizar.
### 8.5 Sesion activa y sesion unica

El backend tiene soporte para ActiveDeviceId y SessionVersion. Program.cs valida la sesion activa en cada request protegido. Si otro dispositivo inicia sesion y reemplaza la sesion anterior, el dispositivo viejo puede recibir 401 con codigo SESSION_REPLACED.
### 8.6 Sin internet o backend caido

- La app puede seguir trabajando con datos locales ya disponibles.
- Los cambios sincronizables quedan pendientes.
- El usuario debe ver estado como guardado en este dispositivo o no se pudo actualizar segun el caso.
- Cuando vuelve la conexion, AutoSyncService intenta confirmar cambios.

## 9. Suscripciones y planes

- Rol que paga: Negocio.
- Roles que no pagan: Personal y Colaborador.
- Trial: Negocio tiene prueba gratis de 30 dias segun la arquitectura documentada.
- Plan Basico: USD 4.99 mensual, 3 colaboradores.
- Plan Crecimiento: USD 12.99 mensual, 7 colaboradores.
- Plan Empresarial: USD 20.99 mensual, 15 colaboradores.
- Ciclos: mensual, trimestral con descuento y anual con descuento.
- Relacion con acceso: el negocio necesita trial o suscripcion valida para operar plenamente; colaboradores dependen del plan del negocio.
Los precios tienen fuente en Flutter, lib/core/constants/subscription_plans.dart, y backend, backend/src/FiadoApp.Api/Subscriptions/SubscriptionPlanCatalog.cs. Riesgo importante: no actualizar uno sin el otro.

## 10. Clientes

### 10.1 Crear cliente step by step

1. Negocio abre ClientesScreen.
2. Ingresa nombre, telefono y datos opcionales.
3. Provider llama al repositorio de clientes.
4. Repositorio valida negocio_id y duplicados por telefono dentro del negocio.
5. SQLite guarda en clientes con uuid, created_at, updated_at y sync_status.
6. Se registra pendiente de sincronizacion.
7. CloudClientSyncService hace push y luego pull.
### 10.2 Editar cliente

Editar cliente actualiza datos editables sin romper cliente_id local. Los movimientos conservan snapshots historicos de nombre y telefono, por lo que cambiar el cliente no debe borrar contexto de deudas antiguas.
### 10.3 Relaciones

- Deudas y pagos: movimientos.cliente_id y snapshots.
- Portal Personal: telefono del cliente permite asociar deudas al usuario Personal.
- Comprobantes: guardan datos del cliente y movimiento.
- Sync: clientes.remote_id enlaza con backend.
### 10.4 Archivos y tablas

- Tablas: clientes, movimientos, comprobantes, credito_ciclos, client_scores.
- Repositorios: cliente_repository.dart, client_repository_impl.dart.
- Servicios: cloud_client_sync_service.dart.
- Pantallas: clientes_screen.dart, detalle_cliente_screen.dart, historial_cliente_screen.dart.

## 11. Deudas / Fiado

### 11.1 Crear deuda simple

1. Seleccionar cliente.
2. Ingresar monto y concepto.
3. Guardar movimiento tipo deuda.
4. Actualizar saldo del cliente y ciclo de credito.
5. Crear comprobante si el flujo lo requiere.
6. Encolar movimiento para sync.
### 11.2 Crear deuda con productos

1. Abrir dialogo de agregar deuda.
2. Seleccionar productos facturables desde BillableProductQuery.
3. Precargar precio de venta del producto.
4. Ingresar cantidades.
5. Calcular subtotal automatico.
6. Permitir monto final manual si el negocio ajusta el fiado.
7. Guardar movimiento principal.
8. Guardar deuda_items con producto, cantidad, precio_unitario y subtotal.
9. Descontar stock en la misma transaccion.
10. Generar comprobante y encolar sync.
### 11.3 Relaciones y riesgos

- Relaciones: clientes -> movimientos -> deuda_items -> productos -> comprobantes.
- Inventario: una deuda con productos descuenta stock.
- Sync: movimientos y debt-items tienen endpoints de push/pull.
- Riesgo: producto sin precio de venta puede generar subtotal incorrecto.
- Validacion necesaria: precio_unitario mayor que cero, stock suficiente o decision explicita del negocio, cliente valido y negocio_id presente.

## 12. Pagos

1. Seleccionar cliente o deuda/ciclo a pagar.
2. Ingresar monto del pago.
3. Guardar movimiento tipo pago.
4. Aplicar pago al ciclo pendiente mas viejo.
5. Actualizar saldo_pendiente, monto_pagado y estado del ciclo si queda saldado.
6. Generar comprobante de pago.
7. Encolar movimiento y comprobante para sincronizacion.
Riesgo principal: divergencia entre dispositivos si un pago queda local sin confirmar y otro dispositivo sigue mostrando saldo anterior. La UI debe distinguir datos guardados localmente de datos confirmados en cloud.

## 13. Inventario

### 13.1 Crear producto

1. Negocio o colaborador autorizado abre InventarioScreen.
2. Ingresa nombre, categoria, descripcion, cantidad, costo, precio de venta, margen, stock minimo, codigo y ubicacion.
3. Repositorio valida negocio_id y unicidad de nombre/codigo en productos activos.
4. SQLite guarda en productos.
5. Se encola sync y se refrescan providers.
### 13.2 Editar, eliminar y ajustar stock

- Editar producto actualiza campos y marca sync_status.
- Eliminar producto debe ser baja logica con activo/deleted_at para poder sincronizar.
- Ajustar stock afecta inventario_product_metrics y puede requerir auditoria o autorizacion si lo hace un colaborador.
### 13.3 Relaciones

- Deudas: deuda_items descuenta productos.
- Auditorias: auditoria_items compara stock_sistema y stock_fisico.
- Imagenes: producto_imagenes guarda hasta 3 imagenes.
- WhatsApp: campanas seleccionan productos activos con stock.
- Sync: CloudProductSyncService sincroniza productos e imagenes.

## 14. Imagenes de inventario

1. Usuario selecciona o captura imagen.
2. La app valida formato JPG/JPEG/PNG.
3. ProductImageOptimizerService optimiza a 500 x 500 px y comprime.
4. ProductoImagenRepository guarda local_path y metadata.
5. La miniatura se muestra desde producto_imagenes.
6. La metadata se sincroniza con endpoints de products/images.
7. El contenido/binario puede usar rutas especificas inventory/images/content segun servicio disponible.
- Tablas: producto_imagenes, productos.
- Endpoints: /api/products/images/sync/push, /api/products/images/sync/pull, /api/sync/inventory/images/content/push.
- Riesgos: imagenes pesadas, rutas locales no existentes en otro dispositivo, base64 grande en payload, endpoint mal enrutado.

## 15. Auditorias

### 15.1 Auditoria diaria

- Objetivo: validar stock fisico de productos contra stock del sistema.
- Generacion: desde InventarioScreen/AuditoriaScreen.
- Productos incluidos: productos seleccionados o pendientes segun reglas de pantalla.
- Actor: colaborador o negocio.
- Guardado: auditorias como cabecera y auditoria_items por producto.
- Sync: CloudAuditSyncService envia auditorias y audit-items.
### 15.2 Auditoria semanal

- Objetivo: revision mas amplia o de productos clave por semana.
- Dia sugerido: no se confirmo un dia fijo en codigo; la app valida disponibilidad semanal por fecha/semana. Esto es una deduccion desde InventarioScreen.
- Reportes: AuditoriaReportesScreen permite revisar resumen y detalle.
- Relacion: negocio ve reportes; colaborador ve sus auditorias.

## 16. Solicitudes de autorizacion

1. Colaborador intenta ejecutar cambio sensible.
2. La app construye solicitud con tipo_solicitud, entidad, entidad_id, datos_antes y datos_despues.
3. Se guarda en solicitudes_autorizacion con estado pendiente.
4. El negocio ve pendientes.
5. El negocio aprueba o rechaza con comentario.
6. La decision se sincroniza.
7. El colaborador ve el resultado en sus solicitudes.
- Acciones tipicas: editar costo, margen o precio de venta de productos existentes.
- Riesgo: aplicar cambios antes de aprobar o permitir cambios fuera del negocio_id.

## 17. Colaboradores

- Creacion: el Negocio registra colaborador desde gestion de colaboradores o endpoint de AuthController.
- Relacion con negocio_id: usuarios.negocio_id apunta al negocio propietario.
- Permisos: operacion limitada, auditorias, solicitudes y tareas autorizadas.
- Restricciones: no administra suscripcion, no debe ver datos administrativos completos, no debe editar sensible sin autorizacion.
- Auditorias: auditorias.colaborador_id permite reportar quien realizo conteo.
- Impacto: sus acciones modifican datos del negocio, por eso negocio_id y autorizaciones son criticos.

## 18. Portal Personal

- Ve saldos propios agrupados por negocio.
- Consulta vencimientos, historial y recordatorios suaves.
- No modifica deuda, inventario, pagos ni datos del negocio.
- Se relaciona con clientes registrados por negocios principalmente por telefono autenticado.
- Riesgo: telefonos mal normalizados pueden asociar datos incorrectamente.

## 19. Comprobantes PDF

1. Se crea una deuda o pago.
2. ComprobanteRepository guarda registro en comprobantes.
3. Se incluye tipo, movimiento_id, cliente, negocio, codigo, fecha, subtotal, total, saldo anterior, saldo nuevo y payload_json.
4. ComprobanteScreen muestra el comprobante.
5. ComprobantePdfService genera PDF.
6. El usuario comparte o imprime mediante herramientas del dispositivo.
7. CloudReceiptSyncService sincroniza comprobantes cuando aplica.
- Comprobante de deuda: documenta fiado creado.
- Comprobante de pago: documenta abono o saldo pagado.
- Riesgo: payload_json desactualizado; la arquitectura contempla reconstruir articulos desde deuda_items.

## 20. Campanas WhatsApp

1. Negocio abre creacion de campana.
2. Selecciona productos activos con stock.
3. Selecciona o usa imagenes renderizadas de productos.
4. Define textos y duracion. El requerimiento menciona 7/15/30 dias; en el schema actual existe duracion_dias con valor por defecto 7. No se confirmo UI completa para 15/30 en esta lectura.
5. WhatsappStatusImageRenderer crea flyers.
6. La app abre share sheet o WhatsApp manualmente.
7. El usuario confirma si publico.
8. Se guarda estado en whatsapp_campaign_publications y se sincroniza.
- Retiro automatico si producto no esta disponible: se deduce como regla deseada; el schema conserva campaign_status/is_active, pero debe validarse en UI/servicio antes de prometer automatizacion completa.
- No usa API oficial de WhatsApp; la publicacion es manual.

## 21. Sincronizacion automatica

### 21.1 Objetivo

La sincronizacion automatica busca que el usuario no tenga que pensar en push/pull tecnico. La app debe guardar localmente, detectar pendientes y confirmar en backend cuando haya condiciones.
### 21.2 Eventos que pueden activarla

- Inicio de app.
- Login o registro.
- Vuelta a foreground.
- Recuperacion de internet.
- Intervalo automatico o debounce interno.
- Boton manual Sincronizar con la nube.
### 21.3 Push y pull

- Push: envia cambios locales pendientes al backend.
- Pull: trae cambios remotos desde lastSyncAt/last_pull_at y actualiza SQLite.
- Pendientes: se mantienen en sync_queue o sync_outbox hasta confirmacion.
- Errores: se registran con attempts, last_error o sync_state.last_error.
### 21.4 Estados visibles al usuario

- Actualizando...: hay sync en proceso.
- Guardado en este dispositivo: el dato existe localmente pero puede no estar confirmado en cloud.
- Todo guardado: no hay pendientes locales relevantes.
- Todo actualizado: cloud y local estan alineados segun ultimo ciclo exitoso.
- No se pudo actualizar: hubo error de red, backend, token o contrato.
### 21.5 Riesgos

- Datos locales no confirmados en cloud.
- Divergencia entre dispositivos.
- Duplicados por reintentos sin idempotencia.
- Errores legacy persistentes.
- Sesion cloud invalida o reemplazada.

## 22. Sync queue legacy y sync v2

### 22.1 Legacy

sync_queue es la cola historica. Guarda entity_type, entity_id, operation, payload, status, attempts, last_error, created_at y updated_at. Muchos repositorios y servicios cloud especificos la usan para modulos existentes.
### 22.2 Sync v2

sync_outbox y sync_state son la base nueva. sync_outbox guarda uuid, business_id, module, entity_type, entity_uuid, operation, payload_json y estado. sync_state guarda ultimos pull/push por business_id y modulo.
### 22.3 Coexistencia

- Pueden coexistir porque la app migra de sincronizacion por entidad legacy a sincronizacion generica por modulos.
- Riesgo: enviar dos veces el mismo cambio si un modulo usa ambas rutas sin idempotencia.
- Diagnostico: SyncDiagnosticsRepository y LegacySyncQueueDiagnostics revisan pendientes, errores y estado visible.
- Evitar perdida: no limpiar pendientes sin confirmar que el dato existe en SQLite y cloud.

## 23. Backend

- Tecnologia: ASP.NET Core, controllers, services, DTOs, JWT Bearer, EF Core, SQL Server.
- Auth: /api/auth/register/personal, /api/auth/register/business, /api/auth/register/collaborator, /api/auth/login, /api/auth/me.
- Clientes: /api/clients y /api/clients/sync/*.
- Inventario: /api/products y /api/products/sync/*.
- Imagenes: /api/products/images/sync/* y /api/sync/inventory/images/*.
- Deudas: /api/movements/sync/* y /api/debt-items/sync/*.
- Pagos/suscripciones: /api/payments/* y /api/subscriptions/*.
- Campanas: /api/whatsapp-campaigns/sync/*.
- Auditorias: /api/audits/* y /api/audit-items/sync/*.
- Health: /health y /api/health existen en el backend.
- Configuracion local: ApiEnvironmentConfig define URLs por plataforma; BackendSettingsScreen permite override y prueba de health.

## 24. SQLite local

- Se usa porque permite operacion offline-first, bajo costo, rapidez y control local.
- DatabaseSchema.version actual: 29.
- Tablas principales: usuarios, sesiones, clientes, movimientos, pagos, productos, producto_imagenes, deuda_items, comprobantes, subscriptions, auditorias, auditoria_items, solicitudes_autorizacion, credito_ciclos, client_scores, whatsapp_campaign_publications, sync_queue, sync_outbox y sync_state.
- Migraciones: DatabaseHelper.onUpgrade agrega tablas, columnas, indices y backfills.
- Reglas por negocio_id: toda entidad de negocio debe filtrar por negocio_id.
- Backfills: cliente_id, uuid, sync fields, negocio_id e idempotencia se aseguran con funciones defensivas.
- Riesgo: migraciones incompletas pueden romper startup o perder relaciones.

## 25. Multi-negocio

- Significa que cada negocio tiene su propio conjunto de clientes, productos, movimientos, auditorias, solicitudes y campanas.
- SQLite usa negocio_id; backend usa BusinessId desde JWT.
- Clientes: telefono unico por negocio, no global.
- Productos: nombre/codigo deben validarse por negocio activo.
- Colaboradores: usuario colaborador queda asociado a negocio_id.
- Riesgo critico: cualquier consulta sin negocio_id puede mezclar datos, exponer informacion o crear duplicados.

## 26. Mapa general de datos

### 26.x Mapa de Cliente

1. Usuario crea o modifica Cliente en pantalla.
2. Provider recibe la accion y obtiene usuario/negocio activo.
3. Repositorio/servicio relacionado (ClienteRepository; CloudClientSyncService) valida datos.
4. SQLite guarda en tablas: clientes.
5. Se crea pendiente en sync_queue o sync_outbox si aplica.
6. AutoSyncService detecta pendiente.
7. Se envia al backend con JWT.
8. Backend guarda en SQL Server usando BusinessId.
9. Otro dispositivo hace pull.
10. SQLite del otro dispositivo se actualiza y la UI refresca.
### 26.x Mapa de Deuda

1. Usuario crea o modifica Deuda en pantalla.
2. Provider recibe la accion y obtiene usuario/negocio activo.
3. Repositorio/servicio relacionado (MovimientoRepository; DeudaItemRepository; CloudMovementSyncService) valida datos.
4. SQLite guarda en tablas: movimientos; deuda_items; credito_ciclos.
5. Se crea pendiente en sync_queue o sync_outbox si aplica.
6. AutoSyncService detecta pendiente.
7. Se envia al backend con JWT.
8. Backend guarda en SQL Server usando BusinessId.
9. Otro dispositivo hace pull.
10. SQLite del otro dispositivo se actualiza y la UI refresca.
### 26.x Mapa de Pago

1. Usuario crea o modifica Pago en pantalla.
2. Provider recibe la accion y obtiene usuario/negocio activo.
3. Repositorio/servicio relacionado (MovimientoRepository; CreditoCicloRepository; CloudReceiptSyncService) valida datos.
4. SQLite guarda en tablas: movimientos; credito_ciclos; comprobantes.
5. Se crea pendiente en sync_queue o sync_outbox si aplica.
6. AutoSyncService detecta pendiente.
7. Se envia al backend con JWT.
8. Backend guarda en SQL Server usando BusinessId.
9. Otro dispositivo hace pull.
10. SQLite del otro dispositivo se actualiza y la UI refresca.
### 26.x Mapa de Producto

1. Usuario crea o modifica Producto en pantalla.
2. Provider recibe la accion y obtiene usuario/negocio activo.
3. Repositorio/servicio relacionado (ProductoRepository; CloudProductSyncService) valida datos.
4. SQLite guarda en tablas: productos; inventory_product_metrics.
5. Se crea pendiente en sync_queue o sync_outbox si aplica.
6. AutoSyncService detecta pendiente.
7. Se envia al backend con JWT.
8. Backend guarda en SQL Server usando BusinessId.
9. Otro dispositivo hace pull.
10. SQLite del otro dispositivo se actualiza y la UI refresca.
### 26.x Mapa de Imagen

1. Usuario crea o modifica Imagen en pantalla.
2. Provider recibe la accion y obtiene usuario/negocio activo.
3. Repositorio/servicio relacionado (ProductoImagenRepository; InventoryMediaSyncService) valida datos.
4. SQLite guarda en tablas: producto_imagenes; productos.
5. Se crea pendiente en sync_queue o sync_outbox si aplica.
6. AutoSyncService detecta pendiente.
7. Se envia al backend con JWT.
8. Backend guarda en SQL Server usando BusinessId.
9. Otro dispositivo hace pull.
10. SQLite del otro dispositivo se actualiza y la UI refresca.
### 26.x Mapa de Auditoria

1. Usuario crea o modifica Auditoria en pantalla.
2. Provider recibe la accion y obtiene usuario/negocio activo.
3. Repositorio/servicio relacionado (AuditoriaRepository; CloudAuditSyncService) valida datos.
4. SQLite guarda en tablas: auditorias; auditoria_items; productos.
5. Se crea pendiente en sync_queue o sync_outbox si aplica.
6. AutoSyncService detecta pendiente.
7. Se envia al backend con JWT.
8. Backend guarda en SQL Server usando BusinessId.
9. Otro dispositivo hace pull.
10. SQLite del otro dispositivo se actualiza y la UI refresca.
### 26.x Mapa de Campana WhatsApp

1. Usuario crea o modifica Campana WhatsApp en pantalla.
2. Provider recibe la accion y obtiene usuario/negocio activo.
3. Repositorio/servicio relacionado (WhatsappCampaignRepository; CloudWhatsappCampaignSyncService) valida datos.
4. SQLite guarda en tablas: whatsapp_campaign_publications; productos; producto_imagenes.
5. Se crea pendiente en sync_queue o sync_outbox si aplica.
6. AutoSyncService detecta pendiente.
7. Se envia al backend con JWT.
8. Backend guarda en SQL Server usando BusinessId.
9. Otro dispositivo hace pull.
10. SQLite del otro dispositivo se actualiza y la UI refresca.
## 27. Flujos principales step by step

### 27.x Registro de negocio

- Objetivo: Registro de negocio.
- Actor principal: Negocio.
- Precondiciones: Backend disponible para registro cloud o flujo local preparado..
Pasos detallados:
1. Capturar datos del negocio y administrador.
2. Crear usuario Negocio.
3. Crear o vincular Business cloud.
4. Activar trial/suscripcion.
5. Guardar sesion local y JWT si aplica.
6. Abrir dashboard Negocio.
- Datos que se guardan: usuario, business, suscripcion, sesion.
- Tablas involucradas: usuarios; subscriptions; Businesses; Subscriptions.
- Providers/repositorios/servicios: AuthRepository; CloudAuthService; SubscriptionRepository.
- Resultado esperado: Negocio entra al sistema con acceso inicial..
- Riesgos: trial o token no creado, plan inconsistente.
- Validaciones QA: Probar registro, login inmediato y estado de suscripcion..

### 27.x Login de negocio

- Objetivo: Login de negocio.
- Actor principal: Negocio.
- Precondiciones: Usuario registrado..
Pasos detallados:
1. Ingresar telefono y password.
2. Validar local/cloud.
3. Guardar JWT, businessId y sessionVersion.
4. Validar suscripcion.
5. Cargar dashboard y providers.
- Datos que se guardan: sesion y token.
- Tablas involucradas: usuarios; sesiones; subscriptions.
- Providers/repositorios/servicios: AuthRepository; CloudAuthService; auth_providers.
- Resultado esperado: Dashboard de negocio visible..
- Riesgos: SESSION_REPLACED o backend caido.
- Validaciones QA: Probar login online/offline y segundo dispositivo..

### 27.x Registro de cliente

- Objetivo: Registro de cliente.
- Actor principal: Negocio.
- Precondiciones: Sesion Negocio valida..
Pasos detallados:
1. Abrir Clientes.
2. Ingresar datos.
3. Validar telefono unico por negocio.
4. Guardar en SQLite.
5. Encolar sync.
6. Confirmar en backend.
- Datos que se guardan: cliente local, uuid, remote_id posterior.
- Tablas involucradas: clientes; sync_queue.
- Providers/repositorios/servicios: ClienteRepository; CloudClientSyncService.
- Resultado esperado: Cliente aparece en lista y sincroniza..
- Riesgos: duplicado por negocio.
- Validaciones QA: Crear mismo telefono en dos negocios y en mismo negocio..

### 27.x Crear deuda simple

- Objetivo: Crear deuda simple.
- Actor principal: Negocio.
- Precondiciones: Cliente existente..
Pasos detallados:
1. Seleccionar cliente.
2. Ingresar monto/concepto.
3. Crear movimiento deuda.
4. Actualizar saldo/ciclo.
5. Generar comprobante si aplica.
6. Encolar sync.
- Datos que se guardan: movimiento deuda, ciclo, comprobante.
- Tablas involucradas: movimientos; credito_ciclos; comprobantes.
- Providers/repositorios/servicios: MovimientoRepository; CreditoCicloRepository.
- Resultado esperado: Saldo aumenta y deuda queda registrada..
- Riesgos: saldo incorrecto.
- Validaciones QA: Verificar saldo, historial y sync..

### 27.x Crear deuda con productos

- Objetivo: Crear deuda con productos.
- Actor principal: Negocio.
- Precondiciones: Cliente y productos facturables..
Pasos detallados:
1. Seleccionar cliente.
2. Seleccionar productos.
3. Validar precio.
4. Calcular subtotal.
5. Guardar movimiento.
6. Guardar deuda_items.
7. Descontar stock.
8. Generar comprobante.
9. Sincronizar.
- Datos que se guardan: movimiento, items, stock actualizado.
- Tablas involucradas: movimientos; deuda_items; productos; comprobantes.
- Providers/repositorios/servicios: BillableProductQuery; MovimientoRepository; DeudaItemRepository.
- Resultado esperado: Deuda y stock quedan consistentes..
- Riesgos: producto sin precio o doble descuento.
- Validaciones QA: Validar total, stock, PDF y pull en segundo dispositivo..

### 27.x Registrar pago

- Objetivo: Registrar pago.
- Actor principal: Negocio.
- Precondiciones: Cliente con saldo pendiente..
Pasos detallados:
1. Seleccionar cliente.
2. Ingresar monto.
3. Crear movimiento pago.
4. Aplicar al ciclo mas viejo.
5. Actualizar saldo.
6. Generar comprobante.
7. Sincronizar.
- Datos que se guardan: pago, saldo, comprobante.
- Tablas involucradas: movimientos; credito_ciclos; comprobantes.
- Providers/repositorios/servicios: MovimientoRepository; CreditoCicloRepository; ComprobanteRepository.
- Resultado esperado: Saldo baja correctamente..
- Riesgos: divergencia entre dispositivos.
- Validaciones QA: Pago parcial, pago total y sync..

### 27.x Crear producto

- Objetivo: Crear producto.
- Actor principal: Negocio/Colaborador autorizado.
- Precondiciones: Negocio activo..
Pasos detallados:
1. Abrir inventario.
2. Ingresar datos.
3. Validar nombre/codigo por negocio.
4. Guardar producto.
5. Encolar sync.
- Datos que se guardan: producto.
- Tablas involucradas: productos.
- Providers/repositorios/servicios: ProductoRepository; CloudProductSyncService.
- Resultado esperado: Producto visible y sincronizable..
- Riesgos: duplicado o falta negocio_id.
- Validaciones QA: Crear producto con codigo repetido..

### 27.x Agregar imagen a producto

- Objetivo: Agregar imagen a producto.
- Actor principal: Negocio/Colaborador autorizado.
- Precondiciones: Producto existente..
Pasos detallados:
1. Seleccionar imagen.
2. Optimizar.
3. Guardar metadata y path.
4. Mostrar miniatura.
5. Sincronizar metadata/contenido.
- Datos que se guardan: imagen metadata.
- Tablas involucradas: producto_imagenes.
- Providers/repositorios/servicios: ProductoImagenRepository; ProductImageOptimizerService; InventoryMediaSyncService.
- Resultado esperado: Imagen visible en producto..
- Riesgos: archivo pesado o ruta no portable.
- Validaciones QA: Validar 3 imagenes, formato y segundo dispositivo..

### 27.x Ajuste de inventario

- Objetivo: Ajuste de inventario.
- Actor principal: Negocio/Colaborador autorizado.
- Precondiciones: Producto existente..
Pasos detallados:
1. Abrir producto.
2. Cambiar cantidad/costo/precio.
3. Si colaborador y cambio sensible, crear solicitud.
4. Guardar o esperar aprobacion.
5. Marcar metricas dirty.
6. Sincronizar.
- Datos que se guardan: producto actualizado o solicitud.
- Tablas involucradas: productos; solicitudes_autorizacion; inventory_product_metrics.
- Providers/repositorios/servicios: ProductoRepository; SolicitudAutorizacionRepository.
- Resultado esperado: Stock/precio correcto o solicitud pendiente..
- Riesgos: permiso indebido.
- Validaciones QA: Probar con Negocio y Colaborador..

### 27.x Solicitud de autorizacion de colaborador

- Objetivo: Solicitud de autorizacion de colaborador.
- Actor principal: Colaborador y Negocio.
- Precondiciones: Colaborador activo..
Pasos detallados:
1. Colaborador solicita cambio.
2. Guardar datos antes/despues.
3. Sync de solicitud.
4. Negocio revisa.
5. Aprueba o rechaza.
6. Estado vuelve al colaborador.
- Datos que se guardan: solicitud y decision.
- Tablas involucradas: solicitudes_autorizacion.
- Providers/repositorios/servicios: SolicitudAutorizacionRepository; CloudAuthorizationRequestSyncService.
- Resultado esperado: Decision registrada..
- Riesgos: aplicar cambio sin aprobacion.
- Validaciones QA: Probar approve/reject..

### 27.x Auditoria diaria

- Objetivo: Auditoria diaria.
- Actor principal: Colaborador/Negocio.
- Precondiciones: Productos disponibles..
Pasos detallados:
1. Iniciar auditoria.
2. Crear cabecera.
3. Contar productos.
4. Guardar items.
5. Finalizar.
6. Sincronizar.
- Datos que se guardan: auditoria e items.
- Tablas involucradas: auditorias; auditoria_items.
- Providers/repositorios/servicios: AuditoriaRepository; CloudAuditSyncService.
- Resultado esperado: Reporte diario disponible..
- Riesgos: auditoria incompleta.
- Validaciones QA: Validar conteos y reportes..

### 27.x Auditoria semanal

- Objetivo: Auditoria semanal.
- Actor principal: Colaborador/Negocio.
- Precondiciones: Semana no completada..
Pasos detallados:
1. Validar disponibilidad semanal.
2. Crear auditoria semanal.
3. Contar productos clave.
4. Guardar diferencias.
5. Generar reporte.
6. Sincronizar.
- Datos que se guardan: auditoria semanal.
- Tablas involucradas: auditorias; auditoria_items.
- Providers/repositorios/servicios: AuditoriaRepository.
- Resultado esperado: Reporte semanal disponible..
- Riesgos: zona horaria/semana mal calculada.
- Validaciones QA: Probar cambio de semana..

### 27.x Generacion de comprobante PDF

- Objetivo: Generacion de comprobante PDF.
- Actor principal: Negocio.
- Precondiciones: Movimiento creado..
Pasos detallados:
1. Crear comprobante.
2. Cargar datos.
3. Generar PDF.
4. Compartir/imprimir.
5. Sincronizar receipt.
- Datos que se guardan: comprobante y PDF.
- Tablas involucradas: comprobantes; movimientos; deuda_items.
- Providers/repositorios/servicios: ComprobanteRepository; ComprobantePdfService.
- Resultado esperado: PDF refleja saldo y detalle..
- Riesgos: payload inconsistente.
- Validaciones QA: Comparar pantalla, PDF y DB..

### 27.x Publicacion de campana WhatsApp

- Objetivo: Publicacion de campana WhatsApp.
- Actor principal: Negocio.
- Precondiciones: Productos activos con stock..
Pasos detallados:
1. Seleccionar productos.
2. Renderizar imagenes.
3. Abrir share sheet.
4. Confirmar publicacion.
5. Guardar estado.
6. Sincronizar.
- Datos que se guardan: campana y rutas renderizadas.
- Tablas involucradas: whatsapp_campaign_publications.
- Providers/repositorios/servicios: WhatsappCampaignRepository; WhatsappStatusCampaignService.
- Resultado esperado: Campana registrada..
- Riesgos: asumir publicacion automatica.
- Validaciones QA: Validar confirmacion/cancelacion..

### 27.x Sincronizacion automatica

- Objetivo: Sincronizacion automatica.
- Actor principal: Sistema.
- Precondiciones: Pendientes y condicion de red/token..
Pasos detallados:
1. Detectar evento.
2. Bloquear ejecucion duplicada.
3. Procesar modulos.
4. Push pendientes.
5. Pull cambios.
6. Actualizar estados.
7. Mostrar resultado amigable.
- Datos que se guardan: sync state, remote_id, last_synced_at.
- Tablas involucradas: sync_queue; sync_outbox; sync_state.
- Providers/repositorios/servicios: AutoSyncService; SyncEngine; Cloud*SyncService.
- Resultado esperado: Datos confirmados o error visible..
- Riesgos: duplicados o perdida por reintentos.
- Validaciones QA: Probar offline/online y backend caido..

### 27.x Inicio de sesion en segundo dispositivo

- Objetivo: Inicio de sesion en segundo dispositivo.
- Actor principal: Usuario.
- Precondiciones: Usuario cloud existente..
Pasos detallados:
1. Login en dispositivo B.
2. Backend actualiza dispositivo activo.
3. Dispositivo B recibe token nuevo.
4. Dispositivo A queda con token anterior.
- Datos que se guardan: sessionVersion/device.
- Tablas involucradas: Users; sesiones.
- Providers/repositorios/servicios: CloudAuthService; AuthService.
- Resultado esperado: Dispositivo B opera..
- Riesgos: dispositivo A sigue operando indebidamente.
- Validaciones QA: Probar request protegido desde A..

### 27.x Invalidacion de sesion anterior si aplica

- Objetivo: Invalidacion de sesion anterior si aplica.
- Actor principal: Backend/Sistema.
- Precondiciones: Sesion reemplazada..
Pasos detallados:
1. Dispositivo anterior llama endpoint protegido.
2. Middleware valida sesion.
3. Backend devuelve 401 SESSION_REPLACED.
4. App pide iniciar sesion nuevamente.
- Datos que se guardan: estado de sesion.
- Tablas involucradas: Users; sesiones.
- Providers/repositorios/servicios: Program.cs middleware; AuthService.
- Resultado esperado: Sesion anterior queda invalidada..
- Riesgos: mensaje confuso o datos locales sin sync.
- Validaciones QA: Validar pantalla y pendientes..

### 27.x Recuperacion luego de estar offline

- Objetivo: Recuperacion luego de estar offline.
- Actor principal: Sistema/Usuario.
- Precondiciones: Cambios locales pendientes..
Pasos detallados:
1. Usuario trabaja offline.
2. Cambios quedan pending.
3. Vuelve internet.
4. AutoSyncService corre.
5. Push confirma.
6. Pull actualiza.
- Datos que se guardan: pendientes confirmados.
- Tablas involucradas: sync_queue; sync_outbox.
- Providers/repositorios/servicios: AutoSyncService; Cloud*SyncService.
- Resultado esperado: Datos quedan confirmados en cloud..
- Riesgos: conflictos con otro dispositivo.
- Validaciones QA: Crear offline y validar pull..

### 27.x Reintento luego de error de backend

- Objetivo: Reintento luego de error de backend.
- Actor principal: Sistema.
- Precondiciones: Error previo registrado..
Pasos detallados:
1. Detectar last_error o failed.
2. Conservar payload.
3. Reintentar cuando backend responde.
4. Actualizar status si success.
5. Mantener error si falla.
- Datos que se guardan: attempts, last_error.
- Tablas involucradas: sync_queue; sync_state.
- Providers/repositorios/servicios: SyncDiagnosticsRepository; AutoSyncService.
- Resultado esperado: Error se resuelve o queda diagnosticable..
- Riesgos: bucle infinito o perdida de payload.
- Validaciones QA: Apagar backend, crear cambio, encender y reintentar..

## 28. Riesgos y puntos criticos

- Perdida de datos por sincronizacion incorrecta: nunca marcar como sincronizado algo que backend rechazo.
- Duplicados por negocio: validar siempre negocio_id/BusinessId en clientes y productos.
- Divergencia entre dispositivos: probar push/pull y restauracion inicial.
- Errores legacy persistentes: revisar sync_queue failed y last_error.
- Endpoints mal enrutados: cuidar /api/sync/inventory/images, /api/sync/inventory_images, /health y /api/health.
- Contratos JSON camelCase/snake_case: actualizar DTOs, mappers y tests juntos.
- Datos locales no confirmados en cloud: mostrar estado claro al usuario.
- Colaboradores con permisos indebidos: reforzar permisos en UI, repositorios y backend.
- Productos sin precio al crear deuda: validar precio_unitario antes de guardar.
- Migraciones SQLite incompletas: usar migraciones idempotentes y pruebas con DB vieja.
- Cuelgues de comandos Flutter/Dart: usar scripts con timeout y limpiar procesos si corresponde.
- Backend apagado o inaccesible: conservar datos locales y mostrar error amigable.
- Problemas de red local: BackendSettingsScreen debe ayudar a probar health/baseUrl.
- Sesion cloud invalida: detectar 401 y pedir login.
- Conflictos entre dispositivos: definir politica por entidad antes de sobrescribir datos sensibles.

## 29. Checklist QA completo

### 29.x Auth

| Caso | Pasos | Resultado esperado | Estado sugerido |
|---|---|---|---|
| Flujo principal de Auth | Ejecutar alta/consulta/edicion segun modulo y revisar UI. | Datos correctos y sin errores visibles. | Pendiente de ejecucion. |
| Sincronizacion de Auth | Crear cambio, forzar sync y revisar segundo dispositivo o backend. | Sin duplicados, con remote_id/status correcto. | Pendiente de ejecucion. |
| Permisos de Auth | Probar Personal, Negocio y Colaborador cuando aplique. | Cada rol ve solo lo permitido. | Pendiente de ejecucion. |
### 29.x Roles

| Caso | Pasos | Resultado esperado | Estado sugerido |
|---|---|---|---|
| Flujo principal de Roles | Ejecutar alta/consulta/edicion segun modulo y revisar UI. | Datos correctos y sin errores visibles. | Pendiente de ejecucion. |
| Sincronizacion de Roles | Crear cambio, forzar sync y revisar segundo dispositivo o backend. | Sin duplicados, con remote_id/status correcto. | Pendiente de ejecucion. |
| Permisos de Roles | Probar Personal, Negocio y Colaborador cuando aplique. | Cada rol ve solo lo permitido. | Pendiente de ejecucion. |
### 29.x Clientes

| Caso | Pasos | Resultado esperado | Estado sugerido |
|---|---|---|---|
| Flujo principal de Clientes | Ejecutar alta/consulta/edicion segun modulo y revisar UI. | Datos correctos y sin errores visibles. | Pendiente de ejecucion. |
| Sincronizacion de Clientes | Crear cambio, forzar sync y revisar segundo dispositivo o backend. | Sin duplicados, con remote_id/status correcto. | Pendiente de ejecucion. |
| Permisos de Clientes | Probar Personal, Negocio y Colaborador cuando aplique. | Cada rol ve solo lo permitido. | Pendiente de ejecucion. |
### 29.x Deudas

| Caso | Pasos | Resultado esperado | Estado sugerido |
|---|---|---|---|
| Flujo principal de Deudas | Ejecutar alta/consulta/edicion segun modulo y revisar UI. | Datos correctos y sin errores visibles. | Pendiente de ejecucion. |
| Sincronizacion de Deudas | Crear cambio, forzar sync y revisar segundo dispositivo o backend. | Sin duplicados, con remote_id/status correcto. | Pendiente de ejecucion. |
| Permisos de Deudas | Probar Personal, Negocio y Colaborador cuando aplique. | Cada rol ve solo lo permitido. | Pendiente de ejecucion. |
### 29.x Pagos

| Caso | Pasos | Resultado esperado | Estado sugerido |
|---|---|---|---|
| Flujo principal de Pagos | Ejecutar alta/consulta/edicion segun modulo y revisar UI. | Datos correctos y sin errores visibles. | Pendiente de ejecucion. |
| Sincronizacion de Pagos | Crear cambio, forzar sync y revisar segundo dispositivo o backend. | Sin duplicados, con remote_id/status correcto. | Pendiente de ejecucion. |
| Permisos de Pagos | Probar Personal, Negocio y Colaborador cuando aplique. | Cada rol ve solo lo permitido. | Pendiente de ejecucion. |
### 29.x Inventario

| Caso | Pasos | Resultado esperado | Estado sugerido |
|---|---|---|---|
| Flujo principal de Inventario | Ejecutar alta/consulta/edicion segun modulo y revisar UI. | Datos correctos y sin errores visibles. | Pendiente de ejecucion. |
| Sincronizacion de Inventario | Crear cambio, forzar sync y revisar segundo dispositivo o backend. | Sin duplicados, con remote_id/status correcto. | Pendiente de ejecucion. |
| Permisos de Inventario | Probar Personal, Negocio y Colaborador cuando aplique. | Cada rol ve solo lo permitido. | Pendiente de ejecucion. |
### 29.x Imagenes

| Caso | Pasos | Resultado esperado | Estado sugerido |
|---|---|---|---|
| Flujo principal de Imagenes | Ejecutar alta/consulta/edicion segun modulo y revisar UI. | Datos correctos y sin errores visibles. | Pendiente de ejecucion. |
| Sincronizacion de Imagenes | Crear cambio, forzar sync y revisar segundo dispositivo o backend. | Sin duplicados, con remote_id/status correcto. | Pendiente de ejecucion. |
| Permisos de Imagenes | Probar Personal, Negocio y Colaborador cuando aplique. | Cada rol ve solo lo permitido. | Pendiente de ejecucion. |
### 29.x Auditorias

| Caso | Pasos | Resultado esperado | Estado sugerido |
|---|---|---|---|
| Flujo principal de Auditorias | Ejecutar alta/consulta/edicion segun modulo y revisar UI. | Datos correctos y sin errores visibles. | Pendiente de ejecucion. |
| Sincronizacion de Auditorias | Crear cambio, forzar sync y revisar segundo dispositivo o backend. | Sin duplicados, con remote_id/status correcto. | Pendiente de ejecucion. |
| Permisos de Auditorias | Probar Personal, Negocio y Colaborador cuando aplique. | Cada rol ve solo lo permitido. | Pendiente de ejecucion. |
### 29.x Colaboradores

| Caso | Pasos | Resultado esperado | Estado sugerido |
|---|---|---|---|
| Flujo principal de Colaboradores | Ejecutar alta/consulta/edicion segun modulo y revisar UI. | Datos correctos y sin errores visibles. | Pendiente de ejecucion. |
| Sincronizacion de Colaboradores | Crear cambio, forzar sync y revisar segundo dispositivo o backend. | Sin duplicados, con remote_id/status correcto. | Pendiente de ejecucion. |
| Permisos de Colaboradores | Probar Personal, Negocio y Colaborador cuando aplique. | Cada rol ve solo lo permitido. | Pendiente de ejecucion. |
### 29.x Solicitudes

| Caso | Pasos | Resultado esperado | Estado sugerido |
|---|---|---|---|
| Flujo principal de Solicitudes | Ejecutar alta/consulta/edicion segun modulo y revisar UI. | Datos correctos y sin errores visibles. | Pendiente de ejecucion. |
| Sincronizacion de Solicitudes | Crear cambio, forzar sync y revisar segundo dispositivo o backend. | Sin duplicados, con remote_id/status correcto. | Pendiente de ejecucion. |
| Permisos de Solicitudes | Probar Personal, Negocio y Colaborador cuando aplique. | Cada rol ve solo lo permitido. | Pendiente de ejecucion. |
### 29.x Portal Personal

| Caso | Pasos | Resultado esperado | Estado sugerido |
|---|---|---|---|
| Flujo principal de Portal Personal | Ejecutar alta/consulta/edicion segun modulo y revisar UI. | Datos correctos y sin errores visibles. | Pendiente de ejecucion. |
| Sincronizacion de Portal Personal | Crear cambio, forzar sync y revisar segundo dispositivo o backend. | Sin duplicados, con remote_id/status correcto. | Pendiente de ejecucion. |
| Permisos de Portal Personal | Probar Personal, Negocio y Colaborador cuando aplique. | Cada rol ve solo lo permitido. | Pendiente de ejecucion. |
### 29.x Comprobantes

| Caso | Pasos | Resultado esperado | Estado sugerido |
|---|---|---|---|
| Flujo principal de Comprobantes | Ejecutar alta/consulta/edicion segun modulo y revisar UI. | Datos correctos y sin errores visibles. | Pendiente de ejecucion. |
| Sincronizacion de Comprobantes | Crear cambio, forzar sync y revisar segundo dispositivo o backend. | Sin duplicados, con remote_id/status correcto. | Pendiente de ejecucion. |
| Permisos de Comprobantes | Probar Personal, Negocio y Colaborador cuando aplique. | Cada rol ve solo lo permitido. | Pendiente de ejecucion. |
### 29.x Campanas WhatsApp

| Caso | Pasos | Resultado esperado | Estado sugerido |
|---|---|---|---|
| Flujo principal de Campanas WhatsApp | Ejecutar alta/consulta/edicion segun modulo y revisar UI. | Datos correctos y sin errores visibles. | Pendiente de ejecucion. |
| Sincronizacion de Campanas WhatsApp | Crear cambio, forzar sync y revisar segundo dispositivo o backend. | Sin duplicados, con remote_id/status correcto. | Pendiente de ejecucion. |
| Permisos de Campanas WhatsApp | Probar Personal, Negocio y Colaborador cuando aplique. | Cada rol ve solo lo permitido. | Pendiente de ejecucion. |
### 29.x Sync

| Caso | Pasos | Resultado esperado | Estado sugerido |
|---|---|---|---|
| Flujo principal de Sync | Ejecutar alta/consulta/edicion segun modulo y revisar UI. | Datos correctos y sin errores visibles. | Pendiente de ejecucion. |
| Sincronizacion de Sync | Crear cambio, forzar sync y revisar segundo dispositivo o backend. | Sin duplicados, con remote_id/status correcto. | Pendiente de ejecucion. |
| Permisos de Sync | Probar Personal, Negocio y Colaborador cuando aplique. | Cada rol ve solo lo permitido. | Pendiente de ejecucion. |
### 29.x Backend

| Caso | Pasos | Resultado esperado | Estado sugerido |
|---|---|---|---|
| Flujo principal de Backend | Ejecutar alta/consulta/edicion segun modulo y revisar UI. | Datos correctos y sin errores visibles. | Pendiente de ejecucion. |
| Sincronizacion de Backend | Crear cambio, forzar sync y revisar segundo dispositivo o backend. | Sin duplicados, con remote_id/status correcto. | Pendiente de ejecucion. |
| Permisos de Backend | Probar Personal, Negocio y Colaborador cuando aplique. | Cada rol ve solo lo permitido. | Pendiente de ejecucion. |
### 29.x SQLite

| Caso | Pasos | Resultado esperado | Estado sugerido |
|---|---|---|---|
| Flujo principal de SQLite | Ejecutar alta/consulta/edicion segun modulo y revisar UI. | Datos correctos y sin errores visibles. | Pendiente de ejecucion. |
| Sincronizacion de SQLite | Crear cambio, forzar sync y revisar segundo dispositivo o backend. | Sin duplicados, con remote_id/status correcto. | Pendiente de ejecucion. |
| Permisos de SQLite | Probar Personal, Negocio y Colaborador cuando aplique. | Cada rol ve solo lo permitido. | Pendiente de ejecucion. |
### 29.x Multi-dispositivo

| Caso | Pasos | Resultado esperado | Estado sugerido |
|---|---|---|---|
| Flujo principal de Multi-dispositivo | Ejecutar alta/consulta/edicion segun modulo y revisar UI. | Datos correctos y sin errores visibles. | Pendiente de ejecucion. |
| Sincronizacion de Multi-dispositivo | Crear cambio, forzar sync y revisar segundo dispositivo o backend. | Sin duplicados, con remote_id/status correcto. | Pendiente de ejecucion. |
| Permisos de Multi-dispositivo | Probar Personal, Negocio y Colaborador cuando aplique. | Cada rol ve solo lo permitido. | Pendiente de ejecucion. |
### 29.x Offline/online

| Caso | Pasos | Resultado esperado | Estado sugerido |
|---|---|---|---|
| Flujo principal de Offline/online | Ejecutar alta/consulta/edicion segun modulo y revisar UI. | Datos correctos y sin errores visibles. | Pendiente de ejecucion. |
| Sincronizacion de Offline/online | Crear cambio, forzar sync y revisar segundo dispositivo o backend. | Sin duplicados, con remote_id/status correcto. | Pendiente de ejecucion. |
| Permisos de Offline/online | Probar Personal, Negocio y Colaborador cuando aplique. | Cada rol ve solo lo permitido. | Pendiente de ejecucion. |
### 29.x Regresion general

| Caso | Pasos | Resultado esperado | Estado sugerido |
|---|---|---|---|
| Flujo principal de Regresion general | Ejecutar alta/consulta/edicion segun modulo y revisar UI. | Datos correctos y sin errores visibles. | Pendiente de ejecucion. |
| Sincronizacion de Regresion general | Crear cambio, forzar sync y revisar segundo dispositivo o backend. | Sin duplicados, con remote_id/status correcto. | Pendiente de ejecucion. |
| Permisos de Regresion general | Probar Personal, Negocio y Colaborador cuando aplique. | Cada rol ve solo lo permitido. | Pendiente de ejecucion. |
## 30. Glosario

- Auditoria: Proceso de validacion de stock fisico contra sistema.
- Colaborador: Usuario operativo asociado a un negocio.
- Comprobante: Recibo interno asociado a deuda o pago.
- Deuda item: Detalle de producto, cantidad y precio dentro de una deuda.
- Endpoint: Ruta HTTP expuesta por backend.
- Migracion: Cambio controlado de estructura de base de datos.
- Movimiento: Registro financiero de deuda o pago.
- negocio_id: Identificador local que separa datos de cada negocio.
- Offline-first: Modelo donde la app guarda y funciona primero localmente, y sincroniza despues.
- Personal: Usuario que consulta sus deudas propias.
- Provider: Pieza Riverpod que conecta UI con datos/servicios.
- Pull: Descarga de cambios backend hacia SQLite local.
- Push: Envio de cambios locales hacia backend.
- Repositorio: Clase que encapsula lectura/escritura en SQLite.
- Sync queue: Cola local de operaciones pendientes para enviar al backend.

## 31. Resumen tecnico final

- La app esta organizada por capas: core, data, domain, presentation/screens y backend.
- Los modulos criticos son auth, clientes, movimientos, deuda_items, productos, imagenes, auditorias, solicitudes, comprobantes y sync.
- Archivos a revisar primero: database_schema.dart, database_helper.dart, repositorios afectados, providers, Cloud*SyncService, Program.cs, FiadoDbContext.cs y controller correspondiente.
- Para entender el flujo de datos, seguir Pantalla -> Provider -> Repository -> SQLite -> cola -> servicio cloud -> backend -> pull.
- Evitar modificar sin pruebas: migraciones, negocio_id, contratos JSON, sync_status, remote_id, pagos, ciclos de credito, descuento de stock y permisos de colaborador.
- Recomendacion: cada cambio funcional debe tener prueba local, prueba offline/online y prueba multi-negocio cuando toque datos de negocio.

## 32. Resumen funcional final

Fiado App permite que un negocio registre clientes, cree fiados, reciba pagos, controle productos, haga auditorias, genere comprobantes y publique campanas manuales de WhatsApp. El usuario Personal puede revisar lo que debe sin acceder a informacion interna del negocio. El Colaborador ayuda a operar, pero sus permisos deben estar controlados por el negocio.

La informacion se protege separando datos por negocio_id y BusinessId. La app trabaja sin internet guardando datos en SQLite y luego intenta sincronizar. Cuando hay varios dispositivos, la nube permite que los cambios confirmados se reflejen en todos, siempre que la sincronizacion funcione correctamente.
