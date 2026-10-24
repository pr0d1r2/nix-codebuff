#!/usr/bin/env bats
# scripts/bump.sh (scripts T1, V1-V4, pkgs:V6): the upstream bump. gh and
# nix are stubs through the GH and NIX seams; the release list is a
# two-page fixture shaped like `gh api --paginate` output. No network.

bats_require_minimum_version 1.5.0

setup() {
  bump="$BATS_TEST_DIRNAME/../../../scripts/bump.sh"
  fixtures="$BATS_TEST_DIRNAME/fixtures/bump"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir -p stubs pkgs/codebuff
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  export STUB_RELEASES="$BATS_TEST_TMPDIR/releases.json"
  cp "$fixtures/releases.json" "$STUB_RELEASES"
  cat >stubs/gh <<'EOF'
#!/usr/bin/env bash
echo "gh $*" >>"$STUB_LOG"
[ -z "${STUB_FAIL:-}" ] || exit "$STUB_FAIL"
cat "$STUB_RELEASES"
EOF
  # prefetch answers the GitHub digest of the asset at that URL, or all-f
  # for STUB_BAD_URL; hash convert turns hex into SRI as nix does.
  cat >stubs/nix <<'EOF'
#!/usr/bin/env bash
echo "nix $*" >>"$STUB_LOG"
hex=${!#}
case "$1 $2" in
"store prefetch-file")
  [ -z "${STUB_PREFETCH_FAIL:-}" ] || exit "$STUB_PREFETCH_FAIL"
  hex=$(jq -rn --arg u "${!#}" '[inputs[].assets[] | select(.browser_download_url == $u)][0].digest | ltrimstr("sha256:")' "$STUB_RELEASES")
  [ "${!#}" = "${STUB_BAD_URL:-}" ] && hex=ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
  sri="sha256-$(printf "$(sed 's/../\\x&/g' <<<"$hex")" | base64)"
  jq -n --arg h "$sri" '{hash: $h, storePath: "/nix/store/stub"}'
  ;;
"hash convert")
  echo "sha256-$(printf "$(sed 's/../\\x&/g' <<<"$hex")" | base64)"
  ;;
*) exit 9 ;;
esac
EOF
  chmod +x stubs/gh stubs/nix
  export GH="$BATS_TEST_TMPDIR/stubs/gh"
  export NIX="$BATS_TEST_TMPDIR/stubs/nix"
  export SOURCES="$BATS_TEST_TMPDIR/pkgs/codebuff/sources.json"
  url=https://github.com/CodebuffAI/codebuff-community/releases/download/v1.0.689
}

@test "picks the newest stable v* among freebuff, beta, draft and older tags, and writes the golden sources.json" {
  cp "$fixtures/sources-1.0.688.json" "$SOURCES"
  run --separate-stderr "$bump"
  [ "$status" -eq 0 ]
  [ "$output" = 1.0.689 ]
  [ "$stderr" = "bump: 1.0.688 -> 1.0.689" ]
  cmp "$SOURCES" "$fixtures/sources-1.0.689.json"
}

@test "lists releases with gh api --paginate, never releases/latest" {
  cp "$fixtures/sources-1.0.688.json" "$SOURCES"
  run --separate-stderr "$bump"
  [ "$status" -eq 0 ]
  grep -Fx "gh api --paginate repos/CodebuffAI/codebuff-community/releases" "$STUB_LOG"
  [ "$(grep -c '^gh ' "$STUB_LOG")" -eq 1 ]
}

@test "prefetches exactly the five targets by canonical URL as sha256" {
  cp "$fixtures/sources-1.0.688.json" "$SOURCES"
  run --separate-stderr "$bump"
  [ "$status" -eq 0 ]
  for target in darwin-arm64 darwin-x64 linux-arm64 linux-x64 linux-x64-baseline; do
    grep -Fx "nix store prefetch-file --json --hash-type sha256 $url/codebuff-$target.tar.gz" "$STUB_LOG"
  done
  [ "$(grep -c '^nix store prefetch-file' "$STUB_LOG")" -eq 5 ]
}

@test "--check with a newer release exits 0, names it, and writes nothing" {
  cp "$fixtures/sources-1.0.688.json" "$SOURCES"
  run --separate-stderr "$bump" --check
  [ "$status" -eq 0 ]
  [ "$output" = 1.0.689 ]
  cmp "$SOURCES" "$fixtures/sources-1.0.688.json"
  run grep -c '^nix ' "$STUB_LOG"
  [ "$output" = 0 ]
}

@test "--check when up to date exits 3" {
  cp "$fixtures/sources-1.0.689.json" "$SOURCES"
  run --separate-stderr "$bump" --check
  [ "$status" -eq 3 ]
  [ -z "$output" ]
}

