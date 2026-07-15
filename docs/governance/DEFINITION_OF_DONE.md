# Definition Of Done

A task is complete only when:

- The requested requirement is satisfied.
- UX remains understandable for the target merchant.
- Architecture boundaries are respected.
- Security and privacy risks are addressed.
- Multi-business isolation is preserved.
- Offline behavior works when applicable.
- Synchronization remains safe when applicable.
- Existing behavior is not duplicated or regressed.
- Tests or a documented validation alternative exist.
- Evidence is recorded.
- Documentation is updated.
- A scoped commit exists.
- Required agents have approved or explicitly marked non-critical observations.
- No critical validation contains `NO VALIDADO`.

A task is not complete when:

- A critical agent verdict is `RECHAZADO`.
- A critical validation was skipped.
- A secret is present in code, config, logs, docs, or staged files.
- Changes are outside approved scope.
- Required files are uncommitted.
