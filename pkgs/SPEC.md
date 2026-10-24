# SPEC

## §G GOAL

`pkgs/codebuff/package.nix` & `pkgs/codebuff/sources.json`: fetch asset by hash, install binary + `tree-sitter.wasm` into `libexec`, wrap as `codebuff` & `cb`.

## §N NAV

rel|path|lens
up|.|-
self|pkgs|`pkgs/codebuff/package.nix`, `sources.json`: fetch, install, wrap
sib|nix|`nix/checks.nix`: frozen, offline, untouched, layout, overlay checks
sib|scripts|bash for bump, checks & dev shell entry hook; mirrored bats
sib|dev|dev shell flake, hook install on entry
sib|gate|gate scripts: lock-graph, name, fakehash guards; their bats
sib|docs|human pages: README, SECURITY, CONTRIBUTING, LLM-DISCLAIMER

## §C CONSTRAINTS

- target map: `aarch64-darwin` → `darwin-arm64`, `x86_64-darwin` → `darwin-x64`, `aarch64-linux` → `linux-arm64`, `x86_64-linux` → `linux-x64`; `baseline = true` on `x86_64-linux` → `linux-x64-baseline`, other sys → eval error (`.` §C).
- `stdenvNoCC.mkDerivation`; `fetchurl` per target from `sources.json` (`.:V2`). unpack: tarball holds `codebuff` & `tree-sitter.wasm` at top (`.` R2).
- layout: `$out/libexec/codebuff/codebuff`, `$out/libexec/codebuff/tree-sitter.wasm`; `$out/bin/codebuff` = `makeWrapper` of libexec binary; `$out/bin/cb` → symlink to `$out/bin/codebuff`. wrapper exec keeps `process.execPath` = libexec binary ∴ sibling wasm lookup also holds.
- wrapper: `--set CODEBUFF_TREE_SITTER_WASM_PATH $out/libexec/codebuff/tree-sitter.wasm` (`.` R9); `--set-default CODEBUFF_RG_PATH ${ripgrep}/bin/rg` (`.` R8); `--unset BUN_BE_BUN` (`.` R15); `shipLogs = false` → `--set CODEBUFF_SHIP_LOGS false` (`.` R10). wasm path: the binary ignores the env var (`.` R9); the sibling file is what closes the fetch.
- darwin: `dontStrip`, ⊥ `install_name_tool`, ⊥ `codesign`; binary copied w/ `install -m755` only (`.` §C, D3).
- Linux: `autoPatchelfHook`, buildInputs = `lib.getLib glibc` only (bare `glibc` resolves to `glibc-dev`; `.` R5); `dontStrip` (`.bun` section). `dontPatchELF` ∀ sys: fixup ⊥ shrinks rpath beyond autoPatchelfHook (`pkgs:V2`). `stdenvNoCC` w/o bintools works: CI set the interpreter on both Linux archs (`.` R18).
- `meta`: `license = lib.licenses.asl20`, `sourceProvenance = [ lib.sourceTypes.binaryNativeCode ]`, `mainProgram = "codebuff"`, `platforms` = 4 fleet sys (`codebuff-baseline`: `x86_64-linux`), `homepage = "https://www.codebuff.com"`.
- `passthru.sources` = parsed `sources.json` (checks & bump read it).
- `versionCheckHook` w/ `versionCheckProgramArg = "--version"` ∴ wrong binary = build fail. `--version` creates `~/.config` first (`.` R16) ∴ install check runs w/ `HOME=$(mktemp -d)` & `versionCheckKeepEnvironment = [ "HOME" ]`.
- `pname = "codebuff"` ∀ variants; `codebuff-baseline` = flake attr name only (`nix` / root flake).

## §I INTERFACES

- file: `pkgs/codebuff/sources.json`: `{ "version": "1.0.688", "assets": { "<target>": { "url": "https://github.com/CodebuffAI/codebuff-community/releases/download/v1.0.688/codebuff-<target>.tar.gz", "hash": "sha256-…" } } }`.
- file: `sources.json` `<target>` ∈ `darwin-arm64` `darwin-x64` `linux-arm64` `linux-x64` `linux-x64-baseline`. keys sorted, 2-space indent, trailing newline.
- nix: `callPackage ./pkgs/codebuff/package.nix { baseline ? false; shipLogs ? true; }`.
- out: `bin/codebuff`, `bin/cb`, `libexec/codebuff/{codebuff,tree-sitter.wasm}`.

## §V INVARIANTS

V1: darwin `libexec/codebuff/codebuff` sha256 ≡ tarball member sha256 (D3).
V2: Linux: patched binary's NEEDED set ≡ unpatched; `.bun` section bytes ≡ unpatched; only `PT_INTERP` & rpath differ (D3).
V3: wrapper sets `CODEBUFF_TREE_SITTER_WASM_PATH` to existing file (≡ `libexec/codebuff/tree-sitter.wasm`) & `CODEBUFF_RG_PATH` default to existing store `rg`; unsets `BUN_BE_BUN` (`.:V3`).
V4: `bin/` ≡ {`codebuff`, `cb`}; `cb` resolves to `codebuff`.
V5: `meta.license` ≡ `asl20`, `sourceProvenance` ≡ [`binaryNativeCode`], `mainProgram` ≡ `codebuff`.
V6: `sources.json` holds ∀ 5 targets; package eval reads hash only from it, ⊥ hash literal in `.nix`.

## §T TASKS

id|status|task|cites
T1|x|`sources.json` for `1.0.688` written by bump (`scripts` node), ⊥ by hand|V6
T2|x|`package.nix` darwin path: untouched copy, wrapper, `cb`, meta|V1,V3,V4,V5
T3|x|Linux path: `autoPatchelfHook`, `dontStrip`; `baseline` arg; `codebuff-baseline` attr. built & checked on both Linux archs in CI 2026-10-24 (`.` R18)|V2,V3
T4|x|`shipLogs` arg|V3

## §B BUGS

id|date|cause|fix
