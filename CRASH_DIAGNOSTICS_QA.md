# Crash Diagnostics QA

## Objetivo

Validar que Fiado App no quede en pantalla roja o blanca ante errores de ciclo
de vida, dialogs, providers o navegacion.

## Pruebas manuales

- Abrir y cerrar rapidamente el dialogo de agregar deuda.
- Crear deuda con articulos y cancelar antes de guardar.
- Crear producto sin imagen.
- Crear producto con imagen y cerrar el dialogo durante la seleccion.
- Abrir sincronizacion y volver atras.
- Abrir inventario inteligente y volver con boton visual.
- Abrir Business Copilot y Cobranza Inteligente.
- Abrir recordatorios personales.
- Abrir campanas WhatsApp y cancelar preview/publicacion.
- Cerrar sesion desde pantallas internas.
- Dejar vencer session timeout dentro de un dialog.

## Resultado esperado

- No aparece assertion `_dependents.isEmpty`.
- No se usa `context` despues de desmontar la pantalla.
- Los formularios complejos disponen sus controllers.
- En release se muestra mensaje amigable si una pantalla falla.
- El ultimo crash queda registrado en log local sin token ni clave.
