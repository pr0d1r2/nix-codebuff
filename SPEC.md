# SPEC

## §G GOAL

`nix-codebuff` — Codebuff CLI (`CodebuffAI/codebuff`, AI coding agent) as nix flake on fleet nixpkgs pin (`nixpkgs-lock`): real Bun-compiled `codebuff` binary at pinned version, fetched by hash at build time ∀ 4 fleet systems. frozen: ⊥ run-time download, ⊥ self-update, ⊥ update check. `codebuff` & `cb` on PATH. Linux cached on `pr0d1r2.cachix.org` from CI.

LINEAGE: `SPEC-PROMPT.md` (HISTORICAL after this run). where it & this spec differ, this spec wins. prompt decisions cited `D<n>`. paradigm `fda10ea` + its `docs/NIX.md` & `docs/SHELL.md`; fleet rules cited `paradigm/V<n>`.

## §D DESCRIPTION

nix flake + bash scripts. packaging only: fetch upstream release asset by hash, install untouched (darwin) | interpreter-patched (Linux), wrap, check, bump, cache. ⊥ source build: upstream ships Bun single executable per platform. ⊥ npm launcher: it is the thing that downloads & updates. consumer surface: `packages.<sys>.codebuff`, `default`, `packages.x86_64-linux.codebuff-baseline`, `overlays.default`. shaped like `pr0d1r2/nix-hk`. fleet member, full paradigm conformance.
