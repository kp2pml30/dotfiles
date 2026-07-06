{
  # This starter is intentionally MAXIMAL: it wires up hooks for several
  # languages at once so you can see the pattern. Copy only what your repo
  # actually contains — delete every hook whose language you don't use, and
  # delete any input that only fed those hooks. A repo with no Rust should not
  # carry the rustfmt hook; a repo with no .yamd should drop the yamd input.
  description = "Starter flake for a new repository";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";

    # Deduplicate inputs: for every input that itself depends on nixpkgs (or on
    # git-hooks), add a `follows` so the whole tree resolves to one copy. Only
    # add a `follows` for an input the dependency actually declares — a follows
    # for a non-existent input (e.g. `systems` has no nixpkgs) just warns and
    # does nothing, so drop it.
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    yamd = {
      url = "git+https://git.kp2pml30.moe/ya/yamd";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.git-hooks.follows = "git-hooks";
    };
  };

  outputs =
    inputs@{ self, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
      forEachSystem = lib.genAttrs (import inputs.systems);
    in
    {
      packages = forEachSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          # Replace this with your real package.
          default = pkgs.writeShellScriptBin "my-project" ''
            echo "replace packages.default in flake.nix with your real build output"
          '';
        }
      );

      # Copied from the root flake pattern: expose a formatter command that runs
      # the same pre-commit config used by `nix flake check`.
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
          hooks =
            let
              pkgs = import nixpkgs { inherit system; };
            in
            {
              # Universal — keep this in every repo. Validates commit messages
              # against conventional-commit rules (runs on the commit-msg stage,
              # so it is skipped by `nix flake check` / `pre-commit run`).
              check-commit-message = {
                enable = true;
                name = "check commit message";
                description = "Validate the commit message against conventional-commit rules.";
                entry = "${pkgs.python3}/bin/python3 ${./support/scripts/check-commit-message.py} --message-file";
                language = "system";
                stages = [ "commit-msg" ];
              };

              nixfmt.enable = true;

              # Enable language-specific formatters and linters as needed.
              ruff.enable = true;
              ruff-format.enable = true;
              clang-format.enable = true;

              # Rust. The built-in rustfmt hook shells out to `cargo fmt`, which
              # needs a Cargo manifest in the working dir; run rustfmt directly
              # so it works regardless of where Cargo.toml lives.
              rustfmt = {
                enable = true;
                name = "rustfmt";
                description = "Format Rust code.";
                package = pkgs.rustfmt;
                entry = "${pkgs.rustfmt}/bin/rustfmt --edition 2021";
                files = "\\.rs$";
                pass_filenames = true;
              };

              # Web files (JS/TS/Vue/CSS/JSON/…). prettier's default
              # `types = [ "text" ]` matches every text file, so ALWAYS scope it
              # with `files` or it will fight the other formatters. Exclude
              # generated files (lockfiles, emitted JSON) and verbatim published
              # assets. `.astro` needs prettier-plugin-astro, which is not in
              # nixpkgs — leave it out and format those with the project's own
              # prettier via `npx`.
              prettier = {
                enable = true;
                files = "\\.(css|scss|less|jsx?|mjs|cjs|tsx?|mts|cts|vue|json|jsonc|md|markdown|ya?ml|graphql)$";
                excludes = [
                  "(^|/)package-lock\\.json$"
                  # e.g. "^src/generated\\.json$"  "^public/"
                ];
              };

              # yamd documents: rewrite in place; the commit fails if files
              # changed (drop the input and this hook if the repo has no .yamd).
              yamd-fmt = {
                enable = true;
                name = "yamd fmt";
                entry = "${inputs.yamd.packages.${system}.default}/bin/yamd --fmt";
                files = "\\.yamd$";
              };
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
    };
}
