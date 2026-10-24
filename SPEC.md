# SPEC

## §G GOAL

`nix-codebuff` — Codebuff CLI (`CodebuffAI/codebuff`, AI coding agent) as nix flake on fleet nixpkgs pin (`nixpkgs-lock`): real Bun-compiled `codebuff` binary at pinned version, fetched by hash at build time ∀ 4 fleet systems. frozen: ⊥ run-time download, ⊥ self-update, ⊥ update check. `codebuff` & `cb` on PATH. Linux cached on `pr0d1r2.cachix.org` from CI.

LINEAGE: `SPEC-PROMPT.md` (HISTORICAL after this run). where it & this spec differ, this spec wins. prompt decisions cited `D<n>`. paradigm `fda10ea` + its `docs/NIX.md` & `docs/SHELL.md`; fleet rules cited `paradigm/V<n>`.
