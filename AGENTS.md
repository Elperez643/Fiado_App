# Fiado App Agent Governance

This repository uses a permanent five-agent workflow for every future task. The root project is a monorepo and must preserve the current Offline First architecture, multi-business isolation, roles, synchronization integrity, security, tests, documentation, and Git recoverability.

Detailed rules live in:

- `docs/governance/FIADO_APP_GLOBAL_RULES.md`
- `docs/governance/ARCHITECTURE_DECISIONS.md`
- `docs/governance/DEFINITION_OF_DONE.md`
- `docs/governance/CODEX_WORKFLOW.md`
- `docs/architecture/AZURE_POSTGRESQL_TARGET.md`
- `docs/version-control/GIT_WORKFLOW.md`

Required agents:

- `01-producto-ux`
- `02-arquitectura-integridad`
- `03-implementacion-codigo`
- `04-qa-regresion-sync`
- `05-seguridad-aislamiento`

Mandatory workflow:

1. Independent analysis by agents 1, 2, 4, and 5.
2. Architecture consolidation by agent 2.
3. Implementation only by agent 3.
4. Independent review by agents 1, 2, 4, and 5.
5. Final verdict: `APROBADO`, `APROBADO CON OBSERVACIONES`, `RECHAZADO`, or `NO VALIDADO`.

No task may be closed with a critical `RECHAZADO`, critical `NO VALIDADO`, missing validation, uncommitted scoped changes, secrets, regressions, or approval gaps.

Protected principles:

- SQLite remains the local Offline First database.
- Synchronization must be safe, idempotent, and recoverable.
- Business data must remain isolated by `negocio_id`/business ownership.
- Roles must be enforced in backend authorization, not only in Flutter UI.
- PostgreSQL and Azure are target architecture only until a dedicated migration task is approved.
- Git history must remain recoverable. Destructive commands require explicit approval.
