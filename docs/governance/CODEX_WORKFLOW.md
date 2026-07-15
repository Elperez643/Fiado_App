# Codex Workflow

Every future task follows five stages.

1. Independent analysis

Agents `01-producto-ux`, `02-arquitectura-integridad`, `04-qa-regresion-sync`, and `05-seguridad-aislamiento` review the request before implementation.

2. Architectural consolidation

Agent `02-arquitectura-integridad` produces the single approved plan: baseline, scope, out of scope, modifiable files, protected files, risks, tests, and rollback.

3. Implementation

Only agent `03-implementacion-codigo` modifies code during normal implementation. It must follow the approved plan and keep changes scoped.

4. Independent review

Agents `01`, `02`, `04`, and `05` review the result. The implementer cannot approve its own work as final.

5. Final verdict

Allowed states:

- `APROBADO`
- `APROBADO CON OBSERVACIONES`
- `RECHAZADO`
- `NO VALIDADO`

The task cannot close with a critical `RECHAZADO`, a critical `NO VALIDADO`, missing tests, secrets, regressions, uncommitted scoped changes, or unapproved scope expansion.
