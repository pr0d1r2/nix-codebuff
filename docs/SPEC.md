# SPEC

## §G GOAL

human pages: `README.md` (root), `docs/SECURITY.md`, `docs/CONTRIBUTING.md`, `docs/LLM-DISCLAIMER.md`. prose, ⊥ caveman.

## §N NAV

rel|path|lens
up|.|-
self|docs|human pages: README, SECURITY, CONTRIBUTING, LLM-DISCLAIMER
sib|pkgs|`pkgs/codebuff/package.nix`, `sources.json`: fetch, install, wrap
sib|nix|`nix/checks.nix`: frozen, offline, untouched, layout, overlay checks
sib|scripts|bash for bump, checks & dev shell entry hook; mirrored bats
sib|dev|dev shell flake, hook install on entry
sib|gate|gate scripts: lock-graph, name, fakehash guards; their bats

## §C CONSTRAINTS

- README: what is frozen & how (`.` R6–R9), consumer wiring (input + overlay), `trusted-users` trap (substituter ignored for untrusted user, nix-hk §C), cached systems (Linux only), when to pick `codebuff-baseline`, telemetry (PostHog ⊥ off switch; `shipLogs = false`), licence.
- `LLM-DISCLAIMER.md` = public defect record (`paradigm/V33`); counts generated, ⊥ typed (`paradigm/V34`).
- ⊥ private repo named (`.:V6`).

## §I INTERFACES

- page: `README.md`, `docs/SECURITY.md`, `docs/CONTRIBUTING.md`, `docs/LLM-DISCLAIMER.md`.

## §V INVARIANTS

V1: README states ∀ wrapper env var & what it closes (`pkgs` §C).
V2: README states telemetry ⊥ fully switchable.

## §T TASKS

id|status|task|cites
T1|x|README|V1,V2
T2|x|SECURITY, CONTRIBUTING, LLM-DISCLAIMER in full; "planned" CI & bump wording ! follow root T12 when CI lands|-

## §B BUGS

id|date|cause|fix
