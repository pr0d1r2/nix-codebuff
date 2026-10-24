#!/usr/bin/env bash
# The upstream bump (scripts T1). Lists CodebuffAI/codebuff-community
# releases with `gh api --paginate`, never `releases/latest`; keeps tags
# v<major>.<minor>.<patch> that are neither draft nor prerelease, so no
# freebuff-*, no v*-beta.N, and picks the highest by number, never by
# date (scripts V3). Never downgrades: newest <= sources.json version is
# up to date. Every one of the five targets needs its asset (scripts V2);
# each hash is `nix store prefetch-file`'s SRI and must equal GitHub's
# sha256 digest (scripts V4). Only then is sources.json written, once,
# atomically; nothing else is written, committed or pushed (scripts V1,
# pkgs:V6). URLs are the release download URL (root V2).
# Usage: bump.sh [--check]
#   exit 0 bumped (--check: a newer release exists; writes nothing),
#   3 up to date, 1 refused, 2 usage. The new version goes to stdout.
# Env seams: GH (default gh), NIX (default nix), SOURCES (default
# pkgs/codebuff/sources.json beside this script's repository).
set -euo pipefail

gh=${GH:-gh}
nix=${NIX:-nix}
sources=${SOURCES:-$(dirname "${BASH_SOURCE[0]}")/../pkgs/codebuff/sources.json}
repo=CodebuffAI/codebuff-community
targets="darwin-arm64 darwin-x64 linux-arm64 linux-x64 linux-x64-baseline"

check=false
case "$#:${1:-}" in
0:) ;;
1:--check) check=true ;;
*)
  echo "usage: bump.sh [--check]" >&2
  exit 2
  ;;
esac

current=0.0.0
[ -e "$sources" ] && current=$(jq -r .version "$sources")

# gh --paginate prints one JSON array per page; merge them.
# A failing tool is a refusal (exit 1), never mistaken for exit 2 or 3.
if ! releases=$("$gh" api --paginate "repos/$repo/releases" | jq -c -n '[inputs[]]'); then
  echo "bump: listing $repo releases failed; sources.json untouched" >&2
  exit 1
fi
newest=$(jq -r '.[] | select(.draft == false and .prerelease == false) | .tag_name
  | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) | ltrimstr("v")' <<<"$releases" |
  sort -t. -k1,1n -k2,2n -k3,3n | tail -n1)
if [ -z "$newest" ]; then
  echo "bump: no stable v<major>.<minor>.<patch> release found (scripts V3)" >&2
  exit 1
fi
highest=$(printf '%s\n' "$current" "$newest" | sort -t. -k1,1n -k2,2n -k3,3n | tail -n1)
if [ "$newest" = "$current" ] || [ "$highest" = "$current" ]; then
  echo "bump: up to date at $current" >&2
  exit 3
fi
if [ "$check" = true ]; then
  echo "$newest"
  exit 0
fi

tag=v$newest
release=$(jq -c --arg t "$tag" 'map(select(.tag_name == $t))[0]' <<<"$releases")
missing=false
for target in $targets; do
  name=codebuff-$target.tar.gz
  if ! jq -e --arg n "$name" 'any(.assets[]; .name == $n)' <<<"$release" >/dev/null; then
    echo "bump: $tag has no asset $name for target $target; sources.json untouched (scripts V2)" >&2
    missing=true
  fi
done
[ "$missing" = false ] || exit 1

assets='{}'
for target in $targets; do
  name=codebuff-$target.tar.gz
  url=https://github.com/$repo/releases/download/$tag/$name
  digest=$(jq -r --arg n "$name" '.assets[] | select(.name == $n) | .digest // ""' <<<"$release")
  hex=${digest#sha256:}
  if [ "$hex" = "$digest" ] || ! [[ "$hex" =~ ^[0-9a-f]{64}$ ]]; then
    echo "bump: $tag $target: GitHub gives no sha256 digest to check against; sources.json untouched (scripts V4)" >&2
    exit 1
  fi
  if ! github=$("$nix" hash convert --hash-algo sha256 --to sri "$hex") ||
    ! prefetch=$("$nix" store prefetch-file --json --hash-type sha256 "$url" | jq -r .hash); then
    echo "bump: $tag $target: hashing $url failed; sources.json untouched" >&2
    exit 1
  fi
  if [ "$prefetch" != "$github" ]; then
    echo "bump: $tag $target: prefetch $prefetch != GitHub digest $github; sources.json untouched (scripts V4)" >&2
    exit 1
  fi
  assets=$(jq -c --arg t "$target" --arg u "$url" --arg h "$prefetch" \
    '. + {($t): {url: $u, hash: $h}}' <<<"$assets")
done

dir=$(dirname "$sources")
mkdir -p "$dir"
tmp=$(mktemp "$dir/.sources.json.XXXXXX")
trap 'rm -f "$tmp"' EXIT
jq -S -n --arg v "$newest" --argjson a "$assets" '{version: $v, assets: $a}' >"$tmp"
chmod 644 "$tmp"
mv "$tmp" "$sources"
echo "bump: $current -> $newest" >&2
echo "$newest"