@test "up to date exits 3 and leaves sources.json untouched" {
  cp "$fixtures/sources-1.0.689.json" "$SOURCES"
  cp "$SOURCES" before.json
  touch -t 202001010000 "$SOURCES"
  run --separate-stderr "$bump"
  [ "$status" -eq 3 ]
  [ "$stderr" = "bump: up to date at 1.0.689" ]
  cmp "$SOURCES" before.json
  [ -z "$(find "$SOURCES" -newer before.json)" ]
}

@test "never downgrades: a current version above the newest stable exits 3" {
  jq '.version = "1.0.700"' "$fixtures/sources-1.0.689.json" >"$SOURCES"
  cp "$SOURCES" before.json
  run --separate-stderr "$bump"
  [ "$status" -eq 3 ]
  cmp "$SOURCES" before.json
}

@test "a release missing a target asset is refused, sources.json byte-identical, target named" {
  cp "$fixtures/sources-1.0.688.json" "$SOURCES"
  cp "$SOURCES" before.json
  jq -n '[inputs] | .[1][0].assets |= map(select(.name != "codebuff-linux-arm64.tar.gz")) | .[]' "$fixtures/releases.json" >"$STUB_RELEASES"
  run --separate-stderr "$bump"
  [ "$status" -eq 1 ]
  [ "$stderr" = "bump: v1.0.689 has no asset codebuff-linux-arm64.tar.gz for target linux-arm64; sources.json untouched (scripts V2)" ]
  cmp "$SOURCES" before.json
  [ "$(ls pkgs/codebuff)" = sources.json ]
}

@test "a prefetch hash that disagrees with GitHub's digest is refused, both hashes named, nothing written" {
  cp "$fixtures/sources-1.0.688.json" "$SOURCES"
  cp "$SOURCES" before.json
  export STUB_BAD_URL="$url/codebuff-linux-x64.tar.gz"
  run --separate-stderr "$bump"
  [ "$status" -eq 1 ]
  [ "$stderr" = "bump: v1.0.689 linux-x64: prefetch sha256-//////////////////////////////////////////8= != GitHub digest sha256-REREREREREREREREREREREREREREREREREREREREREQ=; sources.json untouched (scripts V4)" ]
  cmp "$SOURCES" before.json
  [ "$(ls pkgs/codebuff)" = sources.json ]
}

@test "an asset without a GitHub digest is refused" {
  cp "$fixtures/sources-1.0.688.json" "$SOURCES"
  cp "$SOURCES" before.json
  jq -n '[inputs] | .[1][0].assets[0].digest = null | .[]' "$fixtures/releases.json" >"$STUB_RELEASES"
  run --separate-stderr "$bump"
  [ "$status" -eq 1 ]
  [ "$stderr" = "bump: v1.0.689 darwin-arm64: GitHub gives no sha256 digest to check against; sources.json untouched (scripts V4)" ]
  cmp "$SOURCES" before.json
}

@test "the first bump, with no sources.json, creates it and its directory" {
  rm -r pkgs
  run --separate-stderr "$bump"
  [ "$status" -eq 0 ]
  [ "$stderr" = "bump: 0.0.0 -> 1.0.689" ]
  cmp "$SOURCES" "$fixtures/sources-1.0.689.json"
  [ "$(ls pkgs/codebuff)" = sources.json ]
}

@test "a release list with no stable v* tag is refused" {
  jq -n '[inputs[] | select(.tag_name | startswith("freebuff"))]' "$fixtures/releases.json" >"$STUB_RELEASES"
  run --separate-stderr "$bump"
  [ "$status" -eq 1 ]
  [ "$stderr" = "bump: no stable v<major>.<minor>.<patch> release found (scripts V3)" ]
  [ ! -e "$SOURCES" ]
}

@test "gh failing, even with exit 3, is a refusal, never up to date" {
  cp "$fixtures/sources-1.0.688.json" "$SOURCES"
  cp "$SOURCES" before.json
  STUB_FAIL=3 run --separate-stderr "$bump"
  [ "$status" -eq 1 ]
  [ "$stderr" = "bump: listing CodebuffAI/codebuff-community releases failed; sources.json untouched" ]
  cmp "$SOURCES" before.json
}

@test "a failing prefetch is a refusal, nothing written" {
  cp "$fixtures/sources-1.0.688.json" "$SOURCES"
  cp "$SOURCES" before.json
  STUB_PREFETCH_FAIL=2 run --separate-stderr "$bump"
  [ "$status" -eq 1 ]
  [ "$stderr" = "bump: v1.0.689 darwin-arm64: hashing $url/codebuff-darwin-arm64.tar.gz failed; sources.json untouched" ]
  cmp "$SOURCES" before.json
  [ "$(ls pkgs/codebuff)" = sources.json ]
}

@test "an unknown argument is a usage error, exit 2" {
  run --separate-stderr "$bump" --nope
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: bump.sh [--check]" ]
}

@test "two arguments are a usage error, exit 2" {
  run --separate-stderr "$bump" --check --check
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: bump.sh [--check]" ]
}
