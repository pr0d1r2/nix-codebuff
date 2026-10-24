# SPEC

## §G GOAL

repo gate scripts hk runs: lock-graph guard, name guard, overlay guard; bats in `tests/unit/gate/`.

## §N NAV

rel|path|lens
up|.|-
self|gate|gate scripts: lock-graph, name, fakehash guards; their bats
sib|pkgs|`pkgs/codebuff/package.nix`, `sources.json`: fetch, install, wrap
sib|nix|`nix/checks.nix`: frozen, offline, untouched, layout, overlay checks
sib|scripts|bash for bump, checks & dev shell entry hook; mirrored bats
sib|dev|dev shell flake, hook install on entry
sib|docs|human pages: README, SECURITY, CONTRIBUTING, LLM-DISCLAIMER

## §C CONSTRAINTS

- hk steps from `.pklith` via pklith (`paradigm/V23`); 1 check per commit, planted violation each (`paradigm/V21`).
- name guard: denylist local `.private/denylist` (⊥ committed), allowlist of public repos in CI (`paradigm/V37`).
- lock-graph guard runs on root & `dev` locks.

## §I INTERFACES

- cmd: `gate/lock-graph.sh <flake.lock>` → exit 1 on 2nd nixpkgs | unfollowed input | root input ∉ {`nixpkgs-lock`}.
- cmd: `gate/name-guard.sh` → exit 1 on denylisted name | repo ∉ allowlist.
- cmd: `gate/no-fakehash.sh` → exit 1 on `lib.fakeHash` | `sha256-AAAA` in tracked `.nix` | `sources.json`.

## §V INVARIANTS

V1: lock-graph guard fails on fixture w/ 2 nixpkgs nodes & passes on single (`.:V1`).
V2: name guard fails on planted denylisted name (`.:V6`).
V3: fakehash guard fails on planted `lib.fakeHash` (`.:V2`).

## §T TASKS

id|status|task|cites
T1|x|`lock-graph.sh` + fixtures; root inputs allowed by name|V1
T2|x|`name-guard.sh` denylist half + fixtures|V2
T3|x|`no-fakehash.sh` + fixtures|V3
T4|.|`name-guard.sh` allowlist half: ∀ repo named \| linked ∈ committed public list, CI side (`paradigm/V37`)|V2

## §B BUGS

id|date|cause|fix
