#!/usr/bin/env bash
# regenerate pnpm-lock.yaml after bumping package.json, then fix the pnpmDeps hash
set -euo pipefail
cd "$(dirname "$0")"
# the flake-pinned pnpm, so the lockfile format matches what fetchPnpmDeps expects
nix shell --inputs-from "$(git rev-parse --show-toplevel)" nixpkgs#pnpm_10 -c pnpm install --lockfile-only
