# Money Formatting QA

Formato monetario global de Fiado App.

## Fuente Unica

- Formatter: `lib/core/utils/money_formatter.dart`
- Separador de miles: `,`
- Separador decimal: `.`
- Los valores almacenados en SQLite no cambian; solo cambia la presentacion.

## Casos Base

| Valor | Esperado |
| --- | --- |
| `1000` | `1,000` |
| `15000` | `15,000` |
| `1000000` | `1,000,000` |
| `50.05` | `50.05` |
| `1000.75` | `1,000.75` |
| `100000.00` | `100,000.00` |

## Superficies A Validar

- Dashboard Ejecutivo.
- Clientes y detalle de cliente.
- Deudas, pagos y cuentas por cobrar.
- Comprobantes en pantalla.
- PDF de comprobantes.
- Inventario e Inventario Inteligente.
- Cobranza Inteligente.
- Business Copilot.
- Recordatorios Personal.
- Suscripciones e historial de pagos.
- Campanas WhatsApp con precio visible.

## Resultado Esperado

Todos los importes visibles usan coma para miles y punto para decimales. Los
campos editables pueden mostrar el valor numerico simple para facilitar edicion,
pero todo monto renderizado para lectura o comprobante usa el formatter global.
