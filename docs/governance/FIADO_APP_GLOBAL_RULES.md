# Fiado App Global Rules

- Stability before speed.
- Do not break existing features to add a new one.
- Keep the app Offline First: SQLite remains the local source for offline operation.
- Synchronization must be automatic, idempotent, observable, and recoverable.
- Preserve multi-business isolation. No cross-business reads or writes.
- Respect roles: Personal, Negocio, Colaborador, and future roles must have explicit permissions.
- Security is backend-enforced. Hiding a button is not authorization.
- UX must be clear for non-technical merchants in the Dominican Republic.
- Use clean code, small methods, clear names, and existing project patterns.
- SQL must be parameterized and efficient.
- Tests and QA evidence are part of the work, not an optional extra.
- Git changes must be scoped, reviewable, and recoverable.
- Documentation must be updated when behavior, setup, architecture, or operations change.
- Any review agent has veto power when architecture, data, security, UX, or QA is unsafe.
- Do not expand scope without approval.
- Do not hide errors or mark unexecuted validations as passed.
