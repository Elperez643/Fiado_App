# Dist Analysis

Date: 2026-07-15

## Evidence

Root repository:

```text
git submodule status
fatal: no submodule mapping found in .gitmodules for path 'dist'

git ls-files --stage dist
160000 98525914f1bc227a0e8af6b4f9c440a6618ce8a3 0       dist
```

Filesystem:

- `dist/.git` exists as a real directory.
- `dist` contains 18 large APK files.
- `dist` contains `web/` and `windows/` build output folders.
- `dist` contains documentation-like files:
  - `README.md`
  - `fiado_app_manual_completo.csv`
  - `fiado_app_manual_completo_step_by_step.docx`
  - `fiado_app_manual_completo_step_by_step.md`
  - `fiado_app_manual_resumen.md`

Nested repository:

```text
branch: master
head: 9852591 primer commit
remote: https://github.com/Elperez643/Repositorio.git
```

Nested repository pending state:

- Deleted tracked file: `Fiado-Beta-Android-debug-7.apk`
- Untracked: generated APKs, web build, Windows build, and manual documents.

## Classification

`dist` is not a normal folder from the root repository perspective. It is a gitlink/submodule-like entry without a valid `.gitmodules` mapping, plus a real nested Git repository on disk.

This is a broken or incomplete submodule/gitlink state.

## Risks

- Root repository cannot fully control the contents of `dist` while it remains a gitlink.
- The `.gitmodules` mapping is missing, so standard submodule commands fail.
- Large binaries should not be committed into the root repository.
- Documentation inside `dist` may be useful and should not be lost.
- Removing `dist/.git` or `git rm dist` without a backup can lose provenance or state.

## Safe Resolution Options

Option 1: Keep `dist` as external/nested repository.

- Restore or create correct `.gitmodules`.
- Keep `dist` excluded from root content.
- Document that release artifacts live in the external repo.

Option 2: Convert `dist` into a normal root folder with only selected docs.

- Backup `dist`.
- Remove gitlink from root index.
- Preserve selected docs.
- Ignore APK, web, and Windows build outputs.
- Remove nested `.git` only after explicit approval and backup.

Option 3: Remove `dist` from root tracking and keep local ignored artifacts only.

- Backup first.
- Remove gitlink from root index.
- Keep local `dist` ignored for binaries.
- Move useful docs outside `dist` or selectively stage them.

## Recommendation

Prefer Option 2 or Option 3 after backup. Do not resolve automatically in this phase. First complete secrets review, backup branch creation, and explicit user approval.
