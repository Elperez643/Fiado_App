# Pending Files Inventory

Date: 2026-07-15

Source evidence:

- `git-diff-name-status.txt`
- `untracked-files.txt`
- Manual outputs from `git status --branch`
- Manual outputs from `git -C dist ...`

Status: initial classification. No files have been staged by this inventory.

## 1. Codigo Fuente

Tracked modified Flutter/Dart source:

- `lib/core/database/database_schema.dart`
- `lib/core/database/local_database.dart`
- `lib/core/theme/app_theme.dart`
- `lib/core/utils/currency_formatter.dart`
- `lib/data/datasources/product_local_datasource.dart`
- `lib/data/models/cliente_mapper.dart`
- `lib/data/models/movimiento_mapper.dart`
- `lib/data/models/producto_mapper.dart`
- `lib/data/repositories/client_repository_impl.dart`
- `lib/data/repositories/movement_repository_impl.dart`
- `lib/domain/entities/product_entity.dart`
- `lib/domain/repositories/movement_repository.dart`
- `lib/main.dart`
- `lib/models/cliente.dart`
- `lib/models/movimiento.dart`
- `lib/models/producto.dart`
- `lib/screens/*.dart` listed in evidence
- `lib/services/inventario_service.dart`
- `lib/services/storage_service.dart`
- `lib/utils/auditoria_helper.dart`
- `lib/widgets/cliente_search_dialog.dart`

Untracked Flutter/Dart source groups:

- `lib/business_copilot/`
- `lib/collections_intelligence/`
- `lib/core/api/`
- `lib/core/config/`
- `lib/core/constants/`
- `lib/core/database/database_helper.dart`
- `lib/core/database/database_platform*.dart`
- `lib/core/diagnostics/`
- `lib/core/permissions/`
- `lib/core/security/`
- `lib/core/session/`
- `lib/core/sync/`
- `lib/core/theme/app_colors.dart`
- `lib/core/theme/app_gradients.dart`
- `lib/core/theme/app_motion.dart`
- `lib/core/theme/app_shadows.dart`
- `lib/core/utils/money_formatter.dart`
- `lib/credit_scoring/`
- `lib/data/contracts/`
- `lib/data/models/`
- `lib/data/repositories/`
- `lib/data/services/`
- `lib/inventory_intelligence/`
- `lib/personal_debt_guidance/`
- `lib/presentation/providers/`
- `lib/screens/`
- `lib/screens/widgets/`
- `lib/widgets/`

Untracked backend C# source:

- `backend/src/FiadoApp.Api/Controllers/`
- `backend/src/FiadoApp.Api/DTOs/`
- `backend/src/FiadoApp.Api/Data/`
- `backend/src/FiadoApp.Api/Entities/`
- `backend/src/FiadoApp.Api/Payments/`
- `backend/src/FiadoApp.Api/Program.cs`
- `backend/src/FiadoApp.Api/Services/`
- `backend/src/FiadoApp.Api/Subscriptions/`

Recommendation: preserve in Git after secrets review and grouped staging.

## 2. Configuracion Necesaria

Tracked modified:

