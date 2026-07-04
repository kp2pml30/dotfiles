# New Repo Skill

Bootstrap a new repository from scratch. Work through the checklist below in order.

## Checklist — root files

Copy or create the following at the repo root:

| File | Source / action |
|---|---|
| `README.md` | write; follow [standard-readme format](#readme) |
| `LICENSE` | GPL-3.0 by default; match `README.md` badge |
| `.gitignore` | copy [`default-configurations/gitignore`](../../default-configurations/gitignore); append project-specific entries |
| `.gitattributes` | create from [`default-configurations/gitattributes`](../../default-configurations/gitattributes) |
| `.dockerignore` | create from [`default-configurations/dockerignore`](../../default-configurations/dockerignore) |
| `.editorconfig` | copy [`default-configurations/.editorconfig`](../../default-configurations/.editorconfig) verbatim |
| `.pre-commit-config.yaml` | copy [`default-configurations/.pre-commit-config.yaml`](../../default-configurations/.pre-commit-config.yaml); **remove** hooks for languages/tools not in the project |
| `flake.nix` | write; provide at minimum a `devShell` and a default package |

## README

Follow <https://github.com/richardlitt/standard-readme>. Required sections in order:

1. `# Title` — matches repo name
2. One-sentence tagline below the title
3. Badges (CI, license) — optional but recommended
4. `## Background` — 1–3 sentences: why this exists (omit if obvious)
5. `## Install`
6. `## Usage`
7. `## Contributing` — one line linking to `docs/contributing/`
8. `## License` — `GPL-3.0 © <year> <author>`

## Docs

All docs live under `docs/`. Files are Markdown by default. Write brief and precise: one file = one feature or how-to. Links must be relative (`[other.md](../other.md)`).

```
docs/
  contributing/
    README.md          ← overview + link index
    howto/             ← see templates/contributing-structure.md
```

See [`default-configurations/contributing-structure.md`](../../default-configurations/contributing-structure.md) for how to lay out `docs/contributing/howto/`.

## .gitattributes rules

Mark binary, vendored, and generated files so GitHub Linguist handles them correctly. See [`default-configurations/gitattributes`](../../default-configurations/gitattributes) for the base template — extend it with project-specific entries.

Key patterns:

```gitattributes
# vendored
vendor/**  linguist-vendored
*.onnx     linguist-vendored

# generated
*.generated.*  linguist-generated
```

## Nix / flake.nix

Package with nix. Minimal `flake.nix` must expose:
- `packages.default` — the main build output
- `devShells.default` — dev shell with all build-time deps

## Pre-commit

Base config is [`default-configurations/.pre-commit-config.yaml`](../../default-configurations/.pre-commit-config.yaml). Strip hooks that do not apply (e.g. remove `clang-format` if no C/C++, remove `ruff-format` if no Python). Never add new hook versions without verifying they exist upstream.




Project Path: /home/kp2pml30/work/genlayer/genvm-manager/docs/contributing/howto

Source Tree:

```
howto
├── README.md
├── committing
│   ├── git-third-party.md
│   ├── submodules.md
│   └── runners.md
├── testing
│   ├── python.md
│   ├── README.md
│   ├── rust.md
│   ├── fuzzing.md
│   └── integration.md
├── genvm-tool.md
├── setup.md
├── extending
│   ├── modify-runner.md
│   ├── modify-wasmtime.md
│   ├── add-host-function.md
│   ├── add-wasi-function.md
│   └── add-llm-provider.md
├── building
│   ├── build.md
│   ├── docs.md
│   └── runners.md
└── releasing
    ├── versioning.md
    └── release-build.md

```

`/home/kp2pml30/work/genlayer/genvm-manager/docs/contributing/howto/README.md`:

```````md
# How-to guides

- [setup.md](setup.md) — first-time clone: submodule init, nix/direnv dev shell, third-party materialization.
- [genvm-tool.md](genvm-tool.md) — command overview, codegen data → generated files, plugin/test-definition layout.

## building/
- [build.md](building/build.md) — debug build: configure + ninja, outputs, cargo quirks.
- [runners.md](building/runners.md) — where runners come from (build vs download).
- [docs.md](building/docs.md) — building the website, spec vs impl-spec, ADRs.

## testing/
- [testing/README.md](testing/README.md) — `genvm-tool test` itself: filters, presets, continue files.
- [rust.md](testing/rust.md) — Rust tests, `#rust-test` shell, coverage.
- [python.md](testing/python.md) — Python tests, direct pytest for genlayer-py-std.
- [integration.md](testing/integration.md) — running one executor line, `stable` (offline) subset, golden `.stdout`/`.hash` files, `--ignore-hash`, services.
- [fuzzing.md](testing/fuzzing.md) — AFL fuzz targets, host sysctl prep.

## committing/
- [submodules.md](committing/submodules.md) — manager + executor lines, gitlink bumps, pre-commit hook, push order.
- [git-third-party.md](committing/git-third-party.md) — how vendored trees (wasmtime, …) are tracked, edited, and committed as patches.

## releasing/
- [versioning.md](releasing/versioning.md) — release trains, `.genvm-monorepo-root`, check-versions/branch-versions scripts.
- [release-build.md](releasing/release-build.md) — nix packages, platforms, release assets.

## extending/
- [add-llm-provider.md](extending/add-llm-provider.md) — new LLM backend in the manager.
- [add-wasi-function.md](extending/add-wasi-function.md) — new gl_call method or raw WASI function in an executor.
- [add-host-function.md](extending/add-host-function.md) — new executor↔host protocol method.
- [modify-runner.md](extending/modify-runner.md) — runner dev-mode and hash refresh.
- [modify-wasmtime.md](extending/modify-wasmtime.md) — patching vendored wasmtime, trap plumbing.

```````

`/home/kp2pml30/work/genlayer/genvm-manager/docs/contributing/howto/committing/git-third-party.md`:

```````md
# git-third-party (vendored trees)

Vendored third-party sources (e.g. `executors/v0.3.x/executor/third-party/wasmtime`,
`.../wasm-tools`) are **not** tracked by the executor repo — they are
git-ignored (`executor/.gitignore: third-party`) and materialized on demand.
What *is* tracked, per executor line, is `.git-third-party/`:

- `.git-third-party/config.json` — per repo: upstream `url`, pinned base
  `commit`, `patches` count, optional `submodules` list (absent = update all
  submodules, `[]` = none, list = only those).
- `.git-third-party/patches/<repo-path>/<n>` — numbered `git format-patch`
  files (1-based, mbox format) applied on top of the base commit.

The tool is `support/tools/git-third-party/git-third-party` (single Python
script; on PATH via `env.sh` and the dev shell; invoked as `git third-party`).
It has **no `--help`** — running with no subcommand prints usage. Subcommands:

| Command | Effect |
|---|---|
| `git third-party add <PATH> <REPO_URL> <COMMIT>` | register a new vendored repo (path must already be git-ignored) and materialize it |
| `git third-party update {--all \| <path>...}` | materialize: nested `git init`+fetch of the pinned commit, submodule update, then `git am` the patches |
| `git third-party save {--all \| <path>...}` | regenerate patch files from commits above the base commit; updates the count in `config.json` |

`update` refuses to run on a dirty vendored tree. The materialized tree is a
real nested git repo whose history is `base commit` + one commit per patch.

## Editing a vendored tree (e.g. a wasmtime patch)

1. Edit files in `executors/<line>.x/executor/third-party/wasmtime` and
   **commit inside that nested repo** (normal `git commit`; patches are derived
   from history above the base commit).
2. `git third-party save executor/third-party/wasmtime` (path relative to cwd) —
   rewrites `.git-third-party/patches/...` deterministically
   (`format-patch --zero-commit --no-signature --numbered-files`).
3. In the executor repo: `git add .git-third-party/`, commit, push.
4. In the manager: bump the gitlink ([submodules.md](submodules.md)).

The nested repo itself is never pushed — only the patch files persist.

To bump the pinned upstream version: edit `commit` in `config.json`, then
`git third-party update <path>` (patches are re-applied with `git am`; resolve
conflicts by fixing up the nested repo's commits and running `save`).

## Build integration

- Local/CI checkouts run `git third-party update --all` **inside each executor
  submodule** — the config is resolved from the current git toplevel, so running
  it once at the manager root materializes nothing (CI:
  `.github/actions/get-src/action.yaml`; local: [setup.md](../setup.md)).
- Nix does **not** call the tool: `support/nix/git-third-party.nix` re-reads
  `config.json` and uses `builtins.fetchGit` + `pkgs.applyPatches`, mounted into
  the source layout by `support/default.nix`. So nix builds see exactly the
  committed base commit + patches — another reason to `save` and commit before
  building flake packages.

```````

`/home/kp2pml30/work/genlayer/genvm-manager/docs/contributing/howto/committing/submodules.md`:

```````md
# Submodules (multi-repo workflow)

## Topology

- **Manager (umbrella)** — this repo (`genlayerlabs/genvm-manager`): `flake.nix`,
  `implementation/`, `runners/`, `support/tools/genvm-tool`, `install/`.
- **Executor submodules** — `executors/v0.2.x`, `executors/v0.3.x`: checkouts of
  the **same** repo (`genlayerlabs/genvm-executor`) on different branches (see
  `.gitmodules`). Each line's `manifest.json` owns its `executor-version`.
- `.genvm-monorepo-root` lists the active lines and the manager's `version` —
  see [versioning.md](../releasing/versioning.md).

Branch model: manager `feat/<name>` (base usually `v<X>-dev`); each executor
submodule `pr/<line>/feat/<name>`.

## The critical nix flag

Every flake ref needs `?submodules=1` (`nix develop '.?submodules=1#full'`,
`nix build '.?submodules=1#genvm'`). Flake packages only see **committed**
submodule files — commit inside the submodule before building packages.

## Committing across repos (order matters)

The manager pins each submodule by a **gitlink** (a pinned commit):

1. Commit **inside** the submodule: `cd executors/<line>.x && git add … && git commit`.
2. In the manager, bump the gitlink: `git add executors/<line>.x`.
3. Commit the manager (code + gitlink bumps together).

Verify consistency:

```bash
git ls-tree HEAD executors/v0.2.x executors/v0.3.x   # pinned gitlinks
git -C executors/v0.3.x rev-parse HEAD               # must match
```

To reshape unpushed history: `git reset --mixed <base>`, re-stage per commit,
re-bump the gitlink to the new submodule HEAD.

## Pre-commit hook (cross-repo)

`git commit` triggers `genvm-tool hook run`, which fans linters/formatters out
to the manager **and** submodules.

- Everything at once: `genvm-tool hook run --all-files` (default `--fix`
  rewrites; `--check` only verifies — what CI uses).
- `git commit --no-verify` skips the hook — fine for pure gitlink bumps or
  already-formatted content.
- After changing genvm-tool itself: `genvm-tool hook install` rebuilds the tool
  and rewrites the hook stubs. A hook crash referencing an old
  `/nix/store/...genvm-tool` means a stale dev-shell `PYTHONPATH` — refresh the
  dev env or re-run `hook install` with `PYTHONPATH` unset.

## Pushing

Check first: `genvm-tool git check-for-push` (`--offline` compares against the
last fetch). Push **submodules before the manager** so gitlinks resolve:

```bash
git -C executors/v0.2.x push origin pr/v0.2/feat/<name>
git -C executors/v0.3.x push origin pr/v0.3/feat/<name>
git push origin feat/<name>
```

After rebasing the manager onto its base (e.g. `origin/v0.6-dev`), it diverges:
use `git push --force-with-lease origin feat/<name>`. Executor feature branches
are normally ahead-only (plain fast-forward push).

For runner hash hygiene before committing (dev-mode, `hash-updater.py`), see
[runners.md](runners.md).

## Runner trees (why there are two)

Forward-rolling lines (v0.3.x) share the top-level `runners/<id>/<aa>/<rest>.tar`
tree (Crockford base32 of `sha256(tar)`). Frozen v0.2.x keeps runners under
`executor/<version>/legacy-runners/` with **Nix base32** hashes — a different
scheme, hence the separate trees. `flake.nix` packaging splits the runner list
per line; `genvm check` verifies each with its own scheme.

```````

`/home/kp2pml30/work/genlayer/genvm-manager/docs/contributing/howto/committing/runners.md`:

```````md
# Committing runner changes

Runner sources and version pins live inside the executor submodule
(`executors/<line>.x/`). All paths below are relative to that submodule root.

## Dev mode

During development `runners/support/versions/dev-mode.nix` may be `true` and
runner hashes in `runners/support/versions/current.nix` may be `"test"`.
**Neither must reach a commit.**

Before committing:

1. Set `dev-mode.nix` back to `false`.
2. Set "test" hash to `null` in `current.nix`.
3. Run `runners/support/versions/hash-updater.py` (from anywhere inside the
   repo) to recompute real hashes. It builds `#runners-all` with
   `--keep-going`, writes every reported `got:` value back into `current.nix`,
   and repeats until fixed point. Hashes are content-addressed and depend on
   resolved dependency uids, so they must be discovered bottom-up — the script
   handles that automatically.
4. Commit once all hashes are real `sha256-…` values.

**Never restore an old hash value manually.** It becomes wrong the moment any
source or dependency changes; only `hash-updater.py` produces a correct value.

See [modify-runner.md](../extending/modify-runner.md) for the full
runner-modification workflow.

```````

`/home/kp2pml30/work/genlayer/genvm-manager/docs/contributing/howto/testing/python.md`:

```````md
# Python tests

```bash
genvm-tool test run --filter-tag python
```

## Direct pytest (genlayer-py-std, no dev shell)

```bash
cd runners/genlayer-py-std
env_dir="$(nix build --no-link --print-out-paths path:../../support/nix/py-test)"
PYTHONPATH="$PWD/src:$PWD/src-emb" "$env_dir/bin/pytest" tests/
```

Coverage is enforced (`--cov-fail-under=75`); numpy-dependent tests need the
nix env.

```````

`/home/kp2pml30/work/genlayer/genvm-manager/docs/contributing/howto/testing/README.md`:

```````md
# Test

All tests run through `genvm-tool test`. Build first
([build.md](../building/build.md)). Commands assume the `#full` dev shell.

Per-kind guides: [rust.md](rust.md) · [python.md](python.md) ·
[integration.md](integration.md) · [fuzzing.md](fuzzing.md).

## Quick reference

| What | Command |
|---|---|
| All tests | `genvm-tool test run` |
| Release preset | `genvm-tool test run --filter-tag "$(cat tests/presets/release.txt)"` |
| One test | `genvm-tool test run --filter-name 'test_name'` |
| Re-run failed | `genvm-tool test run --filter-continue <file>` |
| List tests / plan / tags / services | `genvm-tool test show test\|plan\|tags\|services` |

Options: `--filter-name REGEX`, `--filter-tag EXPR` (e.g. `stable & !slow`),
`--filter-continue FILE`, `--fail-fast`, `--coverage`,
`--log-level {trace,debug,info,warning,error}`, `--ignore-hash`.

Presets in `tests/presets/`: `release.txt` (`integration & stable & !bench`),
`rust.txt` (`(rust | integration) & !bench & !fuzz`), `rust-fuzz.txt`
(`rust & fuzz`), `python.txt` (`python`).

Common tags are documented in [integration.md](integration.md);
`genvm-tool test show tags` lists everything.

## Fix–rerun loop: use continue files

Every failed run writes the failing test names to
`build/test-artifacts/continue/<timestamp>-<random>` (the name is printed in
the failure summary). **After fixing something, rerun just those tests first**
— much faster than a full rerun:

```bash
genvm-tool test run --filter-continue <name-or-path>
```

Do a full run only once the continue set passes.

## Configuration

Test-suite configuration (artifacts dir, python paths) comes from
`.genvm-monorepo-root`; the suite itself is the `tests` function in
`.genvm-tool.py`. Test definitions live in `tests/system/<name>/test.py` —
see [genvm-tool.md](../genvm-tool.md).

```````

`/home/kp2pml30/work/genlayer/genvm-manager/docs/contributing/howto/testing/rust.md`:

```````md
# Rust tests

```bash
genvm-tool test run --filter-tag rust            # add --coverage for coverage
```

If a Rust test fails to load a shared library under the `#full` shell, use the
dedicated shell:

```bash
nix develop '.?submodules=1#rust-test' --command genvm-tool test run --filter-tag rust
```

Tests live in the executor crates (inline `#[cfg(test)] mod tests` and each
crate's `tests/`); `genvm-tool test` discovers them. Preset:
`tests/presets/rust.txt` (`rust | integration`).

```````

`/home/kp2pml30/work/genlayer/genvm-manager/docs/contributing/howto/testing/fuzzing.md`:

```````md
# Fuzzing

Rust fuzz targets run under AFL (`cargo-afl`):

```bash
genvm-tool test run --filter-tag "$(cat tests/presets/rust-fuzz.txt)"   # rust & fuzz
```

Python fuzz targets exist but their collection is currently disabled in
`.genvm-tool.py`. Some integration cases also carry the `fuzz` tag.

Options: `--fuzz-timeout N` (seconds per run, default 30),
`--fuzz-update-corpus` (write back interesting inputs).

## Host preparation

AFL needs these before a session (crashes must land as files, CPU frequency
must be stable, and the fuzzer must be able to ptrace):

```bash
echo core | sudo tee /proc/sys/kernel/core_pattern
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope
```

```````

`/home/kp2pml30/work/genlayer/genvm-manager/docs/contributing/howto/testing/integration.md`:

```````md
# Integration tests

```bash
genvm-tool test run --filter-tag integration
```

Cases are `.jsonnet` files in `executors/<line>.x/tests/integration/`; each
produces a `<name>/prepare` case plus one case per step (`/0l`, `/0v`, `/0s`, …).
A sibling `.skip` file marks a case skipped. The suite iterates every line in
`active-versions` (`.genvm-monorepo-root`) and runs each line's cases against
that line's own built executor (`build/info.json` maps `v0.3` → the concrete
built version).

## Common tags

| Tag | Meaning |
|---|---|
| `stable` | needs **no LLM keys and no webdriver** (manager only) — safe to run offline |
| `unstable`, `semi-stable` | need modules + webdriver; `unstable` is retried (3 attempts), `semi-stable` is not |
| `bench` | benchmarks — excluded from the presets |

## Running a subset

- **One executor line** — test names are repo-relative paths and
  `--filter-name` is an unanchored regex, so:
  `genvm-tool test run --filter-name 'executors/v0.3.x/'`
- **Offline / no LLMs / no web** — the `stable` tag marks tests needing only
  the manager (no modules, no webdriver; the executor is told `no_modules`):
  `--filter-tag 'integration & stable'` (`tests/presets/release.txt`
  additionally excludes `bench`). Stability is the second argument of
  `util.features(paths, stability)` in the case's jsonnet `tags`
  (`'stable'` / `'semi-stable'` / `'unstable'`). (Legacy: v0.2.x instead uses a
  `stable/` top-level directory.)
- **After a fix** — rerun only the failed cases via the continue file:
  `--filter-continue <file>` (see [README.md](README.md)).

## Golden files and hashes

Goldens live next to the cases (`*.N.stdout`). A missing golden is
auto-created on the first run; after that a mismatch **fails** the test —
delete the sidecar to regenerate it.

With `stable_hash: true` on a step entry (the default) the leader's execution
hash is likewise compared against an auto-created `.N.hash` sidecar; with
`stable_hash: false` there is no sidecar and validators compare to the
leader's runtime hash instead.

`--ignore-hash` skips hash comparison *and* sidecar creation (a new case does
NOT need it — its hash is auto-created). Use it when hashes legitimately
differ, e.g. **runner dev mode**
([modify-runner.md](../extending/modify-runner.md)): a modified runner changes
runner hashes and therefore every execution hash. An executor line can also
disable hash checks wholesale via `integration()` in its `.genvm-tool.py`
returning `{'ignore-hash': True}` — currently the case for v0.3.x.

## Services

The manager, modules (LLM/web), and webdriver services start automatically;
`--no-manager` / `--no-webdriver` use externally running ones instead. Manual
webdriver: `bash webdriver/build-and-run.sh`. If WASM files changed,
`./build/out/executor/<version>/bin/genvm precompile` saves test time.

```````

`/home/kp2pml30/work/genlayer/genvm-manager/docs/contributing/howto/genvm-tool.md`:

```````md
# genvm-tool

Lives at `support/tools/genvm-tool` (on PATH as `genvm-tool` in the dev shell;
outside it, call `support/tools/genvm-tool/genvm-tool`).

## Commands

| Command | Purpose |
|---|---|
| `configure` | generate `build/build.ninja` + `build/info.json` — [build.md](building/build.md) |
| `test` | run the test suite — [testing/README.md](testing/README.md) |
| `codegen` | generate language bindings from data JSON (below) |
| `build-manifest` | generate the manager's `data/manifest.yaml` |
| `git ls` / `list-repo` / `create-branches` / `check-for-push` | git helpers across manager + submodules — [submodules.md](committing/submodules.md) |
| `hook run` / `hook install` | cross-repo pre-commit fan-out / stub installer — [submodules.md](committing/submodules.md) |

Command registration: `genvm_tool/__main__.py` (`TOPLEVEL`, `GROUPS`); each
command module has `NAME`/`HELP` — look there for details.

## codegen

```bash
genvm-tool codegen --lang {rust,python,rst,go} -i <data.json> -o <out>
```

(`--go-package` selects the go package name, default `genvm`.)

Codegen data lives per executor line at
`executors/v<X>.x/executor/codegen/data/{public-abi.json,host-fns.json}`.
After editing the JSON, regenerate via the build (`genvm-tool configure` then
`ninja -C build codegen`) or run `genvm-tool codegen` by hand per the tables:

Per-line generated files (registered by `register_standard_codegen` in
`tests/runner/genvm_tool_plugins/ninja.py`, paths relative to the line root):

| Output | Input | Lang |
|---|---|---|
| `executor/crates/sdk-rs/src/abi/consts.rs` | `public-abi.json` | rust |
| `runners/genlayer-py-std/src/genlayer/vm/public_abi.py` | `public-abi.json` | python |
| `executor/crates/common/src/host_fns.rs` | `host-fns.json` | rust |

Manager-global generated files (from the **primary** line's data, wired in
`genvm_tool/cmd_configure.py`) — these go stale when a line's codegen JSON
changes and are refreshed by the same configure/ninja codegen step:

| Output | Input | Lang |
|---|---|---|
| `tests/runner/origin/host_fns.py` | `host-fns.json` | python |
| `tests/runner/origin/public_abi.py` | `public-abi.json` | python |
| `docs/website/src/spec/appendix/constants.rst` | `public-abi.json` | rst |

## Plugins and test definitions

Plugins (`tests/runner/genvm_tool_plugins/`) are **importable libraries** —
reusable build/test helpers, no side effects on import. Test *definitions* are
kept out of the plugin package: each lives in `tests/system/<name>/test.py`
exposing `collect(ctx, **kwargs)`, and is registered from `.genvm-tool.py` via
`ctx.collect_dir('tests/system/<name>', ...)` (discovery:
`genvm_tool/tests/stage/collection.py`). The project entry point overall is
`.genvm-tool.py` at the repo root (each executor line has its own).

```````

`/home/kp2pml30/work/genlayer/genvm-manager/docs/contributing/howto/setup.md`:

```````md
# First-time setup

1. Init the executor submodules **before** entering the dev shell (the nix flake reads them):

   ```bash
   git submodule update --init --recursive --depth 1
   ```

2. Enter the dev shell:

   ```bash
   nix develop '.?submodules=1#full'
   ```

   `?submodules=1` is required on **every** flake ref — without it:
   `Path 'executors/v0.3.x' … is not tracked by Git`. Usually auto-loaded via
   direnv (`.envrc` is `use flake '.?submodules=1#full'`).

3. `source env.sh` — adds `support/tools/git-third-party` to PATH and sources
   `.env` if present. Only needed outside the dev shell.

4. Materialize the vendored third-party trees (wasmtime, wasm-tools). These are
   registered per executor submodule, and `git third-party` reads its config
   from the current git toplevel — so run it *inside each executor*, not at the
   manager root (which has no config and would materialize nothing):

   ```bash
   for cfg in executors/*/.git-third-party/config.json; do
     ( cd "$(dirname "$(dirname "$cfg")")" && git third-party update --all )
   done
   ```

   See [git-third-party.md](committing/git-third-party.md) for how vendoring works.

Next: [build.md](building/build.md).

```````

`/home/kp2pml30/work/genlayer/genvm-manager/docs/contributing/howto/extending/modify-runner.md`:

```````md
# Modifying a runner

Runner sources and version pins live per executor line; paths below are
relative to `executors/<line>.x/`.

1. Set `runners/support/versions/dev-mode.nix` to `true` and the runner's hash
   in `runners/support/versions/current.nix` to `"test"`; develop and test.
2. Set dev-mode back to `false`; set the changed runner's hash (and its
   dependents') to `null`.
3. Refresh hashes with `runners/support/versions/hash-updater.py` (run from
   anywhere inside the repo): it builds `#runners-all` with `--keep-going`,
   writes every reported `hash mismatch … got:` value back into `current.nix`,
   and repeats until fixed point. Hashes depend on dependencies' resolved uids,
   so they must be discovered in dependency order — the script handles that.

   Manual alternative: `ninja -C build all`, copy the `got:` hash from the
   error into `current.nix`, repeat per dependent runner.
4. Rebuild to verify no mismatches remain.

```````

`/home/kp2pml30/work/genlayer/genvm-manager/docs/contributing/howto/extending/modify-wasmtime.md`:

```````md
# Modifying vendored wasmtime

The tree at `executors/<line>.x/executor/third-party/wasmtime` is a
git-third-party clone (upstream pin + genvm patches) — mechanism and commit
workflow: [git-third-party.md](../committing/git-third-party.md).

Edit the tree directly; `cargo check`/ninja build it in-tree, so iteration is
normal Rust development. Two caveats:

- **Nix builds don't see working-tree edits** — they apply the saved patches
  (`support/nix/git-third-party.nix`). Run `git third-party save` before any
  nix build/release must pick the change up.
- Commit flow: commit inside the nested wasmtime repo →
  `git third-party save executor/third-party/wasmtime` → commit
  `.git-third-party/` in the executor repo → gitlink bump in the manager.

## genvm patch points

- Custom trap variant `Trap::NondetInstruction`
  (`crates/environ/src/trap_encoding.rs`) — raised for instructions disallowed
  in deterministic mode (e.g. unmapped float/SIMD ops); emitted via
  `trap_nondet_instruction` (`crates/cranelift/src/func_environ.rs`) from
  `float_op_unreachable_check` (`crates/cranelift/src/translate/code_translator.rs`).
- When adding a `Trap` variant: update the `check!` macro in `from_u8` and its
  `Display` arm (see the comment at the enum), the `TRAP_*` const in
  `crates/cranelift/src/lib.rs`, and the executor-side remap to a public VM
  error code in `executor/src/rt/errors.rs` (`trap_to_vm_error`).

```````

`/home/kp2pml30/work/genlayer/genvm-manager/docs/contributing/howto/extending/add-host-function.md`:

```````md
# Adding a host function

1. `executors/<line>.x/executor/codegen/data/host-fns.json` — add the method
   id, then regenerate (`ninja -C build codegen`); this updates
   `executor/crates/common/src/host_fns.rs` (per line) and the manager's
   `tests/runner/origin/host_fns.py` — see [genvm-tool.md](../genvm-tool.md).
2. `tests/runner/origin/base_host.py` — handle the new case in the read loop
   and add the method to the `IHost` protocol. NOTE: `origin/` is mirrored
   into the node (`backend/node/genvm/origin/`).
3. `tests/runner/gvm_extra/mock_host.py` — add the test implementation.
4. Update the node (and simulator) host implementations.

```````

`/home/kp2pml30/work/genlayer/genvm-manager/docs/contributing/howto/extending/add-wasi-function.md`:

```````md
# Adding a WASI function to an executor

Paths are relative to `executors/<line>.x/`.

## Via gl_call (preferred — no ABI surface change)

1. `executor/crates/sdk-rs/src/abi/gl_call.rs` — add the message shape.
2. `executor/src/wasi/genlayer_sdk.rs` — implement the handler; add a version
   check so older contracts don't observe the new method.

New gl_call methods are a minor-compatible ABI addition — see the
[versioning spec](../../../website/src/spec/01-core-architecture/03-versioning.rst).

## Raw WASI function (new ABI surface)

1. `executor/src/wasi/witx/genlayer_sdk.witx` — add the declaration.
2. `executor/src/wasi/genlayer_sdk.rs` — add the implementation (under the
   generated `impl` trait).
3. `runners/cpython/modules/_genlayer_wasi/genlayer.c` — add the Python proxy.
   This changes the cpython runner hash — refresh it per
   [modify-runner.md](modify-runner.md).

```````

`/home/kp2pml30/work/genlayer/genvm-manager/docs/contributing/howto/extending/add-llm-provider.md`:

```````md
# Adding an LLM provider

If the provider is OpenAI-API-compatible, no work is needed.

Otherwise (all in the manager's `implementation/src/llm/`):

1. `providers.rs` — declare and implement the provider (`impl Provider`);
   a separate json mode is recommended.
2. `config.rs` — add a `Provider` enum value and a `BackendConfig::to_provider`
   case.

Test (optional): add a case to `implementation/src/llm/handler.rs`, patch
`.github/workflows/queue.yaml` to pass the API-key secret, and provide the key
to the repository owners.

```````

`/home/kp2pml30/work/genlayer/genvm-manager/docs/contributing/howto/building/build.md`:

```````md
# Build (debug)

All commands assume the dev shell (`nix develop '.?submodules=1#full'`, usually
via direnv) — it provides `genvm-tool`, `ninja`, `cargo`, `python3`.
First-time clone: [setup.md](../setup.md).

```bash
genvm-tool configure   # generates build/build.ninja + build/info.json (like CMake)
ninja -C build all/bin
```

Outside the dev shell call `support/tools/genvm-tool/genvm-tool configure`.

Re-run `genvm-tool configure` after adding/removing/renaming source files —
symptom if you forget: ninja `missing and no known rule to make it`.

| Ninja target | Builds |
|---|---|
| `all` | everything (incl. runners; x86_64 Linux only) |
| `all/bin` | all Rust binaries |
| `all/data` | runner data via nix |
| `codegen` | code generation (see [genvm-tool.md](../genvm-tool.md)) |

Outputs under `build/out`:

- `bin/genvm-modules` — modules binary
- `executor/<version>/bin/genvm` — one dir per built executor version; the
  version comes from `executors/<line>.x/manifest.json` and is recorded in
  `build/info.json`

Release/nix packages: [release-build.md](../releasing/release-build.md).
Getting or changing runners: [runners.md](runners.md), [modify-runner.md](../extending/modify-runner.md).

## Cargo notes

- Plain `cargo` inside a submodule needs the dev-shell env (lua, pkg-config, …);
  prefer the ninja build.
- In this nix environment, `cargo check` inside an executor's `executor/` dir
  may need `LD_LIBRARY_PATH="$(nix eval --raw nixpkgs#zlib)/lib"` so rustc
  finds libz.

```````

`/home/kp2pml30/work/genlayer/genvm-manager/docs/contributing/howto/building/docs.md`:

```````md
# Docs

## Website (`docs/website`)

Sphinx site with a poetry env in that dir:

```bash
cd docs/website
poetry install --no-root
poetry run sphinx-build -q -b dirhtml src <out>
```

CI builds `-b html` and `-b text` — see `support/ci/pipelines/src/docs.sh`
(also merges the text output into `_static/ai/*.txt`).

Source layout under `docs/website/src/`:

- `spec/` — the protocol specification (observable behavior).
  `spec/appendix/constants.rst` is **generated** from codegen data — do not
  edit by hand, see [genvm-tool.md](../genvm-tool.md).
- `impl-spec/` — the implementation specification (how this codebase does it).
- `python-sdk/`, `overview/` — SDK API docs and intro material.

`docs/website/generate.py` regenerates derived pages (runner/version tables)
from the repo state; wired into the build via `docs/website/yabuild.rb`.

## ADRs

Architecture decision records live in [`docs/adr/`](../../../adr/) as numbered markdown files
(`000. WASI.md`, …); start new ones from [`docs/adr/_template.md`](../../../adr/_template.md).

## Contributor docs

[`docs/contributing/`](../..) — PR requirements and workflows; how-to guides are in
this directory.

```````

`/home/kp2pml30/work/genlayer/genvm-manager/docs/contributing/howto/building/runners.md`:

```````md
# Runners

Runners build only on x86_64 Linux (part of the `all` ninja target /
`#runners-all` nix attr). On other hosts, download them:

```bash
python3 build/out/bin/post-install.py --create-venv false --default-step false --runners-download true --error-on-missing-executor false
```

or fetch `genvm-runners-all.tar.xz` from a
[genvm-manager release](https://github.com/genlayerlabs/genvm-manager/releases)
and extract it over `build/out`.

Do **not** build runners natively on macOS — deterministic runner artifacts
require a Linux builder (remote nix builder or download).

Changing a runner: [modify-runner.md](../extending/modify-runner.md).

```````

`/home/kp2pml30/work/genlayer/genvm-manager/docs/contributing/howto/releasing/versioning.md`:

```````md
# Versioning and release trains

`.genvm-monorepo-root` (repo root, JSON) is the source of truth:

- `version` — the manager's own release version (e.g. `v0.6.0-rc0`).
- `active-versions` — the live release trains (e.g. `["v0.3", "v0.2"]`); each
  train maps to an `executors/v<X>.x` submodule line.

Executor crates are versioned **independently** in their submodules (each
line's `manifest.json` holds `executor-version`); manager scripts never rewrite
them.

## Scripts

`support/ci/check-versions.py` — keeps manager-owned crate versions
(`implementation/Cargo.toml`) in sync with `version`:

| Command | Effect |
|---|---|
| `check-versions.py sync` (default) | pre-commit fixer: rewrite crate `[package]` major.minor to match `version` (patch kept); non-zero exit if it changed anything |
| `check-versions.py bump minor` | cut next train, e.g. 0.3 → 0.4 (default level) |
| `check-versions.py bump major` | 0.3 → 1.0 |
| `check-versions.py bump --set 0.6` | explicit major.minor |

`bump` updates `version`, appends the new train to `active-versions`, sets
manager crates to `<new>.0`, and prints the bare major.minor (callers build
branch names from it).

`support/ci/branch-versions.py list|latest` — prints active trains (leading `v`
stripped). Branch naming per train `<X>`:

- `v<X>.x` — release branch (release-ready)
- `v<X>-dev` — integration branch

`MONOREPO_ROOT=<path>` points it at a different `.genvm-monorepo-root` (e.g.
extracted from `origin/main`).

See also: [submodules.md](../committing/submodules.md) for the branch model of feature work.

```````

`/home/kp2pml30/work/genlayer/genvm-manager/docs/contributing/howto/releasing/release-build.md`:

```````md
# Release / nix build

Nix flake packages see only **committed** submodule content — commit inside
submodules first ([submodules.md](../committing/submodules.md)), and always pass
`?submodules=1`.

Platform suffixes: none (native), `-amd64-linux`, `-arm64-linux`, `-arm64-macos`.

| Package | Contents |
|---|---|
| `genvm[-<platform>]` | everything: manager + all executor lines + runners |
| `manager[-<platform>]` | manager bundle (`bin/`, `lib/`, `config/`, `data/`) |
| `executor[-<platform>]` | all active executor lines merged (`executor/<version>/…`) |
| `executor-<version>[-<platform>]` | one executor line |
| `runners-all-dist` | platform-independent runners (`runners/` prefix + legacy-line overlay) |
| `genvm-tool` | the tool itself |

```bash
nix build -v -L '.?submodules=1#genvm-amd64-linux'
```

Release assets (`.github/workflows/release.yaml`; tag = `version` from
`.genvm-monorepo-root`, see [versioning.md](versioning.md)):

- `genvm-<os>-<arch>.tar.xz` ← `manager-<platform>`
- `genvm-<os>-<arch>-executor.tar.xz` ← `executor-<platform>`
- `genvm-runners-all.tar.xz` ← `runners-all-dist`

All three extract at the same install root.

```````[✓] Prompt written to file: /dev/stdout
