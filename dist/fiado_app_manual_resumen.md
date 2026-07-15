# Fiado App - Resumen del manual completo

Se genero el manual tecnico y funcional completo en `dist/fiado_app_manual_completo.csv`. El CSV documenta Fiado App de principio a fin: contexto general, arquitectura, roles, permisos, autenticacion, suscripciones, clientes, deudas, pagos, inventario, imagenes, auditorias, solicitudes de autorizacion, colaboradores, portal personal, comprobantes PDF, campanas WhatsApp, sincronizacion, backend ASP.NET Core, SQLite, SQL Server, migraciones, multi-negocio, riesgos y checklist QA.

## Alcance documentado

- Filas del CSV: 90 filas de contenido mas encabezado.
- Secciones: 37 secciones principales.
- Columnas: Seccion, Modulo, Submodulo, Tipo, Descripcion, Funcionamiento, Relaciones, Reglas_Logicas, Archivos_Relacionados, Tablas_Base_Datos, Providers_Servicios, Endpoints_Backend, Flujo_Proceso, Riesgos_Consideraciones, Estado_Actual, Notas_Tecnicas.
- Formato: CSV UTF-8 con BOM para apertura correcta en Excel.

## Secciones incluidas

- Archivos analizados
- Auditorias
- Autenticacion
- Backend ASP.NET Core
- Campanas de WhatsApp
- Checklist de validacion QA
- Clientes
- Colaboradores
- Comprobantes PDF
- Consideraciones futuras
- Contexto general
- Contratos y pruebas
- Detalle de articulos fiados
- Deudas
- Estados visibles de sincronizacion
- Flujos principales
- Imagenes de inventario
- Inventario
- Manejo offline-first
- Mapa general del sistema
- Migraciones
- Multi-negocio
- Pagos
- Portal Personal
- Procesos criticos
- Reportes e inteligencia
- Resumen ejecutivo
- Resumen tecnico
- Riesgos y puntos criticos
- Roles y permisos
- SQL Server/backend cloud
- SQLite local
- Sincronizacion automatica
- Solicitudes de autorizacion
- Suscripciones y planes
- Sync queue legacy
- Sync v2

## Modulos principales

- API
- Aislamiento
- Aprobaciones
- Arquitectura
- Auditoria diaria
- Auditoria funcional
- Auditoria semanal
- Auditorias
- Autenticacion por rol
- Auth
- Auth/Suscripcion
- AutoSyncService
- Backend
- Backend y migraciones
- Base de datos
- Business Copilot
- Campanas
- Campanas WhatsApp
- Centralizar permisos
- Ciclos de credito
- Client Score
- Clientes
- Cobranza inteligente
- Colaborador
- Colaboradores
- Colaboradores con permisos indebidos
- Comprobantes
- Contratos JSON camelCase/snake_case
- Creacion
- Cuelgues de comandos Flutter/Dart
- Datos locales sin confirmar en cloud
- Deuda con productos
- Deuda simple
- Deudas
- Deudas personales
- Deudas/Inventario
- Divergencia entre dispositivos
- Duplicados por negocio
- Edicion
- Eliminacion
- Errores legacy persistentes
- Estados
- Fallos por endpoints mal enrutados
- Fiado App
- Flujo de datos
- Frontend Flutter
- Gestion
- Gestion de clientes
- Inventario
- Inventario e imagenes
- JSON
- Login y registro
- Movimientos
- Negocio
- Objetivo del sistema
- Operacion sin conexion
- Pagos
- Perdida de datos por sincronizacion incorrecta
- Persistencia cloud
- Personal

## Archivos y areas analizadas

- ARCHITECTURE.md
- API_CONTRACTS.md
- README.md
- lib/core/database/database_schema.dart
- lib/core/database/database_helper.dart
- lib/presentation/providers/auth_providers.dart
- lib/presentation/providers/fiado_data_providers.dart
- lib/presentation/providers/sync_providers.dart
- lib/data/repositories/*.dart
- lib/data/services/*.dart
- lib/data/models/*.dart
- lib/screens/*.dart
- backend/src/FiadoApp.Api/Program.cs
- backend/src/FiadoApp.Api/Data/FiadoDbContext.cs
- backend/src/FiadoApp.Api/Controllers/*.cs
- backend/src/FiadoApp.Api/Services/*.cs
- backend/src/FiadoApp.Api/DTOs/*.cs
- backend/src/FiadoApp.Api/Migrations/*.cs
- test/*.dart
- test/regression/*.dart
- tools/qa/*.dart
- tools/scripts/*.ps1

## Riesgos importantes encontrados

- Perdida de datos por sincronizacion incorrecta
- Duplicados por negocio
- Divergencia entre dispositivos
- Errores legacy persistentes
- Fallos por endpoints mal enrutados
- Contratos JSON camelCase/snake_case
- Datos locales sin confirmar en cloud
- Colaboradores con permisos indebidos
- Productos sin precio al crear deuda
- Problemas de migraciones SQLite
- Cuelgues de comandos Flutter/Dart

## Como usar el CSV

Abra `dist/fiado_app_manual_completo.csv` en Excel o en un editor compatible con UTF-8. Use la columna `Seccion` para navegar por bloques grandes, `Modulo` y `Submodulo` para ubicar una funcionalidad concreta, y `Archivos_Relacionados`, `Tablas_Base_Datos`, `Providers_Servicios` y `Endpoints_Backend` para conectar la descripcion funcional con el codigo.

Las filas de `Mapa general del sistema` explican el viaje de datos desde la UI hasta SQLite, colas de sincronizacion, backend y retorno al dispositivo. Las filas de `Flujos principales`, `Riesgos y puntos criticos` y `Checklist de validacion QA` sirven como guia de operacion, mantenimiento y pruebas.

## Limitaciones

Este manual se genero mediante analisis estatico del repositorio y documentacion existente. No se ejecuto la app, el backend ni la suite de pruebas porque la tarea solicitaba no modificar logica funcional y crear solo documentacion en `dist`.
