---
name: new-repo
description: Skill to use when creating a new repository. Covers the root files, README, docs layout, .gitattributes, and Nix flake.nix.
---
# New Repo Skill

Bootstrap a new repository from scratch. Work through the checklist below in order.

The `example/` directory next to this skill contains starter files you can copy into a new repo and adapt.

## Checklist — root files

Copy or create the following at the repo root:

| File | Source / action |
|---|---|
| `README.md` | write; follow [standard-readme format](#readme) |
| `LICENSE` | GPL-3.0 by default; match `README.md` badge |
| `.gitignore` | copy [`example/gitignore`](./example/gitignore); append project-specific entries |
| `.gitattributes` | create from [`example/gitattributes`](./example/gitattributes) |
| `.dockerignore` | create from [`example/dockerignore`](./example/dockerignore) |
| `.editorconfig` | copy [`example/.editorconfig`](./example/.editorconfig) verbatim |
| `flake.nix` | start from [`example/flake.nix`](./example/flake.nix); adapt `packages.default`, hook set, and dependencies |

Optional starter configs from `example/` when relevant:
- [`ruff.toml`](./example/ruff.toml)
- [`.clang-format`](./example/.clang-format)
- [`.pre-commit-config.yaml`](./example/.pre-commit-config.yaml) for repos that use pre-commit directly instead of generating hooks from Nix

## Support files

Keep all supporting material (scripts, helper data, hook implementations) under a
single `support/` directory — e.g. `support/scripts/check-commit-message.py`.
The only exception is config dotfiles that tools look up by a fixed name and can
only find at the repo root (`.gitignore`, `.gitattributes`, `.editorconfig`,
`.clang-format`, `ruff.toml`, `flake.nix`, …) — those must stay at the root.

The [`example/`](./example/) tree follows this: config dotfiles at the root,
everything else under [`example/support/`](./example/support/).

### Commit-message hook

[`example/support/scripts/check-commit-message.py`](./example/support/scripts/check-commit-message.py)
validates commit messages against conventional-commit rules. Wire it as a
`commit-msg` hook in every repo. See [`example/flake.nix`](./example/flake.nix)
(the `check-commit-message` hook) for the `git-hooks.nix` wiring, or
[`example/.pre-commit-config.yaml`](./example/.pre-commit-config.yaml) for the
plain-pre-commit `repo: local` variant. Because it runs on the `commit-msg`
stage it is skipped by `nix flake check` / `pre-commit run --all-files`.

It enforces `<type>(<scope>): <subject> [emoji...]`, rejects AI attribution,
mid-subject emojis and control characters, and validates each `* ` bullet of a
squash commit as its own subject.

### Local guards

Also under `example/support/scripts/`, wired the same way:

| Script | Hook | Checks |
|---|---|---|
| [`check-source-text.py`](./example/support/scripts/check-source-text.py) | `check-source-text` | non-ASCII punctuation with an ASCII swap (`§ — ─ → …`); a blacklist, not an ASCII-only ban. Opt a file out with a `check-source-text: off` comment. Add project citation patterns (ADR, ticket ids) to `_PATTERNS` if wanted |
| [`md-local-links.py`](./example/support/scripts/md-local-links.py) | `markdown-local-links` | relative Markdown links resolve to existing files; offline, ignores URLs and anchors |

### Hooks worth enabling

Pick what the repo needs; `example/flake.nix` shows the wiring:

- Generic: `trim-trailing-whitespace`, `end-of-file-fixer`, `check-added-large-files`, `check-json`, `check-yaml`, `check-toml`, `check-merge-conflicts`, `editorconfig-checker` (set `types = [ "text" ]`)
- Formatters: `nixfmt`, `taplo` ([`.taplo.toml`](./example/.taplo.toml)), `stylua` ([`.stylua.toml`](./example/.stylua.toml)), `ruff` + `ruff-format`, `clang-format`, `rustfmt` / per-crate `cargo fmt`, `prettier` (always scope `files`)
- GitHub: `check-github-workflows`, `check-github-actions` via `check-jsonschema --builtin-schema`
- Project-specific: version-sync or generated-index `--check` hooks with `pass_filenames = false`

## README

Follow <https://github.com/richardlitt/standard-readme>. Required sections in order:

1. `# Title` — matches repo name
2. One-sentence tagline below the title
3. Badges (CI, license) — optional but recommended. Add `![vibe coded](https://img.shields.io/badge/vibe-coded-purple.svg)` **only if the user asks**
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
		howto/             ← see example/contributing-structure.md
```

See [`example/contributing-structure.md`](./example/contributing-structure.md) for how to lay out `docs/contributing/howto/`. Every repo gets a committing howto listing the hook, format and check commands; start from [`example/docs/contributing/howto/committing/README.md`](./example/docs/contributing/howto/committing/README.md).

## .gitattributes rules

Mark binary, vendored, and generated files so GitHub Linguist handles them correctly. See [`example/gitattributes`](./example/gitattributes) for the base template — extend it with project-specific entries.

Key patterns:

```gitattributes
# vendored
vendor/**  linguist-vendored
*.onnx     linguist-vendored

# generated
*.generated.*  linguist-generated
```

## Nix / flake.nix

Package with nix. Minimal `flake.nix` should expose:
- `packages.default` — the main build output
- `devShells.default` — dev shell with all build-time deps
- `checks.<system>.pre-commit-check` — git hooks via `git-hooks.nix`
- `formatter.<system>` — a formatter command that runs the same generated pre-commit config as `nix flake check`

Use [`example/flake.nix`](./example/flake.nix) as the starter. It is derived from this repo's root `flake.nix` formatter/checks/dev-shell pattern.

Wire git hooks using [cachix/git-hooks.nix](https://github.com/cachix/git-hooks.nix):

```nix
inputs.git-hooks = {
	url = "github:cachix/git-hooks.nix";
	inputs.nixpkgs.follows = "nixpkgs";
};
```

In outputs (assumes `forEachSystem = lib.genAttrs (import inputs.systems)`):

```nix
formatter = forEachSystem (
	system:
	let
		pkgs = import nixpkgs { inherit system; };
		config = self.checks.${system}.pre-commit-check.config;
		inherit (config) package configFile;
	in
	pkgs.writeShellScriptBin "pre-commit-run" ''
		${pkgs.lib.getExe package} run --all-files --config ${configFile}
	''
);

checks = forEachSystem (system: {
	pre-commit-check = inputs.git-hooks.lib.${system}.run {
		src = ./.;
		hooks = {
			nixfmt.enable = true;
			# add language-specific hooks here, e.g.:
			# ruff.enable = true;
			# ruff-format.enable = true;
			# clang-format.enable = true;
		};
	};
});

devShells = forEachSystem (
	system:
	let
		pkgs = import nixpkgs { inherit system; };
		inherit (self.checks.${system}.pre-commit-check) shellHook enabledPackages;
	in
	{
		default = pkgs.mkShell {
			inherit shellHook;
			buildInputs = enabledPackages;
		};
	}
);
```

If you use `git-hooks.nix`, add `/.pre-commit-config.yaml` to `.gitignore` — it is auto-generated by Nix.

Check and format:
- `nix fmt` — format: runs every hook over all files, fixing files in place; rerun until clean
- `nix flake check` — verify: builds all `checks` (and evaluates the other outputs); the pre-commit check runs sandboxed on a read-only copy, so it fails rather than fixes. Run it before pushing / in CI
- `nix flake check --all-systems` — also evaluate other systems' outputs
- `nix develop` — installs hooks into `.git/hooks/`, so they run on `git commit` (including `commit-msg`, which the 2 commands above skip)
- `nix develop -c pre-commit run --all-files` — same as `nix fmt`, from the dev shell's pre-commit

In a git repo, flakes see only tracked files: `git add` new files first, or run `nix flake check path:$PWD`. `nix fmt` takes formatter arguments, not a flake ref.
