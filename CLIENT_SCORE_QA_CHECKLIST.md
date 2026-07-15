# Client Score QA Checklist

## Alcance

Validar el Motor Inteligente v1 sin cambiar reglas de negocio: calculo local
offline-first, persistencia SQLite, `sync_queue`, reportes y sincronizacion
cloud inicial contra ASP.NET Core.

## Casos Funcionales

### Caso A - Cliente excelente

Datos:

- Varias deudas historicas.
- Pagos completos antes de 30 dias.
- Sin mora 30/45.
- Sin bloqueo 60.

Resultado esperado:

- Score alto, idealmente 70-100.
- Riesgo: `Bajo riesgo`.
- Limite sugerido positivo y razonable frente al promedio historico.
- Motivos incluyen pagos antes de 30 dias y cumplimiento alto.

### Caso B - Cliente regular

Datos:

- Deudas con pagos parciales.
- Algunos pagos entre 30 y 45 dias.
- Sin bloqueo 60.

Resultado esperado:

- Score medio, idealmente 40-69.
- Riesgo: `Riesgo medio`.
- Limite sugerido moderado.
- Motivos explican pagos 30-45 y cumplimiento parcial.

### Caso C - Cliente en mora

Datos:

- Ciclo vencido 30.
- Ciclo en mora 45.
- Saldo pendiente.

Resultado esperado:

- Score bajo o medio-bajo.
- Riesgo: `Riesgo alto` o `Riesgo medio` segun historial pagado.
- Limite sugerido bajo.
- Motivos mencionan vencido 30, mora 45 y saldo/cumplimiento.

### Caso D - Cliente bloqueado

Datos:

- Ciclo bloqueado 60.
- Saldo pendiente.

Resultado esperado:

- Score bajo.
- Riesgo: `Riesgo alto`.
- Limite sugerido muy bajo.
- Motivos mencionan bloqueo 60.

### Caso E - Cliente nuevo

Datos:

- Sin historial suficiente.

Resultado esperado:

- Score conservador.
- Riesgo no debe presentarse como prohibicion.
- Limite sugerido bajo o cero.
- Motivos incluyen historial insuficiente.

## Pantallas

### ClientScoreScreen

- Muestra score.
- Muestra riesgo.
- Muestra limite sugerido.
- Muestra motivos principales.
- Usa lenguaje `Fiado App recomienda`.
- No contiene `Fiado App prohibe` ni `Fiado App prohíbe`.

### ClientScoreReportScreen

- Muestra top mejores clientes ordenado por score descendente.
- Muestra top clientes en riesgo ordenado por score ascendente.
- Respeta `negocio_id` actual.
- Si existe score local o cloud sincronizado, usa el snapshot mas reciente
  disponible.

## Sync Cloud

- Calcular score guarda fila en `client_scores`.
- Calcular score encola `sync_queue` con `entity_type = client_scores`.
- Push usa `POST /api/client-scores/sync/push`.
- Pull usa `POST /api/client-scores/sync/pull`.
- No mezcla negocios: `negocio_id` local y `BusinessId` backend deben coincidir.
- Si el cliente no tiene `remote_id`, el push falla claramente y no borra datos.

## SQL Server

- Tabla `ClientScores` existe.
- `BusinessId` coincide con JWT.
- `ClientId` pertenece al mismo negocio.
- `Score`, `RiskLevel`, `SuggestedCreditLimit` y fechas se persisten.
- `__EFMigrationsHistory` contiene `AddClientScores`.

## Prueba Live Cloud

Fecha: 2026-05-30.

- Base URL: `http://127.0.0.1:5197/api`.
- SQL Server: `FiadoAppDb` via `127.0.0.1,14333`.
- Negocio: `QA Score Live 0530165948921`.
- BusinessId: `619b7a8a-d757-4f0b-bb0b-05784adb2cf6`.
- Cliente: `Cliente Score Live 0530165948921`.
- ClientId: `9d802807-f785-4eb3-b9da-a069bc35441c`.
- Score enviado: `88`.
- Riesgo enviado: `Bajo riesgo`.
- Limite enviado: `1500.00`.

Resultado:

- `POST /api/client-scores/sync/push`: `created`.
- Server score id: `24a3b55c-4d47-4b1d-9dc1-eb4cfa2e3601`.
- `POST /api/client-scores/sync/pull`: devolvio 1 score.
- SQL Server confirmo `BusinessId`, `ClientId`, `Score`, `RiskLevel` y
  `SuggestedCreditLimit`.
- Segundo negocio `b34098a1-f1a4-4b08-b5a4-aade5676c03b` obtuvo 0 scores,
  validando aislamiento multi-negocio.

## Resultado Esperado Del Script

Ejecutar:

```bat
dart run tools\qa\run_client_score_qa.dart
```

El script debe crear `qa_data/client_score_qa.db`, imprimir casos A-E y validar:

- Orden top: A sobre B/C/D/E.
- Orden riesgo: D/C antes que A.
- Cinco filas en `client_scores`.
- Cinco entradas en `sync_queue`.
