# Baseline Report

Date: 2026-07-15

Repository root: `C:\Users\eric_\fiado_app`

Current branch: `master`

Existing baseline commit before this task: `6154d1a`

Project structure found:

- Flutter application at repository root: `pubspec.yaml`, `lib/`, `test/`, `android/`, `ios/`, `linux/`, `macos/`, `web/`, `windows/`.
- ASP.NET Core backend under `backend/`, including `FiadoApp.Backend.sln`, `src/FiadoApp.Api/FiadoApp.Api.csproj`, and EF Core migrations.
- Scripts under `scripts/` and `tools/scripts/`.
- Documentation in root markdown files and `docs/`.
- Distribution/build output under `dist/`.
- Local QA SQLite databases under `qa_data/`.

Approximate visible files during audit: 962 non-Git files reported by `rg --files` before ignore improvements.

Git repositories detected:

- Root repository: `C:\Users\eric_\fiado_app\.git`
- Nested repository: `C:\Users\eric_\fiado_app\dist\.git`

Risks:

- The root repository already had one commit and many pending functional changes before this governance task.
- `dist/` is a nested repository or gitlink and contains generated binaries.
- Local generated folders existed: `.codex_appdata/`, `.codex_build/`, `.codex_dart_appdata/`, `.codex_logs/`, `.dart_tool/`, build output, platform ephemeral folders.
- QA databases and APK/EXE artifacts are large and must not be committed.

Potential secrets, values not shown:

- Local SQL Server connection strings in backend appsettings and documentation. They use local/trusted or placeholder values in the inspected lines, but must be treated as environment-specific configuration.
- Bearer/JWT references in API documentation and tests. Inspected matches appeared to be examples, placeholders, or redacted test strings.
- Payment provider code references API key assignment paths; real keys must come from secure configuration.

Files intentionally excluded by `.gitignore`:

- Local app data, logs, generated binaries, build outputs, local databases, signing keys, certificates, local appsettings, environment files, and platform ephemeral output.

Validation status:

- See `docs/version-control/baseline-logs/`.
- A full validation pass may fail for pre-existing functional changes; failures must be recorded, not hidden.
