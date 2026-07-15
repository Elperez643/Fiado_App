# Business Copilot QA

## Pruebas

- Cliente bloqueado genera recomendacion critica de cobranza/credito.
- Cliente score bajo genera recomendacion de credito.
- Producto agotado genera recomendacion de inventario.
- Producto sin movimiento con stock alto y ganancia potencial genera promocion sugerida.
- Producto promocionable abre accion de campana WhatsApp.
- Auditoria pendiente genera recomendacion de auditoria.
- Solicitud pendiente genera recomendacion de autorizacion.
- Trial proximo a vencer genera recomendacion de suscripcion.
- Cache: abrir la pantalla dos veces no debe recalcular todo si el cache sigue vigente.
- Recalcular: boton refresh debe regenerar recomendaciones.
- Dismiss: descartar recomendacion debe ocultarla.
- Multi-negocio: recomendaciones siempre filtran por `businessId`.

## Resultado Esperado

- Dashboard muestra bloque "Fiado App recomienda" con top 3.
- Menu lateral Negocio incluye Business Copilot.
- Pantalla Business Copilot muestra resumen y tabs.
- Las recomendaciones aparecen ordenadas por score descendente.
- `flutter analyze` debe quedar limpio.