- `android/app/src/debug/AndroidManifest.xml`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/profile/AndroidManifest.xml`
- `ios/Runner/Info.plist`
- `pubspec.yaml`
- `pubspec.lock`
- `linux/flutter/generated_plugin_registrant.cc`
- `linux/flutter/generated_plugins.cmake`
- `macos/Flutter/GeneratedPluginRegistrant.swift`
- `windows/flutter/generated_plugin_registrant.cc`
- `windows/flutter/generated_plugins.cmake`

Untracked:

- `backend/FiadoApp.Backend.sln`
- `backend/src/FiadoApp.Api/FiadoApp.Api.csproj`
- `backend/src/FiadoApp.Api/FiadoApp.Api.http`
- `backend/src/FiadoApp.Api/Properties/launchSettings.json`
- `backend/src/FiadoApp.Api/appsettings.json`

Risk notes:

- `backend/src/FiadoApp.Api/appsettings.json` may contain local connection strings or secrets. It must be inspected before staging.
- `launchSettings.json` may contain local URLs or environment variables. It must be inspected before staging.

## 3. Documentacion y Scripts

Root documentation and QA reports:

- `*_QA.md`
- `*_REPORT.md`
- `*_CHECKLIST.md`
- `*_AUDIT.md`
- `API_CONTRACTS.md`
- `MIGRATION_PLAN.md`
- `STAGING_LOCAL.md`
- `STRIPE_TEST_SETUP.md`
- `SUBSCRIPTION_PRICING.md`
- `UI_DESIGN_SYSTEM.md`
- `WHATSAPP_CAMPAIGNS.md`

Backend documentation:

- `backend/DB_SETUP.md`
- `backend/README_BACKEND.md`

Docs folder:

- `docs/sync_data_contract_matrix.md`
- `docs/version-control/repository-normalization/*.txt`

Scripts and QA tools:

- `tools/qa/`
- `tools/scripts/`
- `tools/sql/create_staginglocal_sql_login.sql`

Recommendation: preserve useful docs and scripts after secrets review. Generated evidence files may be versioned as part of this normalization if they do not contain secrets.

## 4. Secretos o Configuracion Local

Potentially sensitive files or paths requiring manual review:

- `backend/src/FiadoApp.Api/appsettings.json`
- `backend/src/FiadoApp.Api/Properties/launchSettings.json`
- `backend/DB_SETUP.md`
- `backend/README_BACKEND.md`
- `STAGING_LOCAL.md`
- `STRIPE_TEST_SETUP.md`
- `tools/scripts/*.ps1`
- `tools/sql/create_staginglocal_sql_login.sql`
- `lib/core/api/api_config.dart`
- `lib/core/api/api_environment.dart`
- `lib/core/security/secure_token_storage.dart`
- `lib/data/services/api_client.dart`
- `backend/src/FiadoApp.Api/Payments/Providers/StripePaymentProvider.cs`
- `backend/src/FiadoApp.Api/Payments/Providers/Azul/*`

Action: inspect with VS Code search only. Do not print secret values in terminal or chat.

## 5. Artefactos Generados

Known generated or accidental artifacts:

- `dist` gitlink/repository content
- `dist/*.apk`
- `dist/web/`
- `dist/windows/`
- `cd`
- `copy`
- `dart`
- `dotnet`
- `flutter`
- `set`
- `Microsoft.AspNetCore.Connections.AddressInUseException`
- `System.Net.Sockets.SocketException`
- `docs/version-control/repository-normalization/git-status-short.txtgit`

Recommendation: do not stage as source. The accidental command-name files and empty evidence typo file should be removed only after backup and explicit approval.

## 6. Datos Locales

No local database files are shown in the pasted untracked list because current `.gitignore` appears to exclude many DB patterns. Continue checking with `git check-ignore` samples later.

## 7. Archivos Dudosos

- `cd`
- `copy`
- `dart`
- `dotnet`
- `flutter`
- `set`
- `Microsoft.AspNetCore.Connections.AddressInUseException`
- `System.Net.Sockets.SocketException`
- `docs/version-control/repository-normalization/git-status-short.txtgit`

Reason: names suggest accidental command output, placeholder files, or local shell artifacts. Must not be staged until inspected.

## 8. Eliminaciones o Renombrados

Tracked modified list does not show delete or rename entries in the root repo evidence. Inside nested `dist`, `Fiado-Beta-Android-debug-7.apk` is deleted relative to the internal `dist` repository.

## 9. Repositorios Anidados o Gitlinks

- `dist` is tracked in the root repo as a gitlink (`160000`).
- `dist` has its own `.git` directory.
- Root repo has no valid `.gitmodules` mapping for `dist`.
- Internal `dist` remote points to `https://github.com/Elperez643/Repositorio.git`.

Recommendation: document and resolve in a dedicated, approved step. Do not delete `dist/.git` yet.
