---
name: fj
description: Use when working with Forgejo repositories through the `fj` CLI — creating, searching, commenting on, or closing issues; opening and merging pull requests; inspecting repos, labels, or releases. Also use when a task says to file or track issues in a repo whose remote is a Forgejo instance (not github.com).
---

# fj — the Forgejo CLI

`fj` is to Forgejo what `gh` is to GitHub. Reach for it whenever the repo's
`origin` points at a Forgejo host rather than github.com. Check with
`git remote -v` if unsure; `gh` will not work against those hosts.

## Non-negotiables

- **Long bodies go through `--body-file`, never `--body`.** Omitting both opens
  `$EDITOR`, which hangs a non-interactive session forever. Write the body to a
  scratch file first, then pass it. This applies to `issue create`,
  `issue comment`, `pr create`, and `pr comment`.
- **`--body` is not uniform.** `issue create` and `pr create` take `--body`;
  `issue comment` and `pr comment` do **not** — their body is a positional
  argument after the number. `fj issue comment 12 --body "text"` fails with a
  bare usage error that does not say why. `--body-file` works everywhere, which
  is another reason to default to it.
- **`fj` has no `--version` flag.** Use `fj version` (prints e.g. `fj v0.5.0`).
  Probing with `--version` exits non-zero and prints a usage error.
- **Markdown in bodies is literal.** Write real newlines in the file; do not
  escape them.

```bash
# The pattern to use every time
cat > /tmp/scratch/body.md <<'EOF'
Multi-paragraph description with `code` and lists.
EOF
fj issue create "Short imperative title" --body-file /tmp/scratch/body.md
```

Only inline `--body` for a genuine one-liner with no shell metacharacters.

## Issues

```bash
fj issue search                          # open issues (the default state)
fj issue search -s all                   # or: open | closed | all
fj issue search "query" -l bug -a someone
fj issue view 12                         # body plus comments
fj issue create "Title" --body-file b.md
fj issue comment 12 --body-file c.md     # or: fj issue comment 12 "one-liner"
fj issue close 12
fj issue assign 12 someone
fj issue edit 12
```

`fj issue create` prints `created issue #N: <title>`; parse the number from
there when you need to cross-reference it. `fj issue close` prints
`Closed issue N: "<title>"`.

The issue number is always a **positional** argument — to `comment`, `close`,
`view`, and `assign` alike.

## Pull requests

```bash
fj pr create "Title" --base main --head my-branch --body-file b.md
fj pr create -A                # autofill title and body from the commits
fj pr search
fj pr view 5
fj pr status 5                 # mergeability plus CI
fj pr checkout 5               # into a new local branch
fj pr merge 5
fj pr close 5                  # without merging
```

`-A/--autofill` is the fast path when the branch's commit messages already say
what the PR should: a single commit becomes the title and body verbatim.

Prefix a title with `WIP: ` to open it as a draft.

## Repos, labels, releases

```bash
fj repo view / readme / clone / fork / create / edit / delete
fj repo labels                 # manage issue labels
fj release create / edit / list
fj tag ...
fj wiki ...
fj actions ...
```

## Selecting the target repo

Most subcommands accept:

- `-R, --remote <REMOTE>` — the local git remote to resolve (default `origin`).
- `-r, --repo <REPO>` — an explicit `owner/name`, for acting outside the cwd.

Global flags go **before** the subcommand: `fj -H host.example issue search`.

## Auth

```bash
fj whoami                      # confirms the signed-in account and host
fj auth login
fj auth list
fj auth add-key
```

If a command fails with an auth error, run `fj whoami` first — the session may
be scoped to a different instance than the repo's remote.

## Output style

`fj --style minimal ...` drops colour and box-drawing characters. Piped output
is already minimal, so this only matters when you want plain text on a TTY.
