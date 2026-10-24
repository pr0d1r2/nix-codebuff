# SPEC

## §G GOAL

`nix/checks.nix`: flake checks proving frozen, offline & untouched (D4); each script check = one script from `scripts/checks/` run by store path (`${../scripts/checks/<name>.sh}`), ⊥ inlined; `meta` & `overlay` = nix assertions, false → eval error naming the rule.

## §N NAV

rel|path|lens
up|.|-
self|nix|`nix/checks.nix`: frozen, offline, untouched, layout, overlay checks
sib|pkgs|`pkgs/codebuff/package.nix`, `sources.json`: fetch, install, wrap
sib|scripts|bash for bump, checks & dev shell entry hook; mirrored bats
sib|dev|dev shell flake, hook install on entry
sib|gate|gate scripts: lock-graph, name, fakehash guards; their bats
sib|docs|human pages: README, SECURITY, CONTRIBUTING, LLM-DISCLAIMER

## §C CONSTRAINTS

- `docs/NIX.md`: `nix/checks.nix`, one script per check; ⊥ inline shell (`.` §C).
- run in build sandbox: ⊥ network on Linux. darwin sandbox may allow network (owner Mac 2026-10-24: `nix config show sandbox` = `false`, ∴ darwin checks run unsandboxed & the proxy count is the only network guard there) ∴ checks also point `HTTP_PROXY` `HTTPS_PROXY` `ALL_PROXY` at loopback listener & count connections.
- fresh `HOME=$TMPDIR/home` per check.
- checks run ∀ 4 sys where built; `codebuff-baseline` checks on `x86_64-linux`.
- check inputs (wave 4): `frozen` socat coreutils findutils gnused gnugrep; `tree-sitter` coreutils gnused gnugrep; `untouched` gnutar gzip diffutils coreutils, + binutils on Linux (ELF branch ⊥ on darwin: `.` R17); `layout` findutils gnused gnugrep. `overlay` & meta (`pkgs:V5`) = nix assertions, ⊥ script.

## §I INTERFACES

- flake: `checks.<sys>.frozen` → `codebuff --version` offline, exit 0, stdout contains `sources.json` version; listener 0 connections; `$HOME` tree after run ⊥ executable, ⊥ `*.tar.gz`, ⊥ `*.part`.
- flake: `checks.<sys>.tree-sitter` → `codebuff --smoke-tree-sitter` resolves store wasm path, ⊥ URL (`.` R9).
- flake: `checks.<sys>.untouched` → darwin `pkgs:V1` | Linux `pkgs:V2`.
- flake: `checks.<sys>.layout` → `pkgs:V3`, `pkgs:V4`. `checks.<sys>.meta` → `pkgs:V5`. `checks.<sys>.frozen-cb` = `frozen` on `bin/cb`. `-baseline` twins of frozen, frozen-cb, tree-sitter, untouched, layout, meta on `x86_64-linux`.
- flake: `checks.<sys>.overlay` → `.:V4`.

## §V INVARIANTS

V1: `frozen` fails on fixture binary that opens a socket | writes a file named `codebuff` under `$HOME` (planted violation) (`.:V3`).
V2: `tree-sitter` fails when wasm path unset (planted: wrapper w/o `--set`; caught by reading wrapper text, since binary ignores the var: `.` R9) (`.:V3`).
V3: ∀ check script has mirrored bats (`scripts` node owns script & bats).

## §T TASKS

id|status|task|cites
T1|x|`checks.nix` skeleton & `frozen`|V1
T2|x|`tree-sitter`, `untouched`, `layout`, `overlay`, `meta`. built aarch64-darwin & both Linux in CI 2026-10-24; x86_64-darwin waits for root T9|V2,V3

## §B BUGS

id|date|cause|fix
