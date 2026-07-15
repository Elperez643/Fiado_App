# Personal Debt Guidance QA

## Acceso

- Iniciar sesion como usuario Personal.
- Confirmar que el menu lateral muestra `Recordatorios de pago`.
- Confirmar que el dashboard muestra una tarjeta pequena si hay recordatorios.
- Confirmar que no aparece modal intrusivo ni notificacion automatica.

## Casos Por Estado

- Cliente sin vencimiento cercano: debe mostrarse como `Al dia` o baja prioridad.
- Cliente por vencer: debe mostrar fecha limite cercana y prioridad media/alta.
- Cliente vencido 30: debe mostrar recomendacion de revisar o abonar.
- Cliente en mora 45: debe subir prioridad y mantener lenguaje suave.
- Cliente bloqueado 60: debe marcar prioridad critica sin usar lenguaje agresivo.

## Multi-Negocio

- Crear deudas para el mismo telefono en dos negocios.
- Confirmar que cada negocio aparece separado.
- Confirmar que el resumen total suma ambos negocios.
- Confirmar que el detalle solo muestra movimientos/comprobantes del negocio
  seleccionado.

## Privacidad

- Crear otro usuario Personal con telefono distinto.
- Confirmar que no ve deudas del primer telefono.
- Confirmar que no ve inventario, clientes internos, reportes ni score completo
  del negocio.

## Detalle

- Abrir `Ver detalle`.
- Confirmar monto pendiente, recomendacion, pasos sugeridos, movimientos y
  comprobantes propios.
- Confirmar que si no hay comprobantes, se muestra estado vacio amigable.

## Rendimiento

- Probar con muchos movimientos del mismo telefono.
- Confirmar que la pantalla abre rapido y el detalle pagina/limita historial
  reciente.
