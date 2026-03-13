# Migration and Rollback

This guide is for repositories that already contain `AGENTS.md`, `CLAUDE.md`,
`MEMORY.md`, or other workflow files.

## Safe migration strategy

1. Run bootstrap in dry-run mode first.
2. Inspect what would change.
3. Apply only when expected.
4. Keep a simple before-state snapshot for rollback.

## Example: dry-run

```bash
./bootstrap/bootstrap.sh --project-root /path/to/repo --dry-run
```

## Example: apply

```bash
./bootstrap/bootstrap.sh --project-root /path/to/repo --force
```

Use `--force` only after verifying planned changes.

## Strict isolation behavior

By default, bootstrap blocks unmanaged files/symlinks in:

- `AGENTS.md`
- `CLAUDE.md`
- `GEMINI.md`
- `MEMORY.md`
- `SKILLS.md`

To bypass this for manual migration runs only:

```bash
./bootstrap/bootstrap.sh --project-root /path/to/repo --no-strict --force
```

## Rollback

Rollback is file-based:

1. Restore previous symlink targets for workflow files.
2. Remove generated files if they did not exist before:
   - `.agent-workflow/state.env`
   - `workitems/INDEX.md`
   - `workitems/template.md`
3. Re-run your previous setup script if available.
