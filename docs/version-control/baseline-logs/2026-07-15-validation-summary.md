# Validation Summary - 2026-07-15

Scope: Git/governance/agents baseline, repository normalization, and allowed backend validation.

## Current Git Baseline

- Branch: `master`
- Backup branch: `backup/pre-normalization-2026-07-15`
- Remote tracking: `origin/master`
- Current state after repository normalization: clean working tree, local branch ahead of `origin/master`.

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

- `dart format --output=none --set-exit-if-changed .`: `NO VALIDADO`.
- `flutter analyze`: `NO VALIDADO`.
- `flutter test`: `NO VALIDADO`.

These validations require manual execution by the user under the hybrid execution protocol.

## Verdict

Repository normalization and backend .NET validation are complete and approved with logs. Dart/Flutter validation remains pending manual execution.
