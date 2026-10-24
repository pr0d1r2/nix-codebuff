#!/usr/bin/env bats
# scripts/checks/tree-sitter.sh (nix:V2, nix §I `tree-sitter`, R9): the
# wrapped BIN's `--smoke-tree-sitter` resolves the store wasm, no URL.
# BIN is a fake makeWrapper script over a fake binary that prints the
# diag lines the real 1.0.688 prints (measured in a nix build): it
# resolves the tree-sitter.wasm beside itself, else `<none>` and exit 1.

bats_require_minimum_version 1.5.0

setup() {
  check="$BATS_TEST_DIRNAME/../../../../scripts/checks/tree-sitter.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  out="$BATS_TEST_TMPDIR/out"
  lib="$out/libexec/codebuff"
  mkdir -p "$out/bin" "$lib" stubs
  printf '\0asm' >"$lib/tree-sitter.wasm"
  export FAKE_LOG="$BATS_TEST_TMPDIR/fake.log"
  cat >"$lib/codebuff" <<'EOF'
#!/usr/bin/env bash
dir=$(cd "$(dirname "$0")" && pwd)
echo "cwd=$PWD home=$HOME args=$*" >"$FAKE_LOG"
ls -A >>"$FAKE_LOG"
sibling=$dir/tree-sitter.wasm
[ -f "$sibling" ] || sibling='<none>'
[ -z "${FAKE_RESOLVED:-}" ] || sibling=$FAKE_RESOLVED
{
  echo "[pre-init diag] argv[0]=bun"
  echo "[pre-init diag] execPath=$dir/codebuff"
  echo "[pre-init diag] candidates=[\"$PWD/tree-sitter.wasm\",\"$dir/tree-sitter.wasm\"]"
  echo "[pre-init diag] resolved siblingPath=$sibling"
  echo
  [ -z "${FAKE_URL:-}" ] || echo "[smoke diag] fetching https://unpkg.com/web-tree-sitter@0.25.10/tree-sitter.wasm"
  echo "[smoke diag] siblingPath=$dir/tree-sitter.wasm"
} >&2
if [ "$sibling" = '<none>' ]; then
  echo "tree-sitter smoke FAIL: no wasm available — pre-init published nothing and the sibling-of-execPath fallback also missed. See the diag above for paths." >&2
  exit 1
fi
echo "tree-sitter smoke ok (wasmBinary, 4 bytes)"
EOF
  chmod +x "$lib/codebuff"
  # The wrapper in makeWrapper's own form, as in the real store path.
  cat >"$out/bin/codebuff" <<EOF
#! /usr/bin/env bash
export CODEBUFF_TREE_SITTER_WASM_PATH='$lib/tree-sitter.wasm'
unset BUN_BE_BUN
exec "$lib/codebuff"  "\$@"
EOF
  chmod +x "$out/bin/codebuff"
  bin="$out/bin/codebuff"
}

@test "a wrapper whose binary resolves the wasm it sets passes, quietly" {
  run --separate-stderr "$check" "$bin"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  grep -F "args=--smoke-tree-sitter" "$FAKE_LOG"
}

@test "BIN runs in an empty cwd with a fresh HOME, so no stray wasm is found" {
  touch tree-sitter.wasm
  run --separate-stderr "$check" "$bin"
  [ "$status" -eq 0 ]
  [ "$(wc -l <"$FAKE_LOG")" -eq 1 ]
  run ! grep -F "cwd=$BATS_TEST_TMPDIR " "$FAKE_LOG"
  run ! grep -F "home=$HOME " "$FAKE_LOG"
}

@test "a missing wasm, resolved as <none>, is refused" {
  rm "$lib/tree-sitter.wasm"
  run --separate-stderr "$check" "$bin"
  [ "$status" -eq 1 ]
  [[ $stderr == *"tree-sitter: BIN --smoke-tree-sitter exited 1, not 0 (nix:V2)"* ]]
  [[ $stderr == *"tree-sitter: BIN resolved no tree-sitter.wasm (siblingPath=<none>) (nix:V2, R9)"* ]]
  [[ $stderr == *"tree-sitter: stdout has no 'tree-sitter smoke ok' (nix:V2)"* ]]
}

@test "a wrapper without the --set is refused (nix:V2 planted violation)" {
  sed -i.bak '/CODEBUFF_TREE_SITTER_WASM_PATH/d' "$bin"
  run --separate-stderr "$check" "$bin"
  [ "$status" -eq 1 ]
  [ "$stderr" = "tree-sitter: BIN sets no CODEBUFF_TREE_SITTER_WASM_PATH (nix:V2)" ]
}

@test "a wrapper that sets a wasm other than the one resolved is refused" {
  cp "$lib/tree-sitter.wasm" other.wasm
  sed -i.bak "s|^export CODEBUFF_TREE_SITTER_WASM_PATH=.*|export CODEBUFF_TREE_SITTER_WASM_PATH='$BATS_TEST_TMPDIR/other.wasm'|" "$bin"
  run --separate-stderr "$check" "$bin"
  [ "$status" -eq 1 ]
  [ "$stderr" = "tree-sitter: BIN sets CODEBUFF_TREE_SITTER_WASM_PATH=$BATS_TEST_TMPDIR/other.wasm, but resolved $lib/tree-sitter.wasm (nix:V2)" ]
}

@test "a resolved path that is no existing tree-sitter.wasm is refused" {
  FAKE_RESOLVED=/nonexistent/tree-sitter.wasm run --separate-stderr "$check" "$bin"
  [ "$status" -eq 1 ]
  [[ $stderr == *"tree-sitter: resolved /nonexistent/tree-sitter.wasm is not an existing file named tree-sitter.wasm (nix:V2)"* ]]
  touch "$lib/grammar.wasm"
  FAKE_RESOLVED="$lib/grammar.wasm" run --separate-stderr "$check" "$bin"
  [ "$status" -eq 1 ]
  [[ $stderr == *"tree-sitter: resolved $lib/grammar.wasm is not an existing file named tree-sitter.wasm (nix:V2)"* ]]
}

@test "output naming an unpkg or jsdelivr URL is refused" {
  FAKE_URL=1 run --separate-stderr "$check" "$bin"
  [ "$status" -eq 1 ]
  [ "$stderr" = "tree-sitter: output names a run-time download URL: [smoke diag] fetching https://unpkg.com/web-tree-sitter@0.25.10/tree-sitter.wasm (R9)" ]
}

@test "a BIN that hangs is refused once TIMEOUT fires" {
  printf '#!/usr/bin/env bash\nexit 124\n' >stubs/timeout
  chmod +x stubs/timeout
  TIMEOUT="$BATS_TEST_TMPDIR/stubs/timeout" run --separate-stderr "$check" "$bin"
  [ "$status" -eq 1 ]
  [ "${stderr_lines[0]}" = "tree-sitter: BIN --smoke-tree-sitter timed out after 30 s (nix:V2)" ]
}

@test "wrong argument count is usage, exit 2" {
  run --separate-stderr "$check"
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: tree-sitter.sh BIN" ]
}
