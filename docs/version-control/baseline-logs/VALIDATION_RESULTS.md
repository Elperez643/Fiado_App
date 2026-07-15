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
| Flutter analyze | `flutter analyze` | 1 | FALLÓ | `docs/version-control/baseline-logs/flutter-analyze-final.txt` |
| Flutter test | `flutter test` | N/A | NO EJECUTADO | Blocked after `flutter analyze` failure |

## Dart Format Summary

```text
Formatted 271 files (0 changed) in 1.56 seconds.
```

Classification: `APROBADO`.

## Flutter Analyze Summary

```text
info - Use the null-aware marker '?' rather than a null check via an 'if' - lib\data\repositories\sync_outbox_repository.dart:198:37 - use_null_aware_elements

1 issue found. (ran in 119.1s)
```

Classification: `FALLÓ`.

Failure type: static analysis/lint issue.

Current recommendation: fix the preexisting lint in a dedicated functional/code-quality task, then rerun:

```cmd
flutter analyze
flutter test
```

## Stable Tag Decision

Stable tag creation is blocked.

Reason: the baseline requires `flutter analyze` to pass before creating `fiado-app-baseline-2026-07-15`.

No stable tag should be created from the current commit until the analyze failure is resolved and Flutter tests are executed successfully.
