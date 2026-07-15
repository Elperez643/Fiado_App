# Validation Summary - 2026-07-15

Scope: Git/governance/agents baseline, repository normalization, allowed backend validation, and final Dart/Flutter validation.

## Current Git Baseline

- Branch: `master`
- Backup branch: `backup/pre-normalization-2026-07-15`
- Remote tracking: `origin/master`
- Current state after repository normalization: local branch ahead of `origin/master`.

## Repository Normalization Results

- `dist` broken gitlink resolved.
- Nested `dist\.git` metadata backed up under `.local-backups/`.
- Selected `dist` manuals were preserved as normal root repository files.
- Generated APKs, `dist/web/`, and `dist/windows/` remain ignored.
- `git submodule status`: `APROBADO`, exit code `0`.

## .NET Validation Results

- `dotnet --version`: `10.0.201`.
- `dotnet restore backend\FiadoApp.Backend.sln`: `APROBADO`, exit code `0`, duration `2s`.
- `dotnet build backend\FiadoApp.Backend.sln --no-restore`: `APROBADO`, exit code `0`, duration `12s`, `0 Warning(s)`, `0 Error(s)`.
- `dotnet test backend\FiadoApp.Backend.sln --no-build`: `APROBADO`, exit code `0`, duration `1s`; no test output was emitted, which indicates no .NET test projects were discovered in the solution.

Logs:

- `docs/version-control/baseline-logs/dotnet-restore.txt`
- `docs/version-control/baseline-logs/dotnet-build.txt`
- `docs/version-control/baseline-logs/dotnet-test.txt`

## Dart And Flutter Validation Results

Policy update: Codex must not directly execute commands that start with `dart` or `flutter`.

- `dart --version`: `APROBADO`, exit code `0`, Dart SDK `3.11.4`.
- `flutter --version`: `APROBADO`, exit code `0`, Flutter `3.41.6`, Dart `3.11.4`.
- `dart format --output=none --set-exit-if-changed .`: `APROBADO`, exit code `0`, `Formatted 271 files (0 changed) in 1.56 seconds.`
- `dart format --output=none --set-exit-if-changed lib\data\repositories\sync_outbox_repository.dart`: `APROBADO`, exit code `0`.
- `flutter analyze`: `APROBADO`, exit code `0`.
- `flutter test test/client_sync_v2_test.dart --plain-name "pull exitoso sin pendientes limpia error visible anterior"`: `APROBADO`, exit code `0`.
- `flutter test test/client_sync_v2_test.dart`: `APROBADO`, exit code `0`.
- `flutter test`: `APROBADO`, exit code `0`, `00:17 +111: All tests passed!`.

Corrected lint:

```text
use_null_aware_elements - lib\data\repositories\sync_outbox_repository.dart:198:37
```

Test fixture correction:

- `test/client_sync_v2_test.dart` now applies `idx_sync_outbox_` and `idx_sync_state_` indexes in its in-memory fixture.
- This matches the production schema path and prevents duplicate logical `sync_state` rows for `(business_id, module)`.

Logs:

- `docs/version-control/baseline-logs/dart-format-check-final.txt`
- `docs/version-control/baseline-logs/flutter-analyze-final.txt`
- `docs/version-control/baseline-logs/flutter-test-final.txt`
- `docs/version-control/baseline-logs/VALIDATION_RESULTS.md`

## Verdict

Repository normalization, backend .NET validation, Dart availability, Flutter availability, Dart format check, Flutter analyze, and Flutter tests are approved with logs.

The baseline is eligible for final tag evaluation. The stable tag has not been created yet.
