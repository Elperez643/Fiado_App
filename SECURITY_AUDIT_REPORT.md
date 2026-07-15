# Security Audit Report v1

Fecha: 2026-06-09

## Alcance

Auditoria de Flutter, SQLite, sync cloud, ASP.NET Core API, SQL Server, autenticacion, roles, pagos, Stripe TEST, almacenamiento local, archivos e imagenes.

## Hallazgos Criticos

- Token manual de backend almacenado en `SharedPreferences`.
  - Riesgo: `SharedPreferences` no es almacenamiento seguro para JWT o tokens manuales.
  - Correccion: agregado `flutter_secure_storage` y `SecureTokenStorage`. El token manual se migra automaticamente desde `SharedPreferences` a almacenamiento seguro y se elimina del storage legacy.

- Logout no limpiaba explicitamente `jwt_token` en SQLite.
  - Riesgo: aunque la sesion quedaba inactiva, el token permanecia en la fila historica.
  - Correccion: `cerrarSesionesActivas()` ahora marca `is_active = 0` y limpia `jwt_token`.

- JWT secret de backend tenia placeholder dev en configuracion.
  - Riesgo: ejecutar produccion con secreto de desarrollo.
  - Correccion: `Program.cs` falla al iniciar en produccion si `Jwt:Key` empieza con `dev-only` o mide menos de 32 caracteres.

## Sincronizacion UX Segura

- La pantalla normal de sincronizacion ya no muestra JWT, token completo,
  baseUrl, endpoint, payload, push, pull ni detalles internos de `sync_queue`.
- Los errores tecnicos se transforman en mensajes humanos para el usuario.
- La configuracion de nube y token parcial quedan en `Configuracion avanzada de
  nube`, pensada para debug/pruebas.
- Los tokens siguen en almacenamiento seguro mediante `SecureTokenStorage`.
- El login cloud automatico guarda el token en `flutter_secure_storage`.
- Logout y session timeout limpian el token cloud junto con la sesion local.

## Hallazgos Medios

- CORS no estaba configurado explicitamente.
  - Riesgo: politica no documentada/ambigua para Web.
  - Correccion: agregado policy `FiadoCors`. Desarrollo permite localhost/127.0.0.1; produccion requiere `Cors:AllowedOrigins`.

- Errores de produccion podian depender del comportamiento por defecto.
  - Riesgo: exponer detalles si la configuracion cambia.
  - Correccion: agregado `UseExceptionHandler` en no desarrollo con mensaje generico.

- Webhook Stripe devolvia mensajes de excepcion relacionados a firma/secret.
  - Riesgo: revelar detalles de validacion.
  - Correccion: sanitizacion de errores de webhook con mensaje generico para firma/secret.

## Hallazgos Bajos

- Datos legacy de clientes/productos/movimientos siguen reflejados temporalmente en `SharedPreferences`.
  - Riesgo: datos personales locales sin cifrado.
  - Estado: documentado. No se migra en esta fase para no romper compatibilidad offline existente.

- JWT de sesion local permanece en SQLite mientras la sesion esta activa.
  - Riesgo: SQLite no es secure storage.
  - Estado: mitigado parcialmente con timeout/logout y limpieza explicita. Recomendado migrar JWT de sesion a secure storage en una fase planificada.

- Swagger queda habilitado en Development.
  - Estado: correcto para desarrollo. En produccion no se habilita por `app.Environment.IsDevelopment()`.

## Correcciones Aplicadas

- Agregado `flutter_secure_storage`.
- Creado `lib/core/security/secure_token_storage.dart`.
- `ApiClient` usa secure storage para token manual.
- `BackendSettingsScreen` migra/limpia token manual desde secure storage.
- Logout local limpia `jwt_token`.
- Backend valida secreto JWT fuerte fuera de desarrollo.
- Backend agrega CORS explicito.
- Backend agrega exception handler generico en produccion.
- Webhook Stripe sanitiza errores de firma/secret.
- Documentacion de checklist de hardening creada.

## Pendientes Para Produccion

- Configurar `Jwt:Key` mediante environment variables o user-secrets; nunca usar valores dev.
- Configurar `Cors:AllowedOrigins` con dominios exactos de produccion.
- Revisar hosting para HTTPS obligatorio, HSTS y headers de seguridad.
- Mover JWT de sesion activa desde SQLite a secure storage en una migracion controlada.
- Cifrar o minimizar datos personales legacy en `SharedPreferences`.
- Proteger o deshabilitar Swagger en cualquier ambiente publico.
- Configurar Stripe TEST/produccion con secretos por environment variables.
- Revisar politicas de retencion de imagenes temporales/cache.

## Recomendaciones Antes De Publicar

- Ejecutar pruebas de rol directas por pantalla y endpoint.
- Validar que Personal no pueda llamar endpoints de negocio.
- Validar que Colaborador no apruebe solicitudes ni edite productos existentes sin autorizacion.
- Confirmar que sync push/pull filtra siempre por negocio autenticado.
- Ejecutar pruebas en dispositivo real Android con logout, timeout y background timeout.
- Validar CORS desde build Web contra dominio permitido.
# Aislamiento De Inventario

Los productos se consideran datos privados del negocio. La app filtra por
`negocio_id` en listados, imagenes, metricas, auditorias, fiados, campanas
WhatsApp y sincronizacion cloud. El backend toma `BusinessId` desde el JWT y no
desde requests publicos para productos.
