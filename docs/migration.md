# Migration and Rollback

Language: [English](migration.md) | [Deutsch](migration.de.md)

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

```powershell
powershell -NoProfile -File .\bootstrap\bootstrap.ps1 --project-root C:\path\to\repo --dry-run
```

## Example: apply

```bash
./bootstrap/bootstrap.sh --project-root /path/to/repo --force
```

```powershell
powershell -NoProfile -File .\bootstrap\bootstrap.ps1 --project-root C:\path\to\repo --force
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

```powershell
powershell -NoProfile -File .\bootstrap\bootstrap.ps1 --project-root C:\path\to\repo --no-strict --force
```

## Windows link limitations

On Windows, bootstrap first tries symlinks, then hardlinks, then file copies.

- Hardlinks only work on the same drive (for example `C:` to `C:`).
- If your `agent-kit` is on `C:` and projects are on `D:`, hardlink fallback is
  not possible.
- In this case bootstrap can still complete by copying files.

If copied files are used and you later update `profiles/*.md` or `SKILLS.md`,
re-run bootstrap with `--force` to refresh project copies.

## Rollback

Rollback is file-based:

1. Restore previous symlink targets for workflow files.
2. Remove generated files if they did not exist before:
   - `.agent-workflow/state.env`
   - `workitems/INDEX.md`
   - `workitems/template.md`
3. Re-run your previous setup script if available.
