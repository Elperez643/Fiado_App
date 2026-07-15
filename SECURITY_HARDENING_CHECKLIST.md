# Security Hardening Checklist

## Flutter

- JWT/manual token en secure storage.
- No imprimir tokens, Authorization headers ni secretos.
- Logout limpia sesion local y JWT.
- Session timeout activo para Personal, Negocio y Colaborador.
- BackendSettings muestra token parcial solamente.
- Pantallas sensibles validan rol/businessId.
- Imagenes optimizadas sin logs de rutas sensibles.
- No guardar CVV, numero de tarjeta ni tarjeta completa.

## Backend

- Endpoints sensibles con `[Authorize]`.
- Webhook Stripe anonimo solo con verificacion de firma.
- JWT con issuer/audience/lifetime/signing key.
- Secret JWT fuerte fuera de appsettings de produccion.
- PasswordHasher ASP.NET Core.
- No devolver password hash en DTOs.
- BusinessId desde JWT/usuario autenticado.
- Colaborador no aprueba/rechaza solicitudes.
- Personal sin acceso a endpoints internos de negocio.
- Exception handler generico en produccion.

## SQL Server

- EF Core parametrizado.
- Indices unicos por negocio donde aplica.
- Soft delete respetado.
- Queries filtradas por BusinessId.
- Connection strings sin password real en git.

## Stripe

- Usar solo claves `sk_test_` en modo test.
- WebhookSecret fuera de git.
- Validar firma Stripe.
- No guardar tarjeta completa, CVV ni numero.
- Registrar webhooks sin secretos.

## Hosting

- HTTPS obligatorio.
- CORS con dominios especificos.
- Swagger deshabilitado/protegido en produccion.
- Variables de entorno para secretos.
- Logs sin tokens ni payloads sensibles completos.

## Android/iOS

- Revisar permisos minimos.
- Camara/galeria con descripciones claras.
- No exponer archivos cache innecesarios.
- Probar timeout y background logout.

## Web

- CORS por dominio exacto.
- No usar token manual en storage inseguro.
- Revisar limitaciones SQLite/Web documentadas.
- Validar logout sin acceso via back browser.
