# Login White Screen QA

## Objetivo

Validar que el flujo login -> sesion -> onboarding/dashboard no quede en blanco
para ningun rol.

## Casos Negocio

- Login Negocio nuevo: debe abrir Onboarding v2 si no fue visto.
- Login Negocio existente con onboarding completado: debe abrir Dashboard
  Ejecutivo.
- Login Negocio con onboarding omitido: debe abrir Dashboard Ejecutivo.
- Negocio sin datos: dashboard debe mostrar ceros/estados vacios, no pantalla
  blanca.
- Negocio con providers de inteligencia sin datos: dashboard debe cargar.

## Casos Personal

- Login Personal nuevo: debe abrir Onboarding v2 si no fue visto.
- Login Personal existente: debe abrir Dashboard Personal.
- Recordatorios vacios: debe mostrar estado estable.

## Casos Colaborador

- Login Colaborador nuevo: debe abrir Onboarding v2 si no fue visto.
- Login Colaborador existente: debe abrir Dashboard Colaborador.
- Colaborador sin `negocio_id`: debe mostrar error/permiso, no pantalla blanca.

## Errores y Recuperacion

- Credenciales incorrectas: mostrar SnackBar.
- Error leyendo `user_onboarding`: navegar al dashboard correspondiente.
- Error cargando Dashboard Ejecutivo: mostrar
  `No pudimos cargar esta pantalla` con botones `Reintentar` y `Cerrar sesion`.
- Logout y login otra vez: no debe quedar pantalla blanca.
- Session timeout y login otra vez: no debe reaparecer pantalla blanca.
- Backend token vacio: no debe afectar login local.

## Logs Debug Esperados

Los logs no incluyen contrasena ni token. Deben mostrar:

- login iniciado.
- login exitoso.
- rol detectado.
- user id.
- negocio id.
- onboarding requerido si/no.
- destino de navegacion.
- error post-login si ocurre.
