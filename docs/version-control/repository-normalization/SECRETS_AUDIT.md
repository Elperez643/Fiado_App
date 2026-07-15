# Secrets Audit

Date: 2026-07-15

Method:

- Hybrid-mode repository searches executed by Codex.
- Searches returned file paths only, not secret values.
- JSON configuration was inspected structurally without printing values.
- No history rewrite was attempted.

## Summary

Status: `NO VALIDADO` for absence of all secrets until staged content is reviewed before commit.

No files containing `AccountKey`, `SharedAccessSignature`, `PrivateKey`, or `BEGIN ... PRIVATE KEY` were reported by the path-only searches.

Potentially sensitive configuration and examples exist and must be handled carefully before staging.

## Findings

### backend/src/FiadoApp.Api/appsettings.json

- Type: `ConnectionStrings`, JWT key, payment/provider configuration section.
- Git state: pending/untracked in current normalization evidence.
- Appears: local/development configuration. `ConnectionStrings.FiadoDb` classified as local; `Jwt.Key` classified as placeholder-or-development by pattern/length.
- Risk: medium. Even development JWT keys and connection strings should not be treated casually.
- Recommended action: do not stage until reviewed. Prefer staging `appsettings.Template.json` and keeping environment-specific appsettings ignored unless team decides this file is safe sample config.
- Requires rotation: no evidence of production secret, but `NO SEGURO` until human confirms values were never real production credentials.

### backend/src/FiadoApp.Api/appsettings.Template.json

- Type: placeholders for connection string, JWT secret, Stripe/Azul keys.
- Git state: tracked by governance commit.
- Appears: placeholder/template.
- Risk: low.
- Recommended action: keep versioned as safe template.
- Requires rotation: no.

### backend/src/FiadoApp.Api/Properties/launchSettings.json

- Type: local development launch configuration.
- Git state: pending/untracked.
- Appears: environment-specific development settings.
- Risk: low to medium depending on environment variables inside file.
- Recommended action: inspect before staging; do not include secrets or personal endpoints.
- Requires rotation: no evidence.

### backend/DB_SETUP.md

- Type: local SQL Server examples, `User Id`/`Password` placeholder examples.
- Git state: pending/untracked.
- Appears: documentation/example based on path-only and previous evidence.
- Risk: medium because setup docs often collect real local values over time.
- Recommended action: inspect manually before staging; keep placeholders only.
- Requires rotation: no evidence.

### backend/README_BACKEND.md

- Type: Bearer/API usage examples and backend setup notes.
- Git state: pending/untracked.
- Appears: documentation/example.
- Risk: low to medium.
- Recommended action: inspect for copied real tokens before staging.
- Requires rotation: no evidence.

### STAGING_LOCAL.md

- Type: staging/local connection guidance.
- Git state: pending/untracked.
- Appears: local documentation.
- Risk: medium.
- Recommended action: inspect for real host/user/password values before staging.
- Requires rotation: no evidence.

### STRIPE_TEST_SETUP.md

- Type: Stripe setup documentation.
- Git state: pending/untracked.
- Appears: payment setup docs.
- Risk: medium to high if real Stripe keys were copied.
- Recommended action: inspect before staging; only placeholders or redacted examples may be committed.
- Requires rotation: `NO SEGURO` until visually confirmed.

### AZUL_PAYMENT_ARCHITECTURE.md / AZUL_PAYMENT_QA.md

- Type: Azul payment documentation.
- Git state: pending/untracked.
- Appears: architecture/QA docs.
- Risk: medium if merchant IDs/secrets were copied.
- Recommended action: inspect before staging; redact real merchant credentials.
- Requires rotation: no evidence.

### backend/src/FiadoApp.Api/Payments/Providers/StripePaymentProvider.cs

- Type: payment provider API key usage path.
- Git state: pending/untracked.
- Appears: code reads/uses secret configuration.
- Risk: low if no literal key is present; high if literal key exists.
- Recommended action: inspect for hard-coded keys before staging.
- Requires rotation: no evidence.

### backend/src/FiadoApp.Api/Payments/Providers/Azul/*

- Type: Azul options/provider code.
- Git state: pending/untracked.
- Appears: code reads/uses payment configuration.
- Risk: low if no literal merchant secret is present; high if literal secret exists.
- Recommended action: inspect for hard-coded credentials before staging.
- Requires rotation: no evidence.

### lib/data/services/api_client.dart

- Type: Bearer token header construction.
- Git state: pending/untracked.
- Appears: expected code path for authenticated requests.
- Risk: low if token is read from secure storage/session and not hard-coded.
- Recommended action: inspect for hard-coded token or logging before staging.
- Requires rotation: no evidence.

### test/cloud_client_initial_restore_test.dart

- Type: Bearer token test value.
- Git state: pending/untracked.
- Appears: test fixture/example token.
- Risk: low if synthetic.
- Recommended action: keep synthetic/redacted only.
- Requires rotation: no evidence.

### test/sync_diagnostics_test.dart

- Type: Bearer token text in diagnostics test.
- Git state: pending/untracked.
- Appears: test/redaction coverage.
- Risk: low if synthetic and expected.
- Recommended action: ensure no real token string is present.
- Requires rotation: no evidence.

### lib/data/repositories/sync_diagnostics_repository.dart

- Type: Bearer/redaction handling.
- Git state: pending/untracked.
- Appears: code path for redacting diagnostics.
- Risk: low if it redacts tokens; medium if it logs raw tokens.
- Recommended action: inspect before staging.
- Requires rotation: no evidence.

### tools/scripts/*.ps1

- Type: local connection string handling and staging/local diagnostics.
- Git state: pending/untracked.
- Appears: scripts read local config/environment connection strings.
- Risk: medium because scripts may print effective connection information.
- Recommended action: inspect before staging; ensure no real secret literals and no full secret logging.
- Requires rotation: no evidence.

### tools/sql/create_staginglocal_sql_login.sql

- Type: SQL login setup.
- Git state: pending/untracked.
- Appears: local setup script.
- Risk: medium to high if it contains a real password.
- Recommended action: inspect before staging; use placeholders or documentation instructions only.
- Requires rotation: `NO SEGURO` until visually confirmed.

## Immediate Rules Before Staging

- Do not stage `backend/src/FiadoApp.Api/appsettings.json` until it is confirmed safe or converted to a template.
- Do not stage payment setup docs until confirmed placeholder/redacted.
- Do not stage SQL login scripts if they contain real passwords.
- Do not stage logs or generated evidence if they contain connection strings or token values.
- Before each commit, run staged diff review and path-only secret scan over staged files.

## Rotation Status

No confirmed production secret has been exposed in the current evidence.

Rotation is required only if manual review confirms a real credential was committed previously or is present in pending files.
