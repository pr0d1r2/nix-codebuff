# SPEC

## §G GOAL

bash scripts CI & humans run: upstream bump writing `pkgs/codebuff/sources.json`, check scripts `nix` node loads; each w/ mirrored bats in `tests/unit/scripts/`.

## §N NAV

rel|path|lens
up|.|-
self|scripts|bash for bump & checks; mirrored bats
sib|pkgs|`pkgs/codebuff/package.nix`, `sources.json`: fetch, install, wrap
sib|nix|`nix/checks.nix`: frozen, offline, untouched, layout, overlay checks
sib|dev|dev shell flake, hook install on entry
sib|gate|gate scripts: lock-graph, name, fakehash guards; their bats
sib|docs|human pages: README, SECURITY, CONTRIBUTING, LLM-DISCLAIMER

## §C CONSTRAINTS

- `docs/SHELL.md` rules (`.` §C); env seams in header (`GH`, `NIX`, `CURL`); external tools stubbed in bats; ⊥ network in bats.
- bump: list releases via `gh api --paginate repos/CodebuffAI/codebuff-community/releases`; keep tag `^v[0-9]+\.[0-9]+\.[0-9]+$`, `prerelease == false`, `draft == false`; pick max by semver (⊥ by date, ⊥ `releases/latest`) (`.` §C, R1).
- bump: newer than `sources.json` version → ∀ 5 targets: asset ∃ in release else refuse; hash = `nix store prefetch-file --json <url>` SRI; GitHub `digest` `sha256:<hex>` → SRI; disagree → refuse. write `sources.json` once, after ∀ 5 pass (atomic: temp file + `mv`).
- bump ⊥ edits any file but `sources.json`; ⊥ commits, ⊥ pushes (workflow does, `.` T14).
- `upstream.yml`: daily cron + `workflow_dispatch`; run bump; newer release & ⊥ PR token → job red w/ version in log, ⊥ branch push (lesson from `pr0d1r2/nix-hk`: Actions here ⊥ open PRs, branch w/o PR stalls idempotency).

## §I INTERFACES

- cmd: `scripts/bump.sh` → exit 0 bumped, 3 up to date, 1 refused (stderr names missing target | hash mismatch). `--check` → exit 3 up to date, 0 newer exists, writes nothing.
- cmd: `scripts/checks/<name>.sh` per `nix` §I check.
- env: `GH_TOKEN` (CI).

## §V INVARIANTS

V1: bump writes only `pkgs/codebuff/sources.json` (`pkgs:V6`, D5).
V2: bump refuses release missing ∀ 1 of 5 target assets: exit 1, `sources.json` byte-unchanged (D5).
V3: bump ⊥ picks prerelease, draft, `freebuff-*`, `v*-beta.N`; ⊥ downgrades.
V4: bump refuses when prefetch SRI ≠ GitHub `digest`.
V5: ∀ script has mirrored bats & passes w/ stubs only; orphan bats fails.

## §T TASKS

id|status|task|cites
T1|.|`bump.sh` + fixtures (release list w/ freebuff & beta tags, missing asset, digest mismatch)|V1,V2,V3,V4
T2|.|`checks/*.sh` per `nix` node|V5
T3|.|`upstream.yml` via `.actlith`|V1

## §B BUGS

id|date|cause|fix
