# Cloud Auth Auto Login QA

## Caso A - Backend Encendido

1. Encender backend.
2. Confirmar internet.
3. Iniciar sesion con credenciales validas.
4. Abrir `Sincronizacion`.

Resultado esperado:

- Login local OK.
- Login cloud OK.
- Token guardado en `flutter_secure_storage`.
- La pantalla muestra `Conectado a la nube`.
- `Sincronizar con la nube` funciona sin pegar token manual.

## Caso B - Backend Apagado

1. Apagar backend.
2. Iniciar sesion con usuario local valido.

Resultado esperado:

- Login local OK.
- No hay crash.
- La nube queda desconectada.
- Los datos se guardan localmente.

## Caso C - Usuario No Existe En Backend

1. Usar usuario local que aun no exista en backend.
2. Iniciar sesion.

Resultado esperado:

- Login local OK.
- La app indica que la nube se conectara cuando las credenciales esten activas.
- Sync muestra cuenta no conectada.

## Caso D - Token Expirado

1. Preparar token vencido.
2. Intentar sincronizar.

Resultado esperado:

- La app no crashea.
- Limpia token vencido.
- Pide iniciar sesion nuevamente con internet.

## Caso E - Logout

1. Iniciar sesion con nube conectada.
2. Cerrar sesion.

Resultado esperado: token cloud eliminado.

## Caso F - Session Timeout

1. Iniciar sesion con nube conectada.
2. Esperar cierre automatico por inactividad.

Resultado esperado: token cloud eliminado junto con sesion local.
