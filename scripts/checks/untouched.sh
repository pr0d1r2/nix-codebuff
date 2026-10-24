#!/usr/bin/env bash
# The untouched check (pkgs:V1, pkgs:V2, nix §I `untouched`, D3): the
# installed binary is the release's own. Unpacks TARBALL into a temp dir
# and compares its `codebuff` and `tree-sitter.wasm` members with
# OUT/libexec/codebuff/. tree-sitter.wasm: byte-identical, every system.
# Mach-O binary (darwin): byte-identical, so the same sha256 (pkgs:V1).
# ELF binary (Linux): autoPatchelfHook may change PT_INTERP and rpath
# only, so the NEEDED set must equal the member's and the `.bun` section
# (the Bun payload, R5) must be byte-identical (pkgs:V2). objcopy dumps
# `.bun` from copies, never from OUT. The kind is read from the first 4
# bytes. Each finding is one line on stderr.
# Usage: untouched.sh OUT TARBALL
#   exit 0 untouched, 1 a finding, 2 usage.
# Env seams: READELF (default readelf), read as `readelf -d FILE`;
# OBJCOPY (default objcopy), run as
# `objcopy --dump-section .bun=DUMP IN DISCARD`. Neither runs on Mach-O.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: untouched.sh OUT TARBALL" >&2
  exit 2
fi
out=$1
tarball=$2
readelf=${READELF:-readelf}
objcopy=${OBJCOPY:-objcopy}
lib=$out/libexec/codebuff

work=$(mktemp -d)
trap 'chmod -R u+w "$work" 2>/dev/null || true; rm -rf "$work"' EXIT
mkdir "$work/member"
if ! tar -xzf "$tarball" -C "$work/member" 2>/dev/null; then
  echo "untouched: $tarball does not unpack" >&2
  exit 1
fi

findings=0
for name in codebuff tree-sitter.wasm; do
  if ! [ -f "$work/member/$name" ]; then
    echo "untouched: $tarball has no member $name" >&2
    findings=1
  fi
done
for name in codebuff tree-sitter.wasm; do
  if ! [ -f "$lib/$name" ]; then
    echo "untouched: $lib/$name does not exist" >&2
    findings=1
  fi
done
[ "$findings" -eq 0 ] || exit 1

if ! cmp -s "$lib/tree-sitter.wasm" "$work/member/tree-sitter.wasm"; then
  echo "untouched: $lib/tree-sitter.wasm is not byte-identical to the tarball member (pkgs:V1, pkgs:V2)" >&2
  findings=1
fi

magic=$(od -An -tx1 -N4 "$lib/codebuff" | tr -d ' \n')
case "$magic" in
feedface | feedfacf | cefaedfe | cffaedfe | cafebabe | bebafeca)
  if ! cmp -s "$lib/codebuff" "$work/member/codebuff"; then
    echo "untouched: $lib/codebuff is not byte-identical to the tarball member (pkgs:V1, D3)" >&2
    findings=1
  fi
  ;;
7f454c46)
  if ! installed=$("$readelf" -d "$lib/codebuff") || ! member=$("$readelf" -d "$work/member/codebuff"); then
    echo "untouched: readelf -d failed on the installed binary or the tarball member (pkgs:V2)" >&2
    exit 1
  fi
  installed=$(sed -n 's/.*(NEEDED).*\[\(.*\)\].*/\1/p' <<<"$installed" | sort -u | tr '\n' ' ')
  member=$(sed -n 's/.*(NEEDED).*\[\(.*\)\].*/\1/p' <<<"$member" | sort -u | tr '\n' ' ')
  if [ "$installed" != "$member" ]; then
    echo "untouched: NEEDED differs: installed ${installed% }, tarball ${member% } (pkgs:V2)" >&2
    findings=1
  fi
  cp "$lib/codebuff" "$work/installed"
  cp "$work/member/codebuff" "$work/original"
  dumped=true
  if ! "$objcopy" --dump-section .bun="$work/installed.bun" "$work/installed" "$work/discard" 2>/dev/null; then
    echo "untouched: $lib/codebuff has no .bun section to dump (pkgs:V2, R5)" >&2
    findings=1
    dumped=false
  fi
  if ! "$objcopy" --dump-section .bun="$work/original.bun" "$work/original" "$work/discard" 2>/dev/null; then
    echo "untouched: the tarball member has no .bun section to dump (pkgs:V2, R5)" >&2
    findings=1
    dumped=false
  fi
  if [ "$dumped" = true ] && ! cmp -s "$work/installed.bun" "$work/original.bun"; then
    echo "untouched: the .bun section differs from the tarball member's (pkgs:V2, R5)" >&2
    findings=1
  fi
  ;;
*)
  echo "untouched: $lib/codebuff is neither Mach-O nor ELF" >&2
  findings=1
  ;;
esac
exit "$findings"
