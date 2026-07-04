# Contributing docs structure

Lay out `docs/contributing/` like this. Only create directories that are needed — a small project may only need a flat set of files directly under `howto/`.

```
docs/contributing/
  README.md                ← top-level: PR process, code of conduct link
  howto/
    README.md              ← index: one-line description of every guide
    setup.md               ← first-time clone: deps, dev shell, env
    building/
      build.md             ← how to compile / build
    testing/
      README.md            ← how to run the full test suite
    committing/
      README.md            ← branching model, commit style, pre-commit hook
    releasing/
      versioning.md
      release-build.md
    extending/             ← add when the project has extension points
```

## Rules

- `howto/README.md` must be a link index: one bullet per file with a one-line description.
- Each file covers exactly one topic. If a file grows past ~60 lines, split it.
- Use relative links everywhere, e.g. `[build.md](building/build.md)`.
- Write for both humans and LLMs: no fluff, all commands must be copy-pasteable.
- Command blocks must be runnable as-is from a stated working directory.

## howto/README.md pattern

```markdown
# How-to guides

- [setup.md](setup.md) — first-time clone: …

## building/
- [build.md](building/build.md) — …

## testing/
- [README.md](testing/README.md) — …
```

## docs/contributing/README.md pattern

```markdown
# Contributing

- [howto/setup.md](howto/setup.md) — get a working dev environment
- [howto/building/build.md](howto/building/build.md) — build the project
- [howto/committing/README.md](howto/committing/README.md) — commit and PR workflow

Commit style: [agents/skills/commit-style](path-to-commit-style-skill).
```
