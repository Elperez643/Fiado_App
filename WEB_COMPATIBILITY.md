# Fiado App - Web Compatibility

## Estado Actual

Fiado App puede compilar para Web como objetivo de validacion visual, pero el
modo offline-first completo depende de SQLite mediante `sqflite`. Ese paquete
no provee una base local Web equivalente lista para este proyecto, por lo que
las pantallas que abren SQLite pueden fallar en runtime Web hasta migrar la
capa local.

## Paquetes Revisados

- `sqflite`: OK Android/iOS/macOS; Windows/Linux requieren
  `sqflite_common_ffi`; Web queda limitado.
- `sqflite_common_ffi`: agregado para Windows/Linux desktop.
- `image_picker`: incluye implementaciones Android/iOS/Web/Desktop.
- `pdf`: puro Dart, compatible para generar bytes.
- `printing`: soporta Web/Desktop con limitaciones propias del navegador/SO.
- `share_plus`: soporta plataformas principales; Web depende de Web Share API
  o fallback del navegador.
- `path_provider`: soporta Desktop; en Web no reemplaza SQLite.
- `http`: soporta Android/Desktop/Web.

## Limitacion Web

La app Web debe considerarse build exploratorio hasta decidir almacenamiento:

- Opcion 1: `sqflite_common_ffi_web`.
- Opcion 2: IndexedDB con una capa local especifica para Web.
- Opcion 3: modo backend-first para Web, manteniendo offline-first en mobile y
  desktop.

No se migra almacenamiento Web en esta fase para no romper Android/Windows ni
reescribir repositorios.

## Pruebas Recomendadas

- `flutter build web` debe compilar.
- Abrir `build/web` y validar pantallas estaticas/responsive.
- Evitar considerar Web productivo hasta resolver persistencia SQLite.
