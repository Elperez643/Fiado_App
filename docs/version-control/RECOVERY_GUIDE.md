# Recovery Guide

Inspect first:

- `git status --short --branch`
- `git log --oneline --decorate -10`
- `git diff`
- `git diff --staged`

Create a recovery branch before risky work:

```powershell
git switch -c recovery/2026-07-15-topic
```

Return to a previous commit safely:

- Prefer `git switch -c recovery/<topic> <commit>` to inspect the old state.
- Use `git revert <commit>` to undo a committed change without rewriting history.

Restore one file:

```powershell
git restore -- path/to/file
```

Restore one staged file:

```powershell
git restore --staged -- path/to/file
```

Prohibited without explicit approval:

- `git reset --hard`
- `git clean -fd`
- force push
- branch changes that discard local modifications
- deleting migrations, databases, or configuration

Before any recovery action, save evidence with `git diff` or create a temporary branch.
