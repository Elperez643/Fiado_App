# Sync UX Simplification

Fiado App mantiene sincronizacion offline-first: todo se guarda primero en el
dispositivo y luego se sincroniza con la nube cuando hay internet.

## Pantalla Normal

La pantalla `Sincronizacion` muestra solo informacion entendible para el
comerciante:

- Todo sincronizado.
- Pendiente de sincronizar.
- Sin conexion.
- Sincronizando...
- Error al sincronizar.

El boton principal es `Sincronizar con la nube`.

No se muestran JWT, token, baseUrl, endpoint, payload, push, pull ni nombres de
colas internas.

## Sincronizacion Automatica

`AutoSyncService` intenta sincronizar automaticamente:

- Al entrar al dashboard despues del login.
- Despues de login cloud automatico exitoso.
- Cuando vuelve internet.
- Cuando la app vuelve a primer plano.
- Despues de un debounce de 15 segundos para evitar saturar la API.

El servicio usa un lock interno para no correr dos sincronizaciones al mismo
tiempo.

## Autenticacion Cloud Automatica

Despues de un login local exitoso, Fiado App intenta `POST /auth/login` con el
telefono y password ingresados. Si la nube responde correctamente, el token se
guarda en `flutter_secure_storage` y `ApiClient` lo usa automaticamente.

Si el backend esta apagado, no hay internet o el usuario aun no existe en la
nube, el login local no se bloquea. La pantalla de sincronizacion muestra un
mensaje humano y los datos siguen guardandose localmente.

## Boton Unico

El boton `Sincronizar con la nube` ejecuta la sincronizacion global en orden:

1. Clientes.
2. Productos.
3. Imagenes metadata.
4. Deudas, pagos y articulos.
5. Comprobantes.
6. Ciclos de credito.
7. Score inteligente.
8. Auditorias.
9. Solicitudes.

Si una parte falla, Fiado App mantiene los pendientes y muestra un mensaje
humano.

## Modo Avanzado

`SyncAdvancedSettingsScreen` conserva herramientas tecnicas para pruebas:

- URL de nube.
- Token parcial.
- Probar conexion.
- Resultados tecnicos por modulo.

Este acceso queda oculto en el flujo normal y disponible solo en debug o desde
configuracion avanzada.
