# WhatsApp Campaigns

Fiado App genera imagenes finales para Estados de WhatsApp. La informacion
principal no se envia como texto separado: queda renderizada dentro de cada
imagen.

## Render

- Tamano optimizado: `720 x 1280 px`.
- Formato vertical para estados.
- La imagen fuente del producto ya se guarda optimizada desde Inventario a
  `500 x 500 px`, maximo 300 KB. El render de estados usa esa imagen
  optimizada, no el archivo original.
- La imagen del producto se redimensiona con recorte centrado tipo
  `BoxFit.cover`, sin deformar.
- Si no hay imagen, se genera un flyer simple con fondo de color.
- Cada render se procesa de forma secuencial, una imagen a la vez.
- La salida se guarda en cache temporal y se reutiliza si el producto, texto e
  imagen base no cambian.

## Franja Inferior

La franja inferior ocupa cerca del 21% del alto. Usa verde/azul oscuro con
opacidad alta para asegurar contraste. Incluye:

- Texto del producto.
- Precio de venta si existe.
- Estado `Disponible hoy`.
- Nombre del negocio o texto `Fiado App`.

## Texto

- El campo de estado es obligatorio.
- Maximo: 30 caracteres.
- Se valida en UI y en `WhatsappStatusImageRenderer.validateStatusText`.
- Si no cumple, no se permite generar preview ni publicar.

## Modos

- Modo Individual: cada producto cuenta como una publicacion independiente.
- Modo Catalogo: varios productos forman parte de una publicacion del dia.

## Limites Por Plan

- Basico: 1 publicacion diaria, maximo 15 productos.
- Crecimiento: 3 publicaciones diarias, maximo 15 productos por publicacion.
- Empresarial: 5 publicaciones diarias, maximo 20 productos por publicacion.

El conteo diario se guarda localmente por negocio y fecha.

## Estados Y Anti-Abuso

Estados soportados:

- `pendiente`
- `enviado_a_whatsapp`
- `confirmado_por_usuario`
- `cancelado_por_usuario`
- `expirado_estimado`
- `fallido_antes_de_abrir_whatsapp`

El cupo diario se consume desde que Fiado App abre el menu de compartir con la
publicacion preparada. Cuentan para el limite:

- `enviado_a_whatsapp`
- `confirmado_por_usuario`
- `cancelado_por_usuario`

No cuentan:

- `pendiente`
- `fallido_antes_de_abrir_whatsapp`

Si el usuario vuelve y marca `No publique`, la publicacion cambia a
`cancelado_por_usuario`, pero el cupo se mantiene consumido porque WhatsApp o el
menu de compartir ya fue abierto correctamente.

## Reintento Inteligente

El usuario puede reintentar la misma publicacion del mismo dia sin consumir cupo
extra cuando se mantiene el mismo `campaign_publication_id` y los mismos
`renderedImagePaths`. Si cambia productos, imagenes o texto, se crea una nueva
publicacion y consume otro cupo disponible.

## Contenido Dinamico

La campana guarda seleccion y texto en pantalla, pero antes de publicar vuelve a
consultar inventario local:

- Si el producto fue modificado, se renderiza con datos actuales.
- Si el producto esta agotado o ya no aparece activo, se excluye.
- Si el precio cambio, se usa el precio actual.
- Si la imagen cambio, se vuelve a resolver la imagen actual.
- Inventario Inteligente v1 no modifica campanas directamente, pero ayuda al
  negocio a detectar agotados, criticos y reposicion antes de publicar.

## Confirmacion

Despues de abrir WhatsApp, Fiado App registra estado operativo
`enviado_a_whatsapp`. Al volver, pregunta si el usuario confirma la publicacion.
Si confirma, se marca `confirmado_por_usuario` y se muestra vigencia estimada de
24 horas.

WhatsApp no confirma esta informacion directamente a Fiado App.
