# Sync User Flow QA

## Caso A - Sin Internet

1. Desconectar internet.
2. Crear cliente, producto y deuda.
3. Abrir `Sincronizacion`.

Resultado esperado: la app guarda localmente y muestra `Pendiente de
sincronizar` o `Sin conexion`.

## Caso B - Vuelve Internet

1. Con datos pendientes, recuperar internet.
2. Esperar el debounce automatico.

Resultado esperado: Fiado App intenta sincronizar automaticamente.

## Caso C - Boton Unico

1. Abrir `Sincronizacion`.
2. Tocar `Sincronizar con la nube`.

Resultado esperado: se ejecuta la sincronizacion global y se muestra resultado
simple.

## Caso D - Backend Apagado

1. Apagar backend.
2. Tocar `Sincronizar con la nube`.

Resultado esperado: mensaje humano. Los datos locales quedan seguros.

## Caso E - Token Faltante

1. Usar una cuenta sin token cloud valido.
2. Tocar `Sincronizar con la nube`.

Resultado esperado: mensaje humano para iniciar sesion con cuenta conectada.

## Caso F - Error Parcial

1. Provocar fallo en un modulo de sync.
2. Ejecutar sincronizacion.

Resultado esperado: resumen simple y pendientes conservados.

## Caso G - Dashboard

1. Entrar al dashboard Negocio.
2. Revisar indicador de nube.

Resultado esperado: verde todo guardado, amarillo pendiente, gris sin conexion,
azul sincronizando.

## Caso H - Sin Terminos Tecnicos

1. Abrir pantalla normal de sincronizacion.

Resultado esperado: no aparecen JWT, baseUrl, endpoint, push, pull, payload ni
sync_queue.
