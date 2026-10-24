#!/usr/bin/env bats
# scripts/dev/shell-hook.sh (dev V3, scripts T4): what the dev shell does
# on entry. git is real, in a scratch repository; hk is a stub.

bats_require_minimum_version 1.5.0

setup() {
  hook="$BATS_TEST_DIRNAME/../../../../scripts/dev/shell-hook.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir stubs repo
  printf '#!/usr/bin/env bash\n' >stubs/hk
  chmod +x stubs/hk
  export PATH="$BATS_TEST_TMPDIR/stubs:$PATH"
  cd repo || exit 1
  git init -q
  touch hk.pkl
  mkdir .githooks
}

@test "with hk, git's hooks path becomes the tracked .githooks/" {
  run --separate-stderr "$hook" x86_64-linux
  [ "$status" -eq 0 ]
  [ "$(git config --local core.hooksPath)" = .githooks ]
  [ -z "$stderr" ]
}

@test "without hk, no hooks, and the shell says so" {
  rm ../stubs/hk
  # git, bash and the stubs only: the caller's PATH may hold a real hk.
  mkdir ../bin
  for t in git bash env dirname; do ln -s "$(command -v "$t")" ../bin/; done
  PATH="$BATS_TEST_TMPDIR/stubs:$BATS_TEST_TMPDIR/bin" run --separate-stderr "$hook" x86_64-linux
  [ "$status" -eq 0 ]
  [ "$stderr" = "nix-codebuff(shell): no hk on PATH, git hooks NOT installed" ]
  run git config --local core.hooksPath
  [ "$status" -eq 1 ]
}

@test "before hk.pkl exists, no empty config ever gates a commit" {
  rm hk.pkl
  run --separate-stderr "$hook" x86_64-linux
  [ "$status" -eq 0 ]
  run git config --local core.hooksPath
  [ "$status" -eq 1 ]
}

@test "outside a git repository, nothing happens" {
  cd "$BATS_TEST_TMPDIR" || exit 1
  run --separate-stderr "$hook" x86_64-linux
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
}

@test "fleet tools with no build on the system are named" {
  run --separate-stderr "$hook" x86_64-darwin microlith pklith
  [ "$status" -eq 0 ]
  [ "$stderr" = "nix-codebuff(shell): no x86_64-darwin build of: microlith, pklith -- gates that need them FAIL here" ]
}

@test "no system is a usage error, exit 2" {
  run --separate-stderr "$hook"
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: shell-hook.sh SYSTEM [ABSENT-TOOL...]" ]
}
