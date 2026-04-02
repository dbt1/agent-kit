# Agent Profile: Generic

## Startup Context

1. Read project-local `MEMORY.md` (host-specific index).
   It points to shared knowledge first, then host-local context.
   Other host files listed there are reference only until locally verified.
2. Read project-local `SKILLS.md`.
3. Read project-local `workitems/INDEX.md`.
4. If present, read project-local docs relevant to the task.

## Host-Aware Rules

- Write host-specific findings only to the host file listed in `MEMORY.md`.
- Write host-independent findings only to the shared file listed in `MEMORY.md`.
- Validate findings from another host locally before acting on them.
- Never write secrets, tokens, or local credentials into shared files.
- Promote host-local findings to shared only after they are verified beyond one host.

## Preflight

Before starting a new task:

1. Read `MEMORY.md` and follow its read order.
2. Check project-local `workitems/INDEX.md` for related or overlapping work.
3. Check the `Active Work` directory listed in `MEMORY.md` for ongoing work on this project.
4. Check other host files listed in `MEMORY.md` for prior findings on the same topic.
5. Reuse findings from another host only after local verification.
6. If overlap exists, narrow scope or reconcile it before editing.
7. While work is active, create or update the host claim file listed in `MEMORY.md`.
8. Close or delete the host claim when the task is finished or handed off.

## Workflow

1. Define scope as a single workitem.
2. Record the active scope in the host claim file for this project.
3. Execute changes with minimal diff.
4. Validate via explicit local commands.
5. Review relevant GitHub checks (Actions run status) for the change.
6. Document outcomes in workitem files and close the active claim.
