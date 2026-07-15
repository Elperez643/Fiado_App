# Offline First Final QA

| Caso | Resultado esperado |
| --- | --- |
| Android sin internet, sin sesion | Abre Login |
| Registro Negocio sin internet | Muestra que necesita internet |
| Android con trial activo luego sin internet | Dashboard funciona con SQLite |
| Crear cliente/producto/fiado offline | Se guarda local y sync queda pendiente |
| Vuelve internet | Sync automatica corre si token y subscription estan validos |
| Suscripcion vencida sin validar | Gracia local de 72 horas |
| Fuera de gracia | No borra datos; restringe creacion segun reglas |
| Splash | No depende del backend para sesion local |

Aviso esperado cuando no se puede validar:

`No pudimos validar tu suscripcion. Fiado App seguira funcionando temporalmente.`

