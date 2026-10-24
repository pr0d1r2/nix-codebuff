#!/usr/bin/env bash
# The frozen check (nix:V1, nix §I `frozen`, root V3, D4): run
# `BIN --version` offline on a fresh HOME, with every proxy variable
# pointing at a loopback listener that logs each connection it accepts.
# A darwin build sandbox may allow network (nix §C), so a proxy-aware
# fetch is caught here rather than reaching the internet. It passes only
# if BIN exits 0, its stdout contains VERSION, the listener saw no
# connection, and afterwards HOME holds no executable regular file, no
# file named codebuff, no *.tar.gz and no *.part (the npm launcher's
# download, R6). Each finding is one line on stderr naming the rule.
# Usage: frozen.sh BIN VERSION
#   exit 0 frozen, 1 a finding, 2 usage.
# Env seams: SOCAT (default socat), the listener, run as
# `socat -d -d TCP-LISTEN:0,bind=127.0.0.1,fork /dev/null` and read from
# its log lines `listening on ... 127.0.0.1:<port>` and `accepting
# connection from` (socat 1.8.1.3); TIMEOUT (default timeout), which
# bounds the run at 30 s so a BIN that waits on the network fails.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: frozen.sh BIN VERSION" >&2
  exit 2
fi
bin=$1
version=$2
socat=${SOCAT:-socat}
timeout=${TIMEOUT:-timeout}
[[ $bin == */* ]] && bin=$(cd "$(dirname "$bin")" && pwd)/$(basename "$bin")

work=$(mktemp -d)
listener=
trap '[ -z "$listener" ] || kill "$listener" 2>/dev/null || true; chmod -R u+w "$work" 2>/dev/null || true; rm -rf "$work"' EXIT
mkdir "$work/home" "$work/cwd"

"$socat" -d -d TCP-LISTEN:0,bind=127.0.0.1,fork /dev/null 2>"$work/listener.log" &
listener=$!
port=
for _ in $(seq 100); do
  port=$(sed -n 's/.* listening on .*127\.0\.0\.1:\([0-9][0-9]*\)$/\1/p' "$work/listener.log" | head -n1)
  [ -z "$port" ] || break
  kill -0 "$listener" 2>/dev/null || break
  sleep 0.1
done
if [ -z "$port" ]; then
  echo "frozen: the loopback listener did not start; nothing would count connections (nix:V1)" >&2
  exit 1
fi

proxy=http://127.0.0.1:$port
unset NO_PROXY no_proxy
export HOME=$work/home HTTP_PROXY=$proxy HTTPS_PROXY=$proxy ALL_PROXY=$proxy
export http_proxy=$proxy https_proxy=$proxy all_proxy=$proxy
code=0
(cd "$work/cwd" && "$timeout" 30 "$bin" --version </dev/null >"$work/stdout" 2>"$work/stderr") || code=$?

# A connection BIN opened just before it exited may still be in the
# accept queue; give the listener a moment to log it.
sleep 0.3
kill "$listener" 2>/dev/null || true
wait "$listener" 2>/dev/null || true
listener=

findings=0
if [ "$code" -eq 124 ]; then
  echo "frozen: BIN --version timed out after 30 s (root V3)" >&2
  findings=1
elif [ "$code" -ne 0 ]; then
  echo "frozen: BIN --version exited $code, not 0 (root V3)" >&2
  findings=1
fi
if ! grep -qF -- "$version" "$work/stdout"; then
  echo "frozen: BIN --version stdout does not contain $version (root V3)" >&2
  findings=1
fi
seen=$(grep -c 'accepting connection from' "$work/listener.log" || true)
if [ "$seen" -ne 0 ]; then
  echo "frozen: the loopback proxy saw $seen connection(s); BIN must make none (nix:V1)" >&2
  findings=1
fi
while IFS= read -r file; do
  echo "frozen: HOME holds an executable file: $file (nix:V1)" >&2
  findings=1
done < <(cd "$HOME" && find . -type f \( -perm -u=x -o -perm -g=x -o -perm -o=x \) | sed 's|^\./||' | sort)
while IFS= read -r file; do
  echo "frozen: HOME holds a file named codebuff: $file (nix:V1)" >&2
  findings=1
done < <(cd "$HOME" && find . -name codebuff | sed 's|^\./||' | sort)
while IFS= read -r file; do
  echo "frozen: HOME holds a download: $file (nix:V1)" >&2
  findings=1
done < <(cd "$HOME" && find . \( -name '*.tar.gz' -o -name '*.part' \) | sed 's|^\./||' | sort)
exit "$findings"
