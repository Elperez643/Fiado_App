# Web Cloud First QA

| Caso | Resultado esperado |
| --- | --- |
| Web abre app | Splash navega a Login |
| Web sin backend | Muestra `Fiado App Web requiere conexion a internet.` |
| Web login con backend | Usa `/api/auth/login` |
| Web registro Negocio | Requiere backend, tarjeta y trial activo |
| Modulo no soportado en Web | Muestra fallback claro |
| Error backend | No queda spinner infinito |

Web no usa SQLite offline como fuente principal para negocio.

