# SPEC

## §G GOAL

`dev/flake.nix`: dev shell w/ every gate tool pinned; hooks installed on entry; root flake stays 1 input.

## §N NAV

rel|path|lens
up|.|-
self|dev|dev shell flake, hook install on entry
sib|pkgs|`pkgs/codebuff/package.nix`, `sources.json`: fetch, install, wrap
sib|nix|`nix/checks.nix`: frozen, offline, untouched, layout, overlay checks
sib|scripts|bash for bump & checks; mirrored bats

## §C CONSTRAINTS

- inputs: `nixpkgs-lock` (nixpkgs follows), `nix-hk` (follows `nixpkgs-lock`), `pklith` | `actlith` as gate needs, ∀ following same nixpkgs (`.:V1`, `paradigm/V20`).
- tools: hk, pkl, nixfmt, statix, deadnix, shellcheck, shfmt, bats, actionlint, jq, gh, mth, sherd, itok.
- `.envrc` → `use flake ./dev`; human reload checkpoint after shell lands.
- shell on ∀ 4 sys (`paradigm/V20`).

## §I INTERFACES

- cmd: `nix develop ./dev` → shell; `hk install` on entry.
- file: `.envrc`.

## §V INVARIANTS

V1: dev lock graph: 1 nixpkgs node ≡ root's rev (`.:V1`).
V2: ∀ hk step's tool on dev shell `PATH`.

## §T TASKS

id|status|task|cites
T1|.|`dev/flake.nix` + `.envrc`|V1,V2

## §B BUGS

id|date|cause|fix
