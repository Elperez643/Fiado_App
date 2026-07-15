# Dist Detachment Backup

Date: 2026-07-15

## Source

- Root repository: `C:\Users\eric_\fiado_app`
- Nested path: `C:\Users\eric_\fiado_app\dist`
- Nested Git metadata: `C:\Users\eric_\fiado_app\dist\.git`

## Nested Repository State Before Detachment

- Type: real nested Git repository directory.
- Branch: `master`
- Commit: `9852591 primer commit`
- Remote: `https://github.com/Elperez643/Repositorio.git`

Internal status summary:

- Tracked deletion: `Fiado-Beta-Android-debug-7.apk`
- Untracked generated binaries: multiple APK files.
- Untracked generated build folders: `web/`, `windows/`.
- Untracked documents/manuals: CSV, DOCX, Markdown, and `README.md`.

## Approximate File Inventory

Top-level `dist` before detachment contained:

- 18 APK files, generated binaries, not versionable in root.
- `web/`, generated web build, not versionable in root.
- `windows/`, generated Windows build, not versionable in root.
- Documentation/manual files:
  - `README.md`
  - `fiado_app_manual_completo.csv`
  - `fiado_app_manual_completo_step_by_step.docx`
  - `fiado_app_manual_completo_step_by_step.md`
  - `fiado_app_manual_resumen.md`

## Metadata Backup And Detachment

Copied backup path:

```text
.local-backups\dist-git-metadata-2026-07-15
```

Live metadata removal path:

```text
.local-backups\dist-git-metadata-2026-07-15-live-removed
```

`.local-backups/` is ignored by root `.gitignore`.

Confirmed actions:

- Root gitlink removed from the index with `git rm --cached dist`.
- Physical `dist` files preserved.
- `dist\.git` moved out of `dist`, so `dist` no longer contains nested Git metadata.
- The old nested repository metadata remains recoverable under `.local-backups/`.

## Recovery Procedure

To recover the old nested repository relationship manually:

1. Confirm the root repository state and make a new backup branch.
2. Restore the metadata directory from `.local-backups\dist-git-metadata-2026-07-15-live-removed` back to `dist\.git` if needed.
3. Use `git -C dist status --branch` to inspect the restored nested repository.
4. If re-establishing a submodule is desired later, create a proper `.gitmodules` entry pointing to `https://github.com/Elperez643/Repositorio.git`.

This normalization intentionally does not configure `dist` as a submodule.
