# Fiado App - UI Design System

## Objetivo

Fiado App adopta una estetica SaaS moderna para pequenos negocios: clara,
ejecutiva, tactil y liviana. La referencia de mercado es la simpleza de apps
comerciales populares, pero la identidad visual es propia: cartera, credito,
inventario y confianza local.

## Paleta

- Verde principal: `#19A37B`, acciones positivas y marca viva.
- Verde oscuro: `#143C36`, confianza, headers ejecutivos y textos fuertes.
- Azul petroleo: `#183B56`, estabilidad y modulos financieros.
- Azul informativo: `#2F6F88`, estados neutrales y sincronizacion.
- Amarillo suave: `#F2B84B`, alertas y stock bajo.
- Rojo elegante: `#B42318`, riesgo, mora y bloqueos.
- Fondo SaaS claro: `#F5F7F4`, base general.
- Superficie: `#FFFFFF`, tarjetas y formularios.

La fuente central vive en `lib/core/theme/app_colors.dart`.

## Gradientes

- `AppGradients.executive`: verde oscuro a verde principal.
- `AppGradients.trust`: azul petroleo a azul informativo.
- `AppGradients.alert`: marron/amarillo para avisos.
- `AppGradients.risk`: rojo profundo para riesgo.
- `AppGradients.surfaceGlow`: tarjetas claras con brillo sutil.

## Sombras

- `AppShadows.card`: profundidad ligera para tarjetas.
- `AppShadows.elevated`: heroes y tarjetas destacadas.
- `AppShadows.pressed`: feedback de presion.

## Movimiento

Las animaciones usan Flutter nativo, sin paquetes pesados:

- `AppMotion.fast`: feedback de tap.
- `AppMotion.normal`: entrada fade/slide.
- `AppMotion.slow`: transiciones suaves.

Regla: animaciones sutiles, no permanentes ni costosas.

## Componentes

- `AnimatedDashboardCard`: entrada fade/slide y escala de presion.
- `ExecutiveKpiCard`: KPI con profundidad, icono y contador visual.
- `FiadoGradientCard`: hero/tarjeta ejecutiva con gradiente de marca.
- `FiadoActionTile`: accesos modernos en paneles/drawer.
- `FiadoEmptyState`: estados vacios profesionales.
- `FiadoLoadingState`: skeleton/loading liviano.
- `DashboardNewsCard`: feed de noticias por nivel.
- `AppNavigationDrawer`: menu lateral por rol.

## Reglas De Uso

- USD es precio principal en suscripciones; DOP solo aproximado.
- Riesgo usa rojo elegante, alertas usan amarillo, acciones exitosas usan verde.
- Evitar tarjetas saturadas: maximo una tarjeta hero fuerte por pantalla.
- Mantener contraste alto para textos.
- Usar grids responsive en dashboards.
- No cargar listas completas ni agregar animaciones por item en listas grandes.

## Diferencia Frente A Treinta

La inspiracion es general: simpleza, tarjetas modernas, navegacion clara y
sensacion amigable para pequenos negocios. Fiado App no copia marca, logo,
paleta exacta ni composicion. Su identidad gira alrededor de fiado, credito,
cartera, inventario y control ejecutivo offline-first.
