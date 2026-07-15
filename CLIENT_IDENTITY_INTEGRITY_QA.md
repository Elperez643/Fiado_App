# Client Identity Integrity QA

## Casos Manuales

- Crear cliente Juan con telefono 8091111111, crear deuda y editar nombre a Juan Perez. La deuda, saldo, comprobante y cobranza deben seguir funcionando.
- Editar telefono 8091111111 a 8092222222. La deuda, score, cobranza y comprobantes deben seguir visibles.
- Crear pago despues de editar telefono. El pago debe asociarse al mismo cliente y bajar el saldo.
- Crear cliente con el mismo telefono en otro negocio. Debe permitirse sin mezclar deudas.
- Business Copilot recomienda cobrar cliente editado. Debe abrir Cobranza/Detalle correcto.
- Sync push/pull despues de editar telefono. No debe duplicar cliente ni perder movimientos.

## Auditoria

Ejecutar:

```bat
dart run tools\qa\run_client_identity_integrity_audit.dart
```

Resultado ideal en datos nuevos:

- `movimientos_huerfanos: 0`
- `ciclos_huerfanos: 0`
- `scores_huerfanos: 0`
- `recomendaciones_por_telefono: 0`
