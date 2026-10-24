#!/usr/bin/env bats
# scripts/checks/layout.sh (pkgs:V3, pkgs:V4, pkgs §I out): the package
# tree and its wrapper's text. OUT is a fake tree; its wrapper copies
# the makeWrapper forms of the real 1.0.688 store path, read, never run.

bats_require_minimum_version 1.5.0

setup() {
  check="$BATS_TEST_DIRNAME/../../../../scripts/checks/layout.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  out="$BATS_TEST_TMPDIR/out"
  lib="$out/libexec/codebuff"
  rg="$BATS_TEST_TMPDIR/ripgrep/bin/rg"
  mkdir -p "$out/bin" "$lib" "$(dirname "$rg")"
  printf '#!/bin/sh\n' >"$lib/codebuff"
  printf '\0asm' >"$lib/tree-sitter.wasm"
  printf '#!/bin/sh\n' >"$rg"
  chmod +x "$lib/codebuff" "$rg"
  cat >"$out/bin/codebuff" <<EOF
#! /nix/store/i61an8hk5k726kqp1v2mp2ziczjs9krd-bash-5.3p9/bin/bash -e
export CODEBUFF_TREE_SITTER_WASM_PATH='$lib/tree-sitter.wasm'
export CODEBUFF_RG_PATH=\${CODEBUFF_RG_PATH-'$rg'}
unset BUN_BE_BUN
export CODEBUFF_SHIP_LOGS='false'
exec "$lib/codebuff"  "\$@"
EOF
  chmod +x "$out/bin/codebuff"
  ln -s codebuff "$out/bin/cb"
}

@test "the makeWrapper layout passes, quietly" {
  run --separate-stderr "$check" "$out"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
}

@test "a missing cb is refused (pkgs:V4)" {
  rm "$out/bin/cb"
  run --separate-stderr "$check" "$out"
  [ "$status" -eq 1 ]
  [ "${stderr_lines[0]}" = "layout: $out/bin holds codebuff, not exactly cb codebuff (pkgs:V4)" ]
  [ "${stderr_lines[1]}" = "layout: $out/bin/cb is not a symlink (pkgs:V4)" ]
}

@test "an extra file in bin is refused (pkgs:V4)" {
  touch "$out/bin/rg"
  run --separate-stderr "$check" "$out"
  [ "$status" -eq 1 ]
  [ "$stderr" = "layout: $out/bin holds cb codebuff rg, not exactly cb codebuff (pkgs:V4)" ]
}

@test "a cb that is a copy, not a symlink, is refused (pkgs:V4)" {
  rm "$out/bin/cb"
  cp "$out/bin/codebuff" "$out/bin/cb"
  run --separate-stderr "$check" "$out"
  [ "$status" -eq 1 ]
  [ "$stderr" = "layout: $out/bin/cb is not a symlink (pkgs:V4)" ]
}

@test "a cb symlink to something else is refused (pkgs:V4)" {
  ln -sf ../libexec/codebuff/codebuff "$out/bin/cb"
  run --separate-stderr "$check" "$out"
  [ "$status" -eq 1 ]
  [ "$stderr" = "layout: $out/bin/cb does not resolve to $out/bin/codebuff (pkgs:V4)" ]
}

@test "a missing libexec file is refused" {
  rm "$lib/tree-sitter.wasm"
  run --separate-stderr "$check" "$out"
  [ "$status" -eq 1 ]
  [ "${stderr_lines[0]}" = "layout: $lib/tree-sitter.wasm does not exist (pkgs §I)" ]
}

@test "a wrapper without the wasm --set is refused (pkgs:V3)" {
  sed -i.bak '/CODEBUFF_TREE_SITTER_WASM_PATH/d' "$out/bin/codebuff"
  rm "$out/bin/codebuff.bak"
  run --separate-stderr "$check" "$out"
  [ "$status" -eq 1 ]
  [ "$stderr" = "layout: the wrapper sets no CODEBUFF_TREE_SITTER_WASM_PATH (pkgs:V3, R9)" ]
}

@test "a wrapper whose wasm path is not the libexec file is refused (pkgs:V3)" {
  sed -i.bak "s|^export CODEBUFF_TREE_SITTER_WASM_PATH=.*|export CODEBUFF_TREE_SITTER_WASM_PATH='/nonexistent/tree-sitter.wasm'|" "$out/bin/codebuff"
  rm "$out/bin/codebuff.bak"
  run --separate-stderr "$check" "$out"
  [ "$status" -eq 1 ]
  [ "$stderr" = "layout: the wrapper sets CODEBUFF_TREE_SITTER_WASM_PATH=/nonexistent/tree-sitter.wasm, not the existing $lib/tree-sitter.wasm (pkgs:V3, R9)" ]
}

@test "a wrapper without a CODEBUFF_RG_PATH default is refused (pkgs:V3)" {
  sed -i.bak '/CODEBUFF_RG_PATH/d' "$out/bin/codebuff"
  rm "$out/bin/codebuff.bak"
  run --separate-stderr "$check" "$out"
  [ "$status" -eq 1 ]
  [ "$stderr" = "layout: the wrapper sets no default CODEBUFF_RG_PATH (pkgs:V3, R8)" ]
}

@test "a forced CODEBUFF_RG_PATH (--set, not --set-default) is refused (pkgs:V3)" {
  sed -i.bak "s|^export CODEBUFF_RG_PATH=.*|export CODEBUFF_RG_PATH='$rg'|" "$out/bin/codebuff"
  rm "$out/bin/codebuff.bak"
  run --separate-stderr "$check" "$out"
  [ "$status" -eq 1 ]
  [ "$stderr" = "layout: the wrapper sets no default CODEBUFF_RG_PATH (pkgs:V3, R8)" ]
}

@test "a CODEBUFF_RG_PATH default that is no executable is refused (pkgs:V3)" {
  chmod -x "$rg"
  run --separate-stderr "$check" "$out"
  [ "$status" -eq 1 ]
  [ "$stderr" = "layout: the wrapper's default CODEBUFF_RG_PATH=$rg is not an existing executable (pkgs:V3, R8)" ]
}

@test "a wrapper that keeps BUN_BE_BUN is refused (pkgs:V3)" {
  sed -i.bak '/^unset BUN_BE_BUN$/d' "$out/bin/codebuff"
  rm "$out/bin/codebuff.bak"
  run --separate-stderr "$check" "$out"
  [ "$status" -eq 1 ]
  [ "$stderr" = "layout: the wrapper does not unset BUN_BE_BUN (pkgs:V3, R15)" ]
}

@test "a wrapper that execs something but the libexec binary is refused" {
  sed -i.bak "s|^exec .*|exec \"$BATS_TEST_TMPDIR/other\" \"\$@\"|" "$out/bin/codebuff"
  rm "$out/bin/codebuff.bak"
  run --separate-stderr "$check" "$out"
  [ "$status" -eq 1 ]
  [ "$stderr" = "layout: the wrapper does not exec $lib/codebuff (pkgs §C)" ]
}

@test "wrong argument count is usage, exit 2" {
  run --separate-stderr "$check"
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: layout.sh OUT" ]
}
