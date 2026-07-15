# Inventory Isolation QA

Regla: los productos no son globales. Cada producto pertenece exclusivamente a
un negocio por `negocio_id`.

## Casos

- [ ] Negocio A crea Producto A; Negocio B no lo ve.
- [ ] Negocio B crea Producto B; Negocio A no lo ve.
- [ ] Colaborador de Negocio A ve Producto A y no ve Producto B.
- [ ] Usuario Personal no accede a inventario.
- [ ] Negocio nuevo entra por primera vez y ve inventario vacio.
- [ ] Mismo nombre permitido en Negocio A y Negocio B.
- [ ] Mismo codigo de barras permitido en Negocio A y Negocio B.
- [ ] Crear fiado en Negocio A: selector solo muestra productos de Negocio A.
- [ ] Campanas WhatsApp en Negocio A solo muestran productos de Negocio A.
- [ ] Inventario Inteligente en Negocio B no usa productos de Negocio A.
- [ ] Business Copilot no recomienda productos de otro negocio.
- [ ] Sync cloud pull bloquea productos si el `businessId` remoto no coincide.

## Scripts

Auditoria:

```cmd
dart run tools\qa\run_inventory_isolation_audit.dart --db RUTA_DB
```

Limpieza segura:

```cmd
dart run tools\qa\clean_orphan_test_inventory.dart --db RUTA_DB --dry-run
```

Aplicar limpieza de globales/huerfanos:

```cmd
dart run tools\qa\clean_orphan_test_inventory.dart --db RUTA_DB --apply
```

