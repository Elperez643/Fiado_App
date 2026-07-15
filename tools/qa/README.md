# QA Stress Tools

Estos scripts generan datos artificiales para medir carga sin mezclar datos reales.

## SQLite local

Generar base QA:

```bash
dart run tools/qa/generate_stress_sqlite_data.dart --clients=1000 --products=500 --movements=3000 --debt-items=3000 --audits=50 --reset
```

Medir consultas:

```bash
dart run tools/qa/benchmark_sqlite_queries.dart --db=qa_data/fiado_stress_test.db
```

La ruta por defecto contiene `qa` y el script rechaza rutas no seguras salvo que se use `--allow-real-db` deliberadamente.

## SQL Server local

Abrir `tools/qa/generate_stress_sql_server.sql` en SSMS o Azure Data Studio contra una base desechable. El script usa `ROLLBACK` por defecto; cambiar a `COMMIT` solo si el destino es una DB QA.
