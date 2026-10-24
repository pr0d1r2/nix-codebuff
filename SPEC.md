# SPEC

## §G GOAL

`nix-codebuff` — Codebuff CLI (`CodebuffAI/codebuff`, AI coding agent) as nix flake on fleet nixpkgs pin (`nixpkgs-lock`): real Bun-compiled `codebuff` binary at pinned version, fetched by hash at build time ∀ 4 fleet systems. frozen: ⊥ run-time download, ⊥ self-update, ⊥ update check. `codebuff` & `cb` on PATH. Linux cached on `pr0d1r2.cachix.org` from CI.

LINEAGE: `SPEC-PROMPT.md` (HISTORICAL after this run). where it & this spec differ, this spec wins. prompt decisions cited `D<n>`. paradigm `fda10ea` + its `docs/NIX.md` & `docs/SHELL.md`; fleet rules cited `paradigm/V<n>`.

## §D DESCRIPTION

nix flake + bash scripts. packaging only: fetch upstream release asset by hash, install untouched (darwin) | interpreter-patched (Linux), wrap, check, bump, cache. ⊥ source build: upstream ships Bun single executable per platform. ⊥ npm launcher: it is the thing that downloads & updates. consumer surface: `packages.<sys>.codebuff`, `default`, `packages.x86_64-linux.codebuff-baseline`, `overlays.default`. shaped like `pr0d1r2/nix-hk`. fleet member, full paradigm conformance.

## §F FEDERATION

dir|owns|⊥owns|tokens

## §N NAV

rel|path|lens
up|-|-
self|.|-

## §C CONSTRAINTS

- lang = nix + bash. paradigm `docs/NIX.md`: nixfmt, statix, deadnix, nixpkgs follows nixpkgs-lock, 1 nixpkgs in lock graph, flake check on push only when push touches what flake reads. `docs/SHELL.md`: one script one job, ⊥ shell functions except `info` `warn` `fatal`, extract ⊥ embed (⊥ inline shell in `.nix`), mirrored bats both ways, TDD order on push, env-var seams named in script header.
- root input = `nixpkgs-lock` only; `nixpkgs.follows = "nixpkgs-lock/nixpkgs"` (D1). gate tools (hk from `nix-hk`, linters) in `dev/flake.nix`, ⊥ root.
- pin = `nixpkgs-lock` `e95fdd0` → nixpkgs 26.05 `da6dc0e` (2026-10-24). follows `nixpkgs-lock` bumps.
- systems: `aarch64-darwin`, `x86_64-darwin`, `x86_64-linux`, `aarch64-linux` (`paradigm/V28`): pre-push native on owner Macs (both archs), CI the rest. ⊥ Windows.
- source = GitHub release asset of `CodebuffAI/codebuff-community` tag `v<version>`, `fetchurl` by URL + SRI hash (D2). ⊥ `codebuff.com/api/releases` (redirector), ⊥ npm `codebuff` (launcher). ∀ hash: source = `nix store prefetch-file` of asset URL, ! ≡ GitHub API asset `digest` (sha256); disagree → bump refuses.
- ∀ hash lives in 1 file `pkgs/codebuff/sources.json`, written only by bump (D5).
- version: newest by semver among tags `^v[0-9]+\.[0-9]+\.[0-9]+$` w/ `prerelease = false` & `draft = false` (D5). repo also carries `freebuff-v*`, `freebuff-desktop-v*` & `v*-beta.N` prereleases; GitHub "Latest" = `freebuff-v0.2.34` (R1) ∴ `releases/latest` ⊥ used. current = `1.0.688`.
- darwin binary ⊥ modified: byte-identical to tarball member (D3). shipped signatures already fail `codesign --verify` (R4) ∴ still ⊥ re-sign; refusal by kernel → gap question, ⊥ silent re-sign.
- Linux binary: only ELF interpreter (& rpath if needed) patched (D3). ⊥ strip: Bun payload in `.bun` section (R5).
- frozen (D4): binary has ⊥ update code (R7); download & self-update live in npm launcher only (R6), ⊥ packaged. run-time fetch paths closed in wrapper: tree-sitter wasm (R9), ripgrep (R8), Bun's own CLI (R15).
- `x86_64-linux` baseline (non-AVX2) build = 2nd package `codebuff-baseline`; default `codebuff` = AVX2 build, as upstream launcher picks on AVX2 CPU. launcher's auto-fallback ⊥ reproduced (pure eval ⊥ read `/proc/cpuinfo`); README says when to pick baseline. agent decision 2026-10-24 (prompt delegated), owner review T15.
- telemetry: PostHog key & host baked as literals, env `prod` baked (R10) ∴ ⊥ off switch exists; ⊥ patch (D3 & Bun payload). log shipping has switch `CODEBUFF_SHIP_LOGS=false`; package arg `shipLogs ? true`, default = upstream behaviour (fleet precedent: off switch opt-in). README states both. agent decision 2026-10-24, owner review T15.
- `meta.license = lib.licenses.asl20`: binary compiled from `CodebuffAI/codebuff` `cli/` (Apache-2.0; `cli/package.json` ⊥ own licence); release repo MIT covers its files, npm launcher MIT ⊥ shipped (R12). `sourceProvenance = binaryNativeCode`. agent decision 2026-10-24 (prompt delegated), owner review T15.
- cache `pr0d1r2.cachix.org` (D6): push from CI on `main` only; ⊆ Linux `codebuff` & `codebuff-baseline` closures; ⊥ darwin; ⊥ fork PR (⊥ secret). push verified by narinfo query from separate job (lesson from `pr0d1r2/nix-hk`: `cachix-action` logs 403 & stays green).
- public from start (D7). ⊥ private repo named in committed text; ∀ repo named checked by `gh repo view` → PUBLIC before first push (`paradigm/V37`).
- CI = GitHub Actions rendered by actlith from `.actlith`, same `hk.pkl` (`paradigm/V23`, `paradigm/V28`).
- outward acts ! explicit human approval: GitHub repo creation, first push, `CACHIX_AUTH_TOKEN`, bump-PR token, release, upstream issue.
- consumer wiring (fleet agent set) = consumer's own PR after release, ⊥ this repo's work (D8).
- non-goals: Windows, npm launcher, Freebuff & Codebuff's other products, source build, patching Codebuff behaviour.
