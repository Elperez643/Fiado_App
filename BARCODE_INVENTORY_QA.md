# Barcode Inventory QA

Checklist manual para validar imagenes visibles en inventario y lector de
codigos de barras en creacion/edicion de productos.

## Creacion Manual

- Crear producto manual sin escanear codigo.
- Escribir codigo de referencia manualmente.
- Escribir ubicacion manualmente.
- Confirmar que se guarda y aparece en inventario.

## Codigo De Producto

- Crear producto escaneando codigo de barras.
- Confirmar que el valor escaneado llena `codigo_referencia`.
- Editar nombre, descripcion, categoria, costo, margen o precio antes de
  guardar.
- Guardar y confirmar que se conserva lo escrito finalmente por el usuario.
- Escanear un codigo existente del mismo negocio.
- Confirmar aviso: `Ya existe un producto con este codigo en tu inventario.`
- Intentar guardar duplicado.
- Confirmar que aparece la validacion de duplicado del repositorio.

## Ubicacion

- Escanear ubicacion `estante-A3`.
- Confirmar que llena el campo Ubicacion.
- Editar ubicacion manualmente antes de guardar.
- Enfocar ubicacion vacia y escribir manualmente.
- Confirmar que no copia automaticamente el codigo del producto.

## Imagenes En Inventario

- Crear producto sin imagen.
- Confirmar que la tarjeta muestra placeholder moderno con icono de producto.
- Crear producto con 1 imagen.
- Confirmar que la tarjeta muestra la imagen cuadrada con bordes redondeados.
- Crear producto con 3 imagenes.
- Confirmar que la tarjeta usa la primera imagen por `orden ASC`.
- Confirmar que refresh mantiene la imagen.

## Colaborador

- Como Colaborador con permiso, crear producto nuevo con codigo y ubicacion.
- Como Colaborador intentar editar codigo o ubicacion de producto existente.
- Confirmar que se genera solicitud de autorizacion para Negocio.
- Aprobar solicitud como Negocio y confirmar que el producto queda actualizado.

## Plataformas

- Android/iOS/macOS/Web compatibles con scanner si hay camara disponible.
- Windows/Linux muestran `Escaneo no disponible en esta plataforma.`
- Creacion manual sigue disponible aunque el scanner no este disponible.
