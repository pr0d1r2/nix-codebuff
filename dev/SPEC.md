# SPEC

## §G GOAL

`dev/flake.nix`: dev shell w/ every gate tool pinned; hooks installed on entry; root flake stays 1 input.

## §N NAV

rel|path|lens
up|.|-
self|dev|dev shell flake, hook install on entry
sib|pkgs|`pkgs/codebuff/package.nix`, `sources.json`: fetch, install, wrap
sib|nix|`nix/checks.nix`: frozen, offline, untouched, layout, overlay checks
sib|scripts|bash for bump, checks & dev shell entry hook; mirrored bats
sib|gate|gate scripts: lock-graph, name, fakehash guards; their bats
sib|docs|human pages: README, SECURITY, CONTRIBUTING, LLM-DISCLAIMER

## §C CONSTRAINTS

- inputs: `nixpkgs-lock` (nixpkgs follows), `nix-hk` (follows `nixpkgs-lock`), `pklith` | `actlith` as gate needs, ∀ following same nixpkgs (`.:V1`, `paradigm/V20`).
- tools: hk (`nix-hk` overlay), pkl, git, nixfmt, statix, deadnix, shellcheck, shfmt, bats, actionlint, jq, gh; fleet tags: microlith `v0.7.4` (`mth`), sherd `v0.5.4`, itok `v0.3.1`, pklith `v0.1.0`, actlith `v0.1.0`, xenolith `v0.1.0`. bump = own commit.
- `x86_64-darwin`: fleet tools w/o build there (microlith, itok, pklith, xenolith; measured 2026-10-24: `inputs.<tool>.packages.x86_64-darwin` absent; actlith present) left out & named on entry; gate needing one fails, ⊥ skips.
- shell hook = `scripts/dev/shell-hook.sh` (`scripts` node), ⊥ inline shell (`.` §C).
- shell adds the tools `pklith gen` names in `nix/pklith.nix`, resolved against nixpkgs + microlith, sherd, itok (pklith catalog namespace); ⊥ on sys missing fleet tools.
- `.envrc` → `use flake ./dev`; human reload checkpoint after shell lands.
- shell on ∀ 4 sys (`paradigm/V20`).

## §I INTERFACES

- cmd: `nix develop ./dev` → shell; entry runs `scripts/dev/shell-hook.sh <system> <absent tools>`.
- file: `.envrc`.

## §V INVARIANTS

V1: dev lock graph: 1 nixpkgs node ≡ root's rev (`.:V1`).
V2: ∀ hk step's tool on dev shell `PATH`.
V3: shell entry ⊥ fails; hooks ⊥ installed before `hk.pkl` exists (`paradigm/V22`); ⊥ hk → says so, ⊥ fallback runner (`paradigm/V23`).

## §T TASKS

id|status|task|cites
T1|x|`dev/flake.nix` + `.envrc`|V1,V2,V3

## §B BUGS

id|date|cause|fix
