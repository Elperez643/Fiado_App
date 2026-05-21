# Fiado App Architecture

Esta reestructuracion prepara la app para crecer sin romper el flujo actual.
La migracion es gradual: las pantallas antiguas siguen funcionando y las capas
nuevas actuan como adaptadores hasta reemplazar `SharedPreferences` por SQLite.

## Capas

- `lib/core`: configuracion transversal, tema, constantes, utilidades,
  contratos de base local y estructuras de sincronizacion.
- `lib/domain`: entidades puras y contratos de repositorios. No depende de
  Flutter ni de almacenamiento.
- `lib/data`: datasources, mappers, repositorios y servicios de sync. Hoy
  adapta el almacenamiento actual; manana puede apuntar a SQLite y API REST.
- `lib/presentation`: pantallas, widgets, providers y responsive. Por ahora
  exporta las pantallas legacy para mantener compatibilidad.

## Estrategia Offline-First

1. Toda escritura debe guardarse primero localmente.
2. Cada escritura local futura debe registrar una operacion en `sync_queue`.
3. Un servicio de sincronizacion enviara pendientes a ASP.NET Core cuando haya
   conexion.
4. La API debe devolver cambios incrementales para reconciliar SQL Server con
   la base local.

## Migracion Recomendada

1. Introducir SQLite implementando `LocalDatabase`.
2. Reemplazar datasources `SharedPreferences*` por datasources SQLite.
3. Mover pantallas grandes a subcomponentes en `presentation/widgets`.
4. Conectar repositorios a providers reales para dejar de cargar listas
   completas en memoria.
5. Implementar paginacion y busqueda indexada antes de llegar a alto volumen.
