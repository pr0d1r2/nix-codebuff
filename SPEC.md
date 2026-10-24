# SPEC

## §G GOAL

`nix-codebuff` — Codebuff CLI (`CodebuffAI/codebuff`, AI coding agent) as nix flake on fleet nixpkgs pin (`nixpkgs-lock`): real Bun-compiled `codebuff` binary at pinned version, fetched by hash at build time ∀ 4 fleet systems. frozen: ⊥ run-time download, ⊥ self-update, ⊥ update check. `codebuff` & `cb` on PATH. Linux cached on `pr0d1r2.cachix.org` from CI.

LINEAGE: `SPEC-PROMPT.md` (HISTORICAL after this run). where it & this spec differ, this spec wins. prompt decisions cited `D<n>`. paradigm `fda10ea` + its `docs/NIX.md` & `docs/SHELL.md`; fleet rules cited `paradigm/V<n>`.

## §D DESCRIPTION

nix flake + bash scripts. packaging only: fetch upstream release asset by hash, install untouched (darwin) | interpreter-patched (Linux), wrap, check, bump, cache. ⊥ source build: upstream ships Bun single executable per platform. ⊥ npm launcher: it is the thing that downloads & updates. consumer surface: `packages.<sys>.codebuff`, `default`, `packages.x86_64-linux.codebuff-baseline`, `overlays.default`. shaped like `pr0d1r2/nix-hk`. fleet member, full paradigm conformance.

## §F FEDERATION

dir|owns|⊥owns|tokens
pkgs|`pkgs/codebuff/package.nix`, `sources.json`: fetch, install, wrap|bump (`scripts`), checks (`nix`)|-
nix|`nix/checks.nix`: frozen, offline, untouched, layout, overlay checks|check script bodies & bats (`scripts`), package (`pkgs`)|-
scripts|bash for bump & checks; mirrored bats|flake outputs (`nix`, `pkgs`), workflows (`.actlith`)|-

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

## §I INTERFACES

- input:
  ```nix
  inputs = {
    nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock";
    nixpkgs.follows = "nixpkgs-lock/nixpkgs";
  };
  ```
- flake: `packages.<sys>.codebuff` ∀ 4 sys; `packages.<sys>.default` ≡ `codebuff` (`pkgs` node).
- flake: `packages.x86_64-linux.codebuff-baseline` (`pkgs` node).
- flake: `overlays.default` → adds exactly `codebuff` (D, goal 2).
- flake: `checks.<sys>.*` (`nix` node). `devShells` from `dev/flake.nix` (`dev` node).
- cmd: `codebuff`, `cb` → same wrapper; `codebuff --version` → contains `sources.json` version.
- file: `pkgs/codebuff/sources.json` — version + per-target URL & SRI hash (`pkgs` node §I).
- cmd: `scripts/bump.sh` (`scripts` node).
- cachix: substituter `https://pr0d1r2.cachix.org`, key `pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=` (from `nix-hk` `flake.nix` `nixConfig`).
- CI: `.github/workflows/build.yml`, `upstream.yml` from `.actlith`.
- env: `CACHIX_AUTH_TOKEN` (CI secret, per-cache WRITE token).

## §R RESEARCH

