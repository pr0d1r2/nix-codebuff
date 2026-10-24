#!/usr/bin/env bats
# gate/no-fakehash.sh (gate:V3, root V2): no placeholder hash reaches a
# commit in a nix file or the sources file.

bats_require_minimum_version 1.5.0

setup() {
  guard="$BATS_TEST_DIRNAME/../../../gate/no-fakehash.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
}

@test "a real SRI hash passes, quietly" {
  printf '{ "hash": "sha256-VSL1JPy+ZPQYb0fW2qUoUfHvtW6/qpA/hnqV1C8oUig=" }\n' >sources.json
  run --separate-stderr "$guard" sources.json
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
}

@test "lib.fakeHash is refused, by file and line" {
  printf '{\n  hash = lib.fakeHash;\n}\n' >package.nix
  run --separate-stderr "$guard" package.nix
  [ "$status" -eq 1 ]
  [ "$stderr" = "no-fakehash: package.nix:2: placeholder hash (root V2)" ]
}

@test "fakeSha256 and an all-A SRI are refused, every hit listed" {
  printf 'sha256 = lib.fakeSha256;\n' >a.nix
  printf '{ "hash": "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }\n' >sources.json
  run --separate-stderr "$guard" a.nix sources.json
  [ "$status" -eq 1 ]
  [ "${#stderr_lines[@]}" -eq 2 ]
  [ "${stderr_lines[0]}" = "no-fakehash: a.nix:1: placeholder hash (root V2)" ]
  [ "${stderr_lines[1]}" = "no-fakehash: sources.json:1: placeholder hash (root V2)" ]
}

@test "a file that is gone is skipped" {
  run --separate-stderr "$guard" gone.nix
  [ "$status" -eq 0 ]
}

@test "no file is a usage error, exit 2" {
  run --separate-stderr "$guard"
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: no-fakehash.sh FILE..." ]
}
