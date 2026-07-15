# Azul Payment QA

## Configuracion requerida

Para sandbox mock:

- `Payments:Provider = Azul`
- Credenciales Azul vacias o no configuradas

Para Azul real:

- `Azul:MerchantId`
- `Azul:MerchantName`
- `Azul:AuthKey`
- `Azul:ApiUrl`
- `Azul:WebhookSecret`
- URLs de retorno

## Casos

| Caso | Resultado esperado |
| --- | --- |
| Crear sesion token Azul sin credenciales | Responde `sandboxMock=true` |
| Confirmar tarjeta sandbox 4242 | Guarda PaymentMethod `provider=Azul` |
| Confirmar tarjeta | Solo guarda token/metadatos, no PAN/CVV |
| Activar trial sin tarjeta | Falla con mensaje claro |
| Activar trial con tarjeta | `trial_active`, 30 dias |
| Segundo trial | Bloqueado |
| Cobro Azul sandbox OK | Payment + transaction, subscription `active` |
| Cobro Azul sandbox fallido | Payment + transaction, subscription `past_due` |
| Webhook Azul sandbox | Responde recibido, documentado como mock |

## Comandos sugeridos

```powershell
dotnet build backend\FiadoApp.Backend.sln
flutter analyze
flutter test
dart run tools\qa\run_subscription_onboarding_audit.dart
```

