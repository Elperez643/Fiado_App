# Auth Startup Recovery QA

## Casos

- [ ] Instalacion limpia Android: abre `LoginScreen`, no error de arranque.
- [ ] DB sin usuarios: abre `LoginScreen`.
- [ ] Usuario existe en backend pero no local: login cloud crea/vincula usuario local y entra.
- [ ] Backend apagado y usuario local existe: login local entra.
- [ ] Backend apagado y usuario local no existe: muestra error claro.
- [ ] Web: abre `LoginScreen`, no spinner infinito.
- [ ] Web con backend disponible: login cloud responde y crea sesion en memoria.
- [ ] Token corrupto/vencido: se limpia token y permite login.
- [ ] Pantalla de error de arranque: `Cerrar sesion` navega a login.
- [ ] Pantalla de error de arranque: `Restablecer nube` limpia configuracion cloud y permite reintentar.

## Resultado Esperado

El splash nunca queda indefinido. El login tiene timeout y siempre detiene el estado de carga con un mensaje humano.
