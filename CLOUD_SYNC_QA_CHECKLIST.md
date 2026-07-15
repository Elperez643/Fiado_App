# Fiado App - Cloud Sync QA Checklist

## Orden Oficial

1. Auth/JWT: obtener token valido de negocio o colaborador.
2. Clientes.
3. Productos.
4. Imagenes de productos: metadata, no binarios.
5. Movimientos/deudas y `deuda_items`.
6. Comprobantes.
7. Ciclos de credito, recordatorios y excepciones.
8. Auditorias y `audit_items`.
9. Solicitudes de autorizacion.
10. Score inteligente de clientes.

El boton `Sincronizar todo con backend` ejecuta el orden funcional dependiente:
clientes, productos, imagenes, movimientos/deuda_items, comprobantes, ciclos de
credito, score inteligente, auditorias/audit_items y solicitudes. Si un paso
falla, no borra datos locales; conserva `sync_queue.last_error`, incrementa
`attempts` en los items procesados por cada servicio y omite solo pasos que
dependen directamente del paso fallido.

## Prueba Base

- Backend compila con `dotnet build backend/FiadoApp.Backend.sln`.
- API inicia con `dotnet run --project backend/src/FiadoApp.Api/FiadoApp.Api.csproj`.
- `GET /health` responde `Healthy`.
- Swagger abre en `/swagger` cuando `ASPNETCORE_ENVIRONMENT=Development`.
- En esta maquina, los endpoints que tocan SQL Server deben correrse con la API
  en contexto elevado o con SQL Auth local configurado. Si la API corre en CMD
  normal, `GET /health` y Swagger responden, pero operaciones DB pueden fallar
  con `Cannot generate SSPI context`.
- Flutter ejecuta `flutter pub get`, `dart format .`, `flutter analyze` y
  `flutter build apk --debug`.

## Configuracion Multiplataforma De Backend

- Android emulador:
  - Entorno: `Android emulador`.
  - Base URL esperada: `http://10.0.2.2:5193/api`.
  - Prueba: abrir Backend, tocar `Probar conexion`, esperar
    `Conexion exitosa`.
- Android fisico:
  - Entorno: `Android fisico`.
  - Cambiar `TU_IP_LOCAL` por la IP LAN de la computadora, por ejemplo
    `http://192.168.1.20:5193/api`.
  - El telefono y la computadora deben estar en la misma red.
  - El firewall debe permitir el puerto `5193`.
- Windows Desktop:
  - Entorno: `Desktop local`.
  - Base URL: `http://127.0.0.1:5193/api`.
  - Prueba: backend corriendo en la misma PC y `/health` OK.
- Web local:
  - Entorno: `Web local`.
  - Base URL: `http://localhost:5193/api`.
  - Validar CORS si el navegador bloquea llamadas futuras.
- Cambio de baseUrl:
  - Cambiar entorno a Android fisico o Desktop local.
  - Escribir baseUrl manual.
  - Guardar y probar conexion.
  - Resultado esperado: se conserva localmente y `ApiClient` la usa en sync.
- Token invalido:
  - Configurar un JWT invalido o vencido.
  - Ejecutar sync.
  - Resultado esperado: error claro `401` o mensaje de token invalido, sin
    borrar datos locales.
- Backend apagado:
  - Detener API.
  - Tocar `Probar conexion`.
  - Resultado esperado: error claro conectando a `/health`.

## Auth/JWT

- Registrar o iniciar sesion como `Negocio`.
- Registrar o iniciar sesion como `Colaborador` asociado al negocio.
- Confirmar que la app guarda el JWT local o permite pegarlo en
  `Configurar backend/token`.
- Resultado esperado: endpoints protegidos responden 200 con Bearer valido y
  401/403 sin token o rol incorrecto.

## Score Inteligente

- Calcular score local desde movimientos/ciclos.
- Confirmar fila en `client_scores`.
- Confirmar item en `sync_queue` con `entity_type=client_scores`.
- Ejecutar `POST /api/client-scores/sync/push`.
- Confirmar en SQL Server:
  - `BusinessId` del JWT.
  - `ClientId` del mismo negocio.
  - `Score`.
  - `RiskLevel`.
  - `SuggestedCreditLimit`.
- Ejecutar `POST /api/client-scores/sync/pull`.
- Crear segundo negocio y confirmar que no recibe scores del primero.

Resultado live 2026-05-30:

