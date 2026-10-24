# Contributing to nix-codebuff

Thanks for looking. This page says how a change lands here: the shell you
work in, the gate that checks it, and the order things happen in.

## Getting set up

Enter the dev shell with `direnv allow` (the `.envrc` runs
`use flake ./dev`) or `nix develop ./dev`. Every tool the gate runs comes
from it, pinned by `dev/flake.lock` on the same nixpkgs as the root flake.
The root flake keeps its one input; gate tools never go there.

On entry the shell runs `scripts/dev/shell-hook.sh`, which points git at
the tracked hooks (`git config --local core.hooksPath .githooks`). If hk
is not on `PATH` it says so and installs nothing. On `x86_64-darwin` some
fleet tools have no build (as of 2026-10-24: microlith, itok, pklith,
xenolith); the shell names the ones it left out, and a gate step that
needs one fails rather than skipping.

## The gate

The hooks in `.githooks/` run hk, and refuse when hk is missing: a gate
that cannot run has not passed.

- **pre-commit** runs every step but the bats suite on what you staged:
  lint, format, spelling, the name, path, hash and secret guards, the
  lock-graph guard, and the spec checks. It checks only and never stashes, because the git stash is
  shared by every worktree. Fixes are yours to run: `hk fix --all`.
- **pre-push** runs every step, including the whole bats suite.
- `hk check --all` runs every step by hand.

Never use `--no-verify`. When the gate refuses, it is working, and its
message says what to do.

The steps are rows in `.pklith`. `pklith gen` writes `hk.pklith.pkl` and
`nix/pklith.nix` from them, and `gen-check` fails when those drift. A new
step lands in its own commit, with proof in the commit body that it
refuses a planted violation.

## Spec first

[`SPEC.md`](../SPEC.md) at the root and one `SPEC.md` per node (`pkgs/`,
`nix/`, `scripts/`, `dev/`, `gate/`, `docs/`) are the law. A change to
behaviour starts there, and the code follows. The spec files use the
compact encoding described in [`FORMAT.md`](../FORMAT.md) and
[`FORMAT-EXTENSIONS.md`](../FORMAT-EXTENSIONS.md); the gate runs
`mth fmt` and `mth check` (microlith) and `sherd check`, `sherd nav` and
`sherd budget` on them. Facts in the spec carry the date they were
measured and the command that measured them.

Some files are not edited at all: `FORMAT.md` and `FORMAT-EXTENSIONS.md`
are vendored byte for byte from paradigm, and `SPEC-PROMPT.md` is the
frozen input of the first spec run.

The human pages (this one, the README, `SECURITY.md`,
`LLM-DISCLAIMER.md`) explain the spec in prose and can lag behind it.
When they disagree, the spec wins; fix the page.

## Shell and tests

Shell lives in `scripts/` and `gate/`, never inline in a `.nix` file.
One script does one job, defines no functions besides `info`, `warn` and
`fatal`, and names its environment seams in its header.

Every script has a bats test mirrored by path, and no test outlives its
script: `scripts/checks/frozen.sh` is tested by
`tests/unit/scripts/checks/frozen.bats`, `gate/name-guard.sh` by
`tests/unit/gate/name-guard.bats`. `pklith check` enforces the mirror
both ways. Tests stub every external tool and use no network.

Tests come first. A new script lands as two commits: `test(...): RED ...`
with the failing test, then `feat(...): GREEN ...` with the script that
passes it. The gate does not check this order yet (pklith v0.1.0 has no
rule for it), so review does.

Run the suite with `bats --recursive tests`.

## Commits

- One topic per commit.
- Subject `type(scope): claim (spec ids)`, for example
  `feat(scripts): GREEN layout check (scripts T2)`.
- The body says why, and what was checked or measured.
- The trailers sit together in the last paragraph, with
  `Paradigm-Stage:` naming the stage the commit belongs to, for example
  `Paradigm-Stage: wave-6`. A blank line between trailers hides the ones
  above it from git.

## Bumping Codebuff

1. `scripts/bump.sh --check` says whether a newer stable release exists.
2. `scripts/bump.sh` rewrites `pkgs/codebuff/sources.json`, and nothing
   else, once every target's hash agrees with GitHub's digest. Never edit
   `sources.json` by hand.
3. Build and check: `nix build .#codebuff` and `nix flake check`.
4. Commit `sources.json` on its own.

A daily workflow, `.github/workflows/upstream.yml`, runs `scripts/bump.sh --check`.
Until it can open pull requests (root T14), it reports a newer release by
failing, and the bump is run by hand.

## Reporting problems

Bugs and ideas go in GitHub issues once the repository is public.
Security problems go through [`SECURITY.md`](SECURITY.md), not a public
issue.
