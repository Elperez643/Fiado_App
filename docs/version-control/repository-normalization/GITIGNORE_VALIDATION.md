# Gitignore Validation

Date: 2026-07-15

## Validated Samples

### Local database

Command:

```text
git check-ignore -v qa_data\stress_100000.db
```

Result:

```text
.gitignore:196:qa_data/*.db "qa_data\stress_100000.db"
```

Verdict: `APROBADO`

### Backend local appsettings

Command:

```text
git check-ignore -v backend\src\FiadoApp.Api\appsettings.json
```

Result:

```text
.gitignore:106:backend/src/FiadoApp.Api/appsettings.json "backend\src\FiadoApp.Api\appsettings.json"
```

Verdict: `APROBADO`

### Accidental command shadow file

Command:

```text
git check-ignore -v dart
```

Result:

```text
.gitignore:142:/dart dart
```

Verdict: `APROBADO`

### Source file must not be ignored

Command:

```text
git check-ignore -v lib\main.dart
```

Result: no output, exit code 1.

Verdict: `APROBADO`

## Dist Limitation

Command:

```text
git check-ignore -v dist\fiado_app_sync_v2_clients_debug.apk
```

Result:

```text
fatal: Pathspec 'dist\fiado_app_sync_v2_clients_debug.apk' is in submodule 'dist'
```

Verdict: `NO VALIDADO`

Reason: `dist` is currently tracked as a gitlink/submodule-like entry. Root ignore rules cannot be fully validated against files inside it until `dist` is resolved.

## Changes Made

`.gitignore` was updated to exclude:

- `backend/src/FiadoApp.Api/appsettings.json`
- root accidental command files: `/cd`, `/copy`, `/dart`, `/dotnet`, `/flutter`, `/set`
- root accidental exception files
- `docs/version-control/repository-normalization/*.txtgit`

## Remaining Risk

Before staging, re-run `git status --short` to confirm ignored local config and accidental files no longer appear as untracked.
