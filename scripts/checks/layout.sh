#!/usr/bin/env bash
# The layout check (pkgs:V3, pkgs:V4, pkgs §I out, nix §I `layout`):
# OUT/bin holds exactly codebuff and cb, cb a symlink resolving to
# codebuff; OUT/libexec/codebuff holds codebuff and tree-sitter.wasm.
# The wrapper OUT/bin/codebuff is read as text, never run, in the forms
# makeWrapper writes (seen in the 1.0.688 store path):
#   export CODEBUFF_TREE_SITTER_WASM_PATH='<path>'         (--set)
#   export CODEBUFF_RG_PATH=${CODEBUFF_RG_PATH-'<path>'}   (--set-default)
#   unset BUN_BE_BUN                                       (--unset)
#   exec "<path>"  "$@"
# The wasm path must be the libexec tree-sitter.wasm (R9), the rg
# default an existing executable (R8), BUN_BE_BUN unset (R15), and the
# exec'd file the libexec binary, so process.execPath stays beside the
# wasm (pkgs §C). Each finding is one line on stderr. pkgs:V5 (meta) is
# a nix assertion, not this script's.
# Usage: layout.sh OUT
#   exit 0 laid out, 1 a finding, 2 usage.
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: layout.sh OUT" >&2
  exit 2
fi
out=$1
bin=$out/bin
lib=$out/libexec/codebuff
wrapper=$bin/codebuff

findings=0
entries=$(find "$bin" -mindepth 1 -maxdepth 1 -exec basename {} \; 2>/dev/null | sort | tr '\n' ' ')
entries=${entries% }
if [ "$entries" != "cb codebuff" ]; then
  echo "layout: $bin holds ${entries:-nothing}, not exactly cb codebuff (pkgs:V4)" >&2
  findings=1
fi
if ! [ -L "$bin/cb" ]; then
  echo "layout: $bin/cb is not a symlink (pkgs:V4)" >&2
  findings=1
elif ! [ "$bin/cb" -ef "$wrapper" ]; then
  echo "layout: $bin/cb does not resolve to $wrapper (pkgs:V4)" >&2
  findings=1
fi
for name in codebuff tree-sitter.wasm; do
  if ! [ -f "$lib/$name" ]; then
    echo "layout: $lib/$name does not exist (pkgs §I)" >&2
    findings=1
  fi
done

if ! [ -f "$wrapper" ]; then
  echo "layout: $wrapper does not exist (pkgs:V3)" >&2
  exit 1
fi
wasm=$(sed -En "s/^export CODEBUFF_TREE_SITTER_WASM_PATH='?([^']*)'?$/\1/p" "$wrapper" | head -n1)
if [ -z "$wasm" ]; then
  echo "layout: the wrapper sets no CODEBUFF_TREE_SITTER_WASM_PATH (pkgs:V3, R9)" >&2
  findings=1
elif ! [ -f "$wasm" ] || ! [ "$wasm" -ef "$lib/tree-sitter.wasm" ]; then
  echo "layout: the wrapper sets CODEBUFF_TREE_SITTER_WASM_PATH=$wasm, not the existing $lib/tree-sitter.wasm (pkgs:V3, R9)" >&2
  findings=1
fi
rg=$(sed -En "s/^export CODEBUFF_RG_PATH=\\$\\{CODEBUFF_RG_PATH-'?([^'}]*)'?\\}$/\\1/p" "$wrapper" | head -n1)
if [ -z "$rg" ]; then
  echo "layout: the wrapper sets no default CODEBUFF_RG_PATH (pkgs:V3, R8)" >&2
  findings=1
elif ! [ -f "$rg" ] || ! [ -x "$rg" ]; then
  echo "layout: the wrapper's default CODEBUFF_RG_PATH=$rg is not an existing executable (pkgs:V3, R8)" >&2
  findings=1
fi
if ! grep -qx 'unset BUN_BE_BUN' "$wrapper"; then
  echo "layout: the wrapper does not unset BUN_BE_BUN (pkgs:V3, R15)" >&2
  findings=1
fi
target=$(sed -En 's/^exec "([^"]*)".*/\1/p' "$wrapper" | head -n1)
if [ -z "$target" ] || ! [ -f "$target" ] || ! [ "$target" -ef "$lib/codebuff" ]; then
  echo "layout: the wrapper does not exec $lib/codebuff (pkgs §C)" >&2
  findings=1
fi
exit "$findings"