- Negocio: `QA Score Live 0530165948921`.
- Cliente: `Cliente Score Live 0530165948921`.
- Score enviado/recibido: `88`.
- Riesgo: `Bajo riesgo`.
- Limite sugerido: `1500.00`.
- SQL Server: registro `24a3b55c-4d47-4b1d-9dc1-eb4cfa2e3601` confirmado.
- Aislamiento multi-negocio: OK, segundo negocio recibio 0 scores.

## Clientes

- Crear cliente offline.
- Confirmar item en `sync_queue` con `entity_type=clientes`.
- Ejecutar sync de clientes.
- Resultado esperado: `clientes.remote_id` queda poblado, `sync_status=synced`,
  `sync_queue.status=synced`, `attempts` incrementado y `last_error` limpio.
- Pull incremental no duplica por telefono dentro del mismo `negocio_id`.

## Productos

- Crear producto offline con nombre y codigo opcional.
- Ejecutar sync de productos despues de clientes.
- Resultado esperado: `productos.remote_id` poblado y sin duplicados por
  nombre/codigo dentro del mismo negocio activo.
- Pull respeta `activo/deleted_at` y `negocio_id`.

## Imagenes Metadata

- Crear metadata de imagen asociada a producto con `remote_id`.
- Ejecutar sync de imagenes despues de productos.
- Resultado esperado: no sube binarios, conserva `local_path`, sincroniza
  `remote_url/storage_key` si existen y respeta maximo 3 imagenes desde backend.
- Si el producto no tiene `remote_id`, el item queda fallido con `last_error`
  claro.

## Movimientos/Deudas/Pagos

- Crear deuda o pago para cliente sincronizado.
- Ejecutar sync de movimientos despues de clientes.
- Resultado esperado: movimiento obtiene `remote_id`, mantiene `negocio_id`,
  y pull no pisa datos locales mas recientes.
- Si falta cliente remoto, el item queda fallido sin borrar datos locales.

## DeudaItems

- Crear deuda con productos sincronizados.
- Ejecutar sync de movimientos/deuda_items.
- Resultado esperado: `deuda_items.remote_id` poblado, referencia movimiento y
  producto remotos, y respeta `deleted_at`.
- Si falta movimiento remoto, queda `last_error` claro.

## Comprobantes

- Crear comprobante para movimiento sincronizado.
- Ejecutar sync de comprobantes despues de movimientos.
- Resultado esperado: `comprobantes.remote_id` poblado y codigo unico.
- Si falta movimiento o cliente remoto, queda fallido sin borrar PDF/payload
  local.

## Ciclos De Credito

- Crear deuda que genere ciclo 30/45/60.
- Ejecutar sync de ciclos despues de movimientos.
- Resultado esperado: backend persiste estado calculado por Flutter, pull trae
  ciclos, recordatorios y excepciones con `negocio_id` correcto.
- No se recalcula la logica 30/45/60 en backend todavia.

## Auditorias

- Crear auditoria y validar items.
- Ejecutar sync de auditorias despues de productos.
- Resultado esperado: `auditorias.remote_id` y `auditoria_items.remote_id`
  poblados; items resuelven auditoria/producto remotos.
- Colaborador solo ve sus auditorias; negocio ve auditorias del negocio.

## Solicitudes De Autorizacion

- Crear solicitud como colaborador.
- Ejecutar sync de solicitudes.
- Resultado esperado: solicitud obtiene `remote_id`; negocio puede verla en
  pendientes y aprobar/rechazar desde backend/app.
- Si el colaborador no tiene `remote_id` pero el JWT es de colaborador, backend
  resuelve `CollaboratorId` desde el token.

## Resultado QA Actual

- Checklist creado.
- Boton global agregado en `SyncStatusScreen`.
- Orden global validado por revision de servicios y dependencias.
- Backend build: limpio.
- Backend run controlado: `GET /health` respondio `200 Healthy` y Swagger
  respondio `200`.
- Prueba E2E base Auth + Clientes:
  - `POST /api/auth/register/business` genero JWT.
  - `POST /api/clients/sync/push` respondio `created` y devolvio `serverId`.
  - `POST /api/clients/sync/pull` devolvio 1 cliente.
- Hallazgo corregido/documentado: el proceso normal de backend puede fallar SQL
  por SSPI; ejecutar elevado o configurar SQL Auth local segun `backend/DB_SETUP.md`.
- Flutter:
  - `flutter pub get`: OK.
  - `dart format .`: OK, 0 cambios.
  - `flutter analyze`: OK.
  - `flutter build apk --debug`: OK.
