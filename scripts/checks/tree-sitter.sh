#!/usr/bin/env bash
# The tree-sitter check (nix:V2, nix §I `tree-sitter`, R9): the wrapped
# BIN finds the store tree-sitter.wasm and names no download URL.
# Runs `BIN --smoke-tree-sitter </dev/null` on a fresh HOME in an empty
# cwd (the binary tries `$PWD/tree-sitter.wasm` first). Measured on
# 1.0.688 in a nix build: it exits 0 and prints `tree-sitter smoke ok
# (wasmBinary, <n> bytes)` on stdout, its diag on stderr, among them
# `[pre-init diag] resolved siblingPath=<path>`; with no wasm it prints
# `siblingPath=<none>` and `tree-sitter smoke FAIL: ...` and exits 1.
# The smoke run ignores CODEBUFF_TREE_SITTER_WASM_PATH (it resolves the
# file beside process.execPath), so the wrapper's `--set` is read from
# BIN's own text and must name the file the binary resolved; a wrapper
# without it fails (nix:V2's planted violation).
# Passes only if BIN exits 0, stdout says `tree-sitter smoke ok`, the
# resolved path is an existing file named tree-sitter.wasm, BIN sets
# CODEBUFF_TREE_SITTER_WASM_PATH to that same file, and the output names
# no unpkg.com or jsdelivr URL. Each finding is one line on stderr.
# Usage: tree-sitter.sh BIN
#   exit 0 resolved, 1 a finding, 2 usage.
# Env seams: TIMEOUT (default timeout), bounds the run at 30 s.
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: tree-sitter.sh BIN" >&2
  exit 2
fi
bin=$1
timeout=${TIMEOUT:-timeout}
[[ $bin == */* ]] && bin=$(cd "$(dirname "$bin")" && pwd)/$(basename "$bin")

work=$(mktemp -d)
trap 'chmod -R u+w "$work" 2>/dev/null || true; rm -rf "$work"' EXIT
mkdir "$work/home" "$work/cwd"

code=0
(cd "$work/cwd" && HOME=$work/home "$timeout" 30 "$bin" --smoke-tree-sitter </dev/null >"$work/stdout" 2>"$work/stderr") || code=$?

findings=0
if [ "$code" -eq 124 ]; then
  echo "tree-sitter: BIN --smoke-tree-sitter timed out after 30 s (nix:V2)" >&2
  findings=1
elif [ "$code" -ne 0 ]; then
  echo "tree-sitter: BIN --smoke-tree-sitter exited $code, not 0 (nix:V2)" >&2
  findings=1
fi
if ! grep -q '^tree-sitter smoke ok' "$work/stdout"; then
  echo "tree-sitter: stdout has no 'tree-sitter smoke ok' (nix:V2)" >&2
  findings=1
fi

resolved=$(sed -n 's/^\[pre-init diag\] resolved siblingPath=//p' "$work/stderr" "$work/stdout" | head -n1)
if [ -z "$resolved" ]; then
  echo "tree-sitter: BIN printed no '[pre-init diag] resolved siblingPath=' line (nix:V2, R9)" >&2
  findings=1
elif [ "$resolved" = '<none>' ]; then
  echo "tree-sitter: BIN resolved no tree-sitter.wasm (siblingPath=<none>) (nix:V2, R9)" >&2
  findings=1
elif [ "$(basename "$resolved")" != tree-sitter.wasm ] || ! [ -f "$resolved" ]; then
  echo "tree-sitter: resolved $resolved is not an existing file named tree-sitter.wasm (nix:V2)" >&2
  findings=1
else
  set=$(sed -En "s/^export CODEBUFF_TREE_SITTER_WASM_PATH='?([^']*)'?$/\1/p" "$bin" | head -n1)
  if [ -z "$set" ]; then
    echo "tree-sitter: BIN sets no CODEBUFF_TREE_SITTER_WASM_PATH (nix:V2)" >&2
    findings=1
  elif ! [ "$set" -ef "$resolved" ]; then
    echo "tree-sitter: BIN sets CODEBUFF_TREE_SITTER_WASM_PATH=$set, but resolved $resolved (nix:V2)" >&2
    findings=1
  fi
fi

while IFS= read -r line; do
  echo "tree-sitter: output names a run-time download URL: $line (R9)" >&2
  findings=1
done < <(cat "$work/stdout" "$work/stderr" | grep -E 'unpkg\.com|jsdelivr' || true)
exit "$findings"
