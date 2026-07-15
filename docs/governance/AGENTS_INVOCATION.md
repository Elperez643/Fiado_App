# Agents Invocation

Local format used: Markdown instruction profiles in `.agents/*.md`.

Reason: The installed Codex CLI from the VS Code extension exposes `codex exec`, `codex review`, plugins, MCP, and session commands, but no visible subcommand for named subagents. The local Codex skill folders include `agents/` directories, but no non-empty agent schema file was available to copy. Therefore the repository stores the five agents as versioned Markdown profiles that Codex can read and execute as role instructions.

VS Code invocation pattern:

1. Open the repository root in VS Code.
2. Start Codex in the Fiado App workspace.
3. For analysis, ask Codex to read the required profile, for example:

```text
Lee .agents/01-producto-ux.md y emite su veredicto para esta tarea sin modificar codigo: <tarea>.
```

4. Repeat for agents `02`, `04`, and `05`.
5. Ask agent `02` to consolidate the plan.
6. Ask agent `03` to implement only after the plan is approved.
7. Ask agents `01`, `02`, `04`, and `05` to review the result.

CLI invocation pattern:

```powershell
codex exec --cd C:\Users\eric_\fiado_app "Lee .agents/01-producto-ux.md y evalua sin modificar codigo: Cambiar el texto de un boton."
```

Simulation result for task: `Cambiar el texto de un boton`

```text
AGENTE: 01-producto-ux
VEREDICTO: APROBADO CON OBSERVACIONES
RIESGOS: confirmar que el nuevo texto sea claro para el rol afectado.
EVIDENCIA: tarea de bajo riesgo, solo copy visible.
ACCIONES REQUERIDAS: validar pantalla, estado offline si aplica y longitud en movil.

AGENTE: 02-arquitectura-integridad
VEREDICTO: APROBADO CON OBSERVACIONES
LINEA BASE: cambio de texto sin impacto esperado en datos.
PLAN: identificar widget, modificar solo texto, ejecutar formato/analyze/test relevante.
RIESGOS: tocar archivo equivocado o cambiar flujo.
PRUEBAS: widget/golden si existe, smoke manual.
ROLLBACK: revertir el archivo puntual.

AGENTE: 04-qa-regresion-sync
VEREDICTO: NO VALIDADO
VALIDACIONES: no ejecutadas en simulacion.
REGRESIONES: no evaluadas.
DATOS: sin impacto esperado.
SYNC: sin impacto esperado.
ACCIONES REQUERIDAS: ejecutar validaciones reales antes de cerrar una tarea real.

AGENTE: 05-seguridad-aislamiento
VEREDICTO: APROBADO CON OBSERVACIONES
RIESGOS: ninguno critico si solo cambia texto.
AISLAMIENTO: sin impacto esperado.
SECRETOS: sin impacto esperado.
MITIGACIONES: confirmar que no se expone configuracion ni datos privados en el texto.
```

Limitacion exacta:

- No se pudo comprobar invocacion automatica por nombre porque la CLI instalada no muestra comando ni schema publico para registrar subagentes ejecutables.
- Los perfiles estan preparados y versionados; el paso manual es pedir a Codex que lea el perfil correspondiente antes de emitir cada veredicto.
