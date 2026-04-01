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

## Workflow

1. Define scope as a single workitem.
2. Execute changes with minimal diff.
3. Validate via explicit local commands.
4. Review relevant GitHub checks (Actions run status) for the change.
5. Document outcomes in workitem files.
