#!/usr/bin/env bash
# No placeholder hash in a commit (gate:V3, root V2): refuse every given
# file holding lib.fakeHash, lib.fakeSha256, lib.fakeSha512 or nixpkgs'
# all-A SRI placeholder. A hash on `main` is a real literal, written by
# the bump. Each hit is a line on stderr, then exit 1. Files that are gone
# (a staged deletion) are skipped.
# Usage: no-fakehash.sh FILE...
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: no-fakehash.sh FILE..." >&2
  exit 2
fi

pattern='fakeHash|fakeSha256|fakeSha512|sha256-A{43}='
status=0
for file in "$@"; do
  [ -f "$file" ] || continue
  while IFS= read -r line; do
    echo "no-fakehash: $file:$line: placeholder hash (root V2)" >&2
    status=1
  done < <(grep -nE -- "$pattern" "$file" | cut -d: -f1 || true)
done
exit "$status"
