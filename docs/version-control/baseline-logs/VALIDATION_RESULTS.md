# Validation Results

Date: 2026-07-15

Scope: final governed baseline validation before creating a stable tag and CI workflow.

## Tool Availability

| Validation | Command | Exit Code | Status | Evidence |
| --- | --- | ---: | --- | --- |
| Dart available | `dart --version` | 0 | APROBADO | Dart SDK `3.11.4` stable on `windows_x64` |
| Flutter available | `flutter --version` | 0 | APROBADO | Flutter `3.41.6` stable, Dart `3.11.4`, DevTools `2.54.2` |

## Dart And Flutter Quality Checks

| Validation | Command | Exit Code | Status | Log |
| --- | --- | ---: | --- | --- |
| Dart format check | `dart format --output=none --set-exit-if-changed .` | 0 | APROBADO | `docs/version-control/baseline-logs/dart-format-check-final.txt` |
| Targeted lint fix format check | `dart format --output=none --set-exit-if-changed lib\data\repositories\sync_outbox_repository.dart` | 0 | APROBADO | Manual output: `Formatted 1 file (0 changed) in 0.01 seconds.` |
| Flutter analyze after lint fix | `flutter analyze` | 0 | APROBADO | `docs/version-control/baseline-logs/flutter-analyze-final.txt` |
| Targeted failing test | `flutter test test/client_sync_v2_test.dart --plain-name "pull exitoso sin pendientes limpia error visible anterior"` | 0 | APROBADO | Manual output: `All tests passed!` |
| Client sync test file | `flutter test test/client_sync_v2_test.dart` | 0 | APROBADO | Manual output: `All tests passed!` |
| Flutter full test suite | `flutter test` | 0 | APROBADO | `docs/version-control/baseline-logs/flutter-test-final.txt` |

## Lint Correction

Corrected lint:

```text
use_null_aware_elements
lib\data\repositories\sync_outbox_repository.dart:198:37
```

Implementation:

```dart
[SyncOutboxItem.statusFailed, ?module]
```

This preserves the previous condition and order: `module` is included only when it is non-null.

## Test Fixture Correction

Previous full-suite failure:

```text
test/client_sync_v2_test.dart:167
Bad state: Too many elements
```

Root cause: `_ClientFixture.open()` created `sync_state` but did not apply the production/test schema indexes. Without `idx_sync_state_business_module`, `SyncStateRepository.upsert()` could insert a second logical `clients` state row instead of replacing the existing `(business_id, module)` row.

Correction: the fixture now applies the same `idx_sync_outbox_` and `idx_sync_state_` indexes used by `DatabaseHelper._ensureNewSyncBaseTables()` and `test/sync_engine_base_test.dart`.

## Flutter Analyze Summary

```text
Analyzing fiado_app...
No issues found! (ran in 8.2s)
```

Classification: `APROBADO`.

## Flutter Test Summary

```text
00:17 +111: All tests passed!
```

Classification: `APROBADO`.

## Stable Tag Decision

The previous blocker is resolved.

Baseline is now eligible for final tag evaluation, but the stable tag has not been created yet.
