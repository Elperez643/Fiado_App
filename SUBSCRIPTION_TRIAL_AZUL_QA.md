# Subscription Trial Azul QA

## Flujo esperado

1. Registro Negocio con internet.
2. Seleccion de plan.
3. Crear sesion de token Azul.
4. Confirmar tarjeta sandbox 4242 o token real Azul.
5. Activar trial.
6. Guardar sesion local y estado `trial_active`.
7. Android/Windows operan offline-first.
8. Web queda cloud-first.

## Pruebas obligatorias

| ID | Prueba | Resultado esperado |
| --- | --- | --- |
| A | Registro Negocio sin internet | Bloqueado con mensaje claro |
| B | Registro con internet sin tarjeta | `payment_method_required` |
| C | Agregar tarjeta Azul sandbox | Token guardado, last4 `4242` |
| D | Activar trial | `trial_active`, `offlineAllowed=true` |
| E | Segundo trial | Bloqueado |
| F | Fin trial pago OK | Renovacion cambia a `active` |
| G | Fin trial pago falla | Cambia a `past_due` |
| H | Android sin internet con trial activo | Permite cliente/producto/fiado/pago/comprobante |
| I | Web sin backend | Mensaje claro, sin spinner infinito |
| J | Web con backend | Login/registro cloud |

## Pendiente credenciales Azul

La integracion real queda pendiente hasta recibir contrato API, credenciales sandbox oficiales y formato de webhook Azul. Mientras tanto, `AzulSandboxMock` valida arquitectura y reglas de negocio sin simular produccion.

