# Git Workflow

Fiado App uses one monorepository for Flutter, ASP.NET Core, tests, scripts, assets, and documentation.

Branches:

- `master`: current protected baseline branch in this local repository.
- `main`: future canonical branch if the remote is renamed.
- `develop`: integration branch when the team needs one.
- `feature/*`, `fix/*`, `security/*`, `refactor/*`, `docs/*`, `migration/*`, `infrastructure/*`: task branches.

Rules:

- Start each task from a clean understanding of `git status`.
- Do not mix unrelated functional changes with governance, docs, build, or migration work.
- Commit messages must describe intent, for example `chore: establish repository governance baseline`.
- Do not run `git reset --hard`, `git clean -fd`, force push, or history rewrite without explicit approval.
- Generated artifacts stay out of Git: APK, EXE, ZIP, local DB, logs, build folders, and local tool caches.
- EF Core migrations are source and must be versioned when intentionally created.
- Flutter generated registrants may be versioned only when they are stable platform source, not ephemeral symlink output.
- Secrets never enter Git. Use templates, local user secrets, environment variables, or secret stores.

Task flow:

1. Create or select a scoped branch when needed.
2. Run the five-agent analysis flow from `docs/governance/CODEX_WORKFLOW.md`.
3. Implement only the approved scope.
4. Run validations and store relevant evidence.
5. Review staged files before commit.
6. Commit with one clear message.
7. Close only after agent verdicts and user acceptance.

Safe recovery:

- Inspect history with `git log --oneline --decorate`.
- Inspect changes with `git diff` and `git diff --staged`.
- Restore a single file only after confirming scope with `git restore -- path`.
- Prefer a recovery branch over destructive rollback: `git switch -c recovery/<date>-<topic>`.