id|topic|finding|src
R1|releases 2026-10-24|`CodebuffAI/codebuff-community` (id 921429448, MIT, public): 696 releases = 317 `v*`, 210 `freebuff-v*`, 169 `freebuff-desktop-v*`. newest stable `v1.0.688` 2026-09-08 (`.0.687` 09-05, `.0.686` 08-30). `v1.0.420-beta.271` 2026-10-21 prerelease. GitHub Latest = `freebuff-v0.2.34`|`gh api --paginate repos/CodebuffAI/codebuff-community/releases`
R2|assets `v1.0.688`|7 tarballs: darwin-arm64 36176238 B `5522f524…`, darwin-x64 38517841 `c8122c4e…`, linux-arm64 52009945 `06ca1cfe…`, linux-x64 52845655 `2f3935a3…`, linux-x64-baseline 52471816 `551c39f0…`, win32 ×2. API `digest` ≡ local `shasum -a 256` ∀ 5 fetched. each = `codebuff` + `tree-sitter.wasm` (205488 B)|`gh release view v1.0.688 --json assets`; `curl` + `shasum`
R3|binary kind|Bun single executable, Bun `v1.3.14 (0d9b296a)`. bundle defines `CODEBUFF_IS_BINARY:"true"`, `CODEBUFF_CLI_VERSION:"1.0.688"`, `CODEBUFF_CLI_TARGET`. darwin: `__BUN` segment 27 MB; Linux: `.bun` ELF section 45 MB|`strings`-class scan, `size -m`, `readelf -S`
R4|darwin signature|arm64: `adhoc,linker-signed`, Identifier `a.out`; x64: `Developer ID Application: Jarred Sumner (7FRXF46ZSN)` (Bun's runtime cert), Identifier `bun`. both `codesign --verify` → `invalid signature (code or signature have been modified)`. `minos 13.0`, `sdk 15.2`. links `/usr/lib` only (libicucore, libresolv, libc++, libSystem). exec under invalid signature ⊥ measured (T9)|`codesign -dv`, `codesign --verify --strict`, `vtool -show-build`, `otool -L`
R5|Linux ELF|dynamic, interpreter `/lib64/ld-linux-x86-64.so.2` \| `/lib/ld-linux-aarch64.so.1`; NEEDED = `libc.so.6` `ld-linux-*` `libpthread.so.0` `libdl.so.2` `libm.so.6` only; max `GLIBC_2.17`; not stripped. ∴ `autoPatchelfHook` w/ glibc alone. payload after patchelf ⊥ measured (T10)|`readelf -d -S -V`
R6|npm launcher 1.0.688|`index.js` `launcher.js` `http.js`, dep `tar`. downloads `${NEXT_PUBLIC_CODEBUFF_APP_URL:-https://codebuff.com}/api/releases/download/<v>/codebuff-<target>.tar.gz` into `~/.config/manicode/`; checks `https://registry.npmjs.org/codebuff/latest`; moves `tree-sitter.wasm` beside binary; picks `linux-x64-baseline` when `/proc/cpuinfo` ⊥ `avx2`; env `CODEBUFF_BINARY_TARGET` overrides; spawns binary w/ `CODEBUFF_LAUNCHER_PID`; posts `cli.update_codebuff_failed` to PostHog|npm tarball `codebuff-1.0.688.tgz`, read in full
R7|binary update code|bundle has 0 `/api/releases`, 0 `registry.npmjs.org/codebuff`, 0 `codebuff@latest`, 0 `npm install -g codebuff`. remaining `registry.npmjs.org` hits = Bun runtime's own package manager. ∴ self-update absent from binary (static; proven by `nix` node `frozen` check)|byte scan of darwin-arm64 binary
R8|ripgrep|code search resolves `CODEBUFF_RG_PATH` first, else `vendor/ripgrep/<target>/rg` beside script (`/$bunfs`, absent), else `./node_modules/@codebuff/sdk/dist/vendor/ripgrep/…`, else throws `Ripgrep binary not found`. ⊥ download. tarball ships ⊥ rg ∴ wrapper sets `CODEBUFF_RG_PATH`. pin ripgrep `15.1.0`|bundle function resolving rg path
R9|tree-sitter wasm|`tree-sitter.wasm` looked up at `CODEBUFF_TREE_SITTER_WASM_PATH`, scriptDir, `dirname(process.execPath)`; fallback URLs `https://unpkg.com/web-tree-sitter@0.25.10/tree-sitter.wasm` & `cdn.jsdelivr.net` = run-time download ∴ wrapper sets path. flag `--smoke-tree-sitter` prints resolution|bundle near `CODEBUFF_TREE_SITTER_WASM_PATH`
R10|telemetry|`posthog-node`; key `phc_…` & host `https://us.i.posthog.com` baked in env literal, schema-validated, ⊥ read from `process.env`; `NEXT_PUBLIC_CB_ENVIRONMENT` baked `prod`; ⊥ `DO_NOT_TRACK` in Codebuff code (1 hit = Bun runtime). `CODEBUFF_SHIP_LOGS` `"false"` → log batches ⊥ sent. `CODEBUFF_FULL_TELEMETRY*` only widens|bundle near `NEXT_PUBLIC_POSTHOG_API_KEY`, `CODEBUFF_SHIP_LOGS`
R11|state dir|config `~/.config/manicode` (`-<env>` suffix off prod); ignore files `.gitignore` `.codebuffignore` `.manicodeignore`. other writes ⊥ measured (T11)|bundle near `manicode`
R12|licences|`CodebuffAI/codebuff` Apache-2.0 (id 826515105); `cli/package.json` `license: null`; `codebuff-community` LICENSE MIT ("Copyright (c) 2025 Codebuff"); npm `codebuff` MIT; nixpkgs `codebuff` `meta.license` MIT|`gh api repos/…`, `gh api …/contents/LICENSE`
R13|pin `da6dc0e` 2026-10-24|nixpkgs `26.05.20261021.da6dc0e` via `nixpkgs-lock` `e95fdd0`; `codebuff` 1.0.674 = `buildNpmPackage` of npm launcher (∴ downloads at first run); `ripgrep` 15.1.0|`nix eval github:NixOS/nixpkgs/<pin>#<attr>`
R14|launcher-only package fails offline|nixpkgs `codebuff` ships `index.js` `launcher.js`; ∀ start → registry check, first start → download into `$HOME` ∴ ⊥ frozen, ⊥ reproducible (prompt Problem)|R6, R13
R15|Bun's own CLI|runtime carries `BUN_BE_BUN` (exe acts as `bun`, incl `bun upgrade`, `bun install`) ∴ wrapper unsets it|bundle scan

## §V INVARIANTS

V1: lock graph: exactly 1 nixpkgs node; root inputs ≡ {`nixpkgs-lock`}; ∀ `nixpkgs` follows it; gate fails else (D1).
V2: ∀ fetched asset: URL `https://github.com/CodebuffAI/codebuff-community/releases/download/v<version>/codebuff-<target>.tar.gz`, literal SRI hash from `sources.json`; ⊥ `lib.fakeHash` on `main`; ⊥ `codebuff.com` URL (D2).
V3: ⊥ run-time download, self-update, update check (D4). proven by `nix` node checks; closed by `pkgs` node wrapper.
V4: overlay adds exactly `codebuff`: `attrNames (overlay {} {})` ≡ [`codebuff`] (goal 2).
V5: ∀ cachix push ⊆ Linux `codebuff` | `codebuff-baseline` closure, `main` only; ⊥ darwin; verified by narinfo 200 from separate job (D6).
V6: ⊥ private repo named in committed text (`paradigm/V37`, D7).
V7: ∀ outward act ∈ §C approval list has human approval on record.

## §T TASKS

id|status|task|cites
T1|.|vendor `FORMAT.md` & `FORMAT-EXTENSIONS.md` from paradigm `fda10ea`|-
T2|.|spec run: root sections & ∀ node, 1 per commit, trailer `spec-run`|-
T3|.|freeze `SPEC-PROMPT.md`: line 1 → `HISTORICAL INPUT`, own commit|-
T4|.|`.context-limits` from `sherd budget` + 12–20%|-
T5|.|`.gitignore`: `.claude/`, `.direnv/`, `result*`, `.private/`|V6
T6|.|dev shell (`dev`); ask human to reload|V1
T7|.|guardrails via `.pklith`, 1 check per commit, planted violation each; ask human to reload|V1,V2,V6
T8|.|waves via `sherd wave`, order: `pkgs` aarch64-darwin → `nix` checks → Linux via builder \| CI → `scripts` bump → CI → `docs`|V2,V3,V4
T9|.|measure: darwin exec of untouched binary on both archs (invalid signature, R4); kernel refusal → gap question to owner, ⊥ re-sign|V3
T10|.|measure: Linux `autoPatchelfHook` keeps Bun payload: `codebuff --version` on x86_64-linux & aarch64-linux after patch|V3
T11|.|measure: writes outside `$HOME/.config/manicode` on fresh `HOME`; record in §R; frozen check covers them|V3
T12|.|CI via actlith: `build.yml` (build & check, cache & verify Linux), `upstream.yml` (daily bump); `CACHIX_AUTH_TOKEN` w/ approval|V5,V7
T13|.|GitHub repo `pr0d1r2/nix-codebuff` PUBLIC, first push, w/ approval; `gh repo view` ∀ named repo first. prompt names `nix-orca`, ⊥ resolvable 2026-10-24; owner: both repos go public same weekend ∴ ! PUBLIC before this repo's first push|V6,V7
T14|.|bump PR author: token source for `upstream.yml` to open PR (owner decision); until then workflow fails red on newer release, ⊥ PR|V7
T15|.|owner review of agent decisions: baseline as 2nd package, `meta.license = asl20`, `shipLogs` default upstream|-
T16|.|upstream issues w/ approval: invalid darwin signatures (R4); telemetry w/o opt-out (R10)|V7

## §B BUGS

id|date|cause|fix
