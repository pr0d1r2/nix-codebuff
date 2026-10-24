# SPEC

## §G GOAL

`nix/checks.nix`: flake checks proving frozen, offline & untouched (D4); each check = one script from `scripts/checks/` via `builtins.readFile`.

## §N NAV

rel|path|lens
up|.|-
self|nix|`nix/checks.nix`: frozen, offline, untouched, layout, overlay checks
sib|pkgs|`pkgs/codebuff/package.nix`, `sources.json`: fetch, install, wrap
sib|scripts|bash for bump & checks; mirrored bats

## §C CONSTRAINTS

- `docs/NIX.md`: `nix/checks.nix`, one script per check; ⊥ inline shell (`.` §C).
- run in build sandbox: ⊥ network on Linux. darwin sandbox may allow network ∴ checks also point `HTTP_PROXY` `HTTPS_PROXY` `ALL_PROXY` at loopback listener & count connections.
- fresh `HOME=$TMPDIR/home` per check.
- checks run ∀ 4 sys where built; `codebuff-baseline` checks on `x86_64-linux`.

## §I INTERFACES

- flake: `checks.<sys>.frozen` → `codebuff --version` offline, exit 0, stdout contains `sources.json` version; listener 0 connections; `$HOME` tree after run ⊥ executable, ⊥ `*.tar.gz`, ⊥ `*.part`.
- flake: `checks.<sys>.tree-sitter` → `codebuff --smoke-tree-sitter` resolves store wasm path, ⊥ URL (`.` R9).
- flake: `checks.<sys>.untouched` → darwin `pkgs:V1` | Linux `pkgs:V2`.
- flake: `checks.<sys>.layout` → `pkgs:V3`, `pkgs:V4`, `pkgs:V5`.
- flake: `checks.<sys>.overlay` → `.:V4`.

## §V INVARIANTS

V1: `frozen` fails on fixture binary that opens a socket | writes a file named `codebuff` under `$HOME` (planted violation) (`.:V3`).
V2: `tree-sitter` fails when wasm path unset (planted: wrapper w/o `--set`) (`.:V3`).
V3: ∀ check script has mirrored bats (`scripts` node owns script & bats).

## §T TASKS

id|status|task|cites
T1|.|`checks.nix` skeleton & `frozen`|V1
T2|.|`tree-sitter`, `untouched`, `layout`, `overlay`|V2,V3

## §B BUGS

id|date|cause|fix
