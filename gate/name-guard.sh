#!/usr/bin/env bash
# Name guard, the denylist half (gate:V2, root V6, paradigm/V37). With
# the local, uncommitted denylist (one name per line, blank lines and `#`
# comments skipped), refuse every given file that holds a listed name,
# compared case-insensitively. A hit prints the file, the line and the
# entry number, never the name, so a log cannot leak it. Without a
# denylist it says so on stderr and passes: CI has none. Files that are
# gone (a staged deletion) or binary hold no text to leak and are skipped.
# Usage: name-guard.sh FILE...
# Env: NAME_GUARD_DENYLIST names the list (default .private/denylist).
set -euo pipefail

list=${NAME_GUARD_DENYLIST:-.private/denylist}
if [ ! -f "$list" ]; then
  echo "name-guard: no $list here, so no private name was checked (paradigm/V37)" >&2
  exit 0
fi

status=0
entry=0
while IFS= read -r name || [ -n "$name" ]; do
  name=${name#"${name%%[![:space:]]*}"}
  name=${name%"${name##*[![:space:]]}"}
  case "$name" in "" | "#"*) continue ;; esac
  entry=$((entry + 1))
  for file in "$@"; do
    [ -f "$file" ] || continue
    while IFS= read -r line; do
      printf 'name-guard: %s:%s: private name (denylist entry %d)\n' "$file" "$line" "$entry" >&2
      status=1
    done < <(grep -inFI -- "$name" "$file" | cut -d: -f1 || true)
  done
done <"$list"
exit "$status"
