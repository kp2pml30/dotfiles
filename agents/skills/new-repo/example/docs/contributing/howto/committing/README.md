# Committing

All commands run from the repo root.

## Hooks

```bash
nix develop   # installs git hooks, including the commit-msg check
```

Hooks then run on every `git commit`. Never pass `--no-verify`; fix what they report.

## Before Pushing

```bash
nix fmt          # format: runs all hooks over all files, fixing in place
nix flake check  # verify: same hooks read-only, plus every flake check, as CI does
```

Rerun `nix fmt` until it reports no changes. `nix flake check` only sees files tracked by git: `git add` new files first.

## Commit Message

`<type>(<scope>): <subject> [emoji...]` -- checked by `support/scripts/check-commit-message.py` on the `commit-msg` stage, which `nix fmt` and `nix flake check` skip. Check a message ahead of time:

```bash
python3 support/scripts/check-commit-message.py --message-text 'feat(cli): add --dry-run'
```
