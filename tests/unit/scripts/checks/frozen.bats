#!/usr/bin/env bats
# scripts/checks/frozen.sh (nix:V1, root V3, D4): `BIN --version` offline
# behind a counting loopback proxy, on a fresh HOME. The listener is a
# python3 stand-in for socat through the SOCAT seam that speaks socat's
# `-d -d` log lines (measured on socat 1.8.1.3); every BIN is a fake. No
# network: the fakes only reach 127.0.0.1.

bats_require_minimum_version 1.5.0

setup() {
  check="$BATS_TEST_DIRNAME/../../../../scripts/checks/frozen.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir -p stubs
  export STUB_LOG="$BATS_TEST_TMPDIR/socat.args"
  cat >stubs/socat <<'EOF'
#!/usr/bin/env python3
import os, socket, sys
with open(os.environ["STUB_LOG"], "w") as f:
    f.write(" ".join(sys.argv[1:]) + "\n")
s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("127.0.0.1", 0))
s.listen(16)
port = s.getsockname()[1]
log = "2026/10/24 10:36:20 socat[1] N "
sys.stderr.write(log + "listening on LEN=16 AF=2 127.0.0.1:%d\n" % port)
sys.stderr.flush()
while True:
    c, a = s.accept()
    sys.stderr.write(log + "accepting connection from LEN=16 AF=2 127.0.0.1:%d on LEN=16 AF=2 127.0.0.1:%d\n" % (a[1], port))
    sys.stderr.flush()
    c.close()
EOF
  cat >stubs/socat-dead <<'EOF'
#!/usr/bin/env bash
echo "socat[1] E bind(5, {LEN=16 AF=2 127.0.0.1:0}, 16): Address already in use" >&2
exit 1
EOF
  chmod +x stubs/socat stubs/socat-dead
  export SOCAT="$BATS_TEST_TMPDIR/stubs/socat"
  # A clean BIN: what the real `codebuff --version` does (R16), it makes
  # ~/.config/manicode/settings.json and prints the version.
  cat >clean <<'EOF'
#!/usr/bin/env bash
mkdir -p "$HOME/.config/manicode"
echo '{}' >"$HOME/.config/manicode/settings.json"
echo 1.0.688
EOF
  chmod +x clean
}

@test "a clean BIN passes, quietly, and the listener binds loopback only" {
  run --separate-stderr "$check" ./clean 1.0.688
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  grep -F "TCP-LISTEN:0,bind=127.0.0.1,fork" "$STUB_LOG"
}

@test "the proxy env points every scheme at the listener and NO_PROXY is gone" {
  cat >bin <<'EOF'
#!/usr/bin/env bash
for v in HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy; do
  [[ ${!v} =~ ^http://127\.0\.0\.1:[0-9]+$ ]] || { echo "bad $v=${!v}" >&2; exit 7; }
done
[ -z "${NO_PROXY-}${no_proxy-}" ] || exit 8
echo 1.0.688
EOF
  chmod +x bin
  NO_PROXY='*' no_proxy='*' run --separate-stderr "$check" ./bin 1.0.688
  [ "$status" -eq 0 ]
}

@test "a BIN that opens a connection through the proxy is refused" {
  cat >bin <<'EOF'
#!/usr/bin/env bash
exec 3<>"/dev/tcp/127.0.0.1/${HTTPS_PROXY##*:}"
printf 'CONNECT registry.npmjs.org:443 HTTP/1.1\r\n\r\n' >&3
echo 1.0.688
EOF
  chmod +x bin
  run --separate-stderr "$check" ./bin 1.0.688
  [ "$status" -eq 1 ]
  [ "$stderr" = "frozen: the loopback proxy saw 1 connection(s); BIN must make none (nix:V1)" ]
}

@test "a BIN that leaves an executable codebuff under HOME is refused" {
  cat >bin <<'EOF'
#!/usr/bin/env bash
mkdir -p "$HOME/.config/manicode"
printf '#!/bin/sh\n' >"$HOME/.config/manicode/codebuff"
chmod +x "$HOME/.config/manicode/codebuff"
echo 1.0.688
EOF
  chmod +x bin
  run --separate-stderr "$check" ./bin 1.0.688
  [ "$status" -eq 1 ]
  [ "${#stderr_lines[@]}" -eq 2 ]
  [ "${stderr_lines[0]}" = "frozen: HOME holds an executable file: .config/manicode/codebuff (nix:V1)" ]
  [ "${stderr_lines[1]}" = "frozen: HOME holds a file named codebuff: .config/manicode/codebuff (nix:V1)" ]
}

@test "a BIN that leaves a non-executable file named codebuff is refused" {
  cat >bin <<'EOF'
#!/usr/bin/env bash
touch "$HOME/codebuff"
echo 1.0.688
EOF
  chmod +x bin
  run --separate-stderr "$check" ./bin 1.0.688
  [ "$status" -eq 1 ]
  [ "$stderr" = "frozen: HOME holds a file named codebuff: codebuff (nix:V1)" ]
}

@test "a BIN that leaves a tarball or a partial download is refused, each named" {
  cat >bin <<'EOF'
#!/usr/bin/env bash
mkdir -p "$HOME/.config/manicode"
touch "$HOME/.config/manicode/codebuff-darwin-arm64.tar.gz" "$HOME/.config/manicode/dl.part"
echo 1.0.688
EOF
  chmod +x bin
  run --separate-stderr "$check" ./bin 1.0.688
  [ "$status" -eq 1 ]
  [ "${#stderr_lines[@]}" -eq 2 ]
  [ "${stderr_lines[0]}" = "frozen: HOME holds a download: .config/manicode/codebuff-darwin-arm64.tar.gz (nix:V1)" ]
  [ "${stderr_lines[1]}" = "frozen: HOME holds a download: .config/manicode/dl.part (nix:V1)" ]
}

@test "a wrong version is refused" {
  run --separate-stderr "$check" ./clean 1.0.689
  [ "$status" -eq 1 ]
  [ "$stderr" = "frozen: BIN --version stdout does not contain 1.0.689 (root V3)" ]
}

@test "a BIN that exits non-zero is refused with its exit code" {
  printf '#!/usr/bin/env bash\necho 1.0.688\nexit 5\n' >bin
  chmod +x bin
  run --separate-stderr "$check" ./bin 1.0.688
  [ "$status" -eq 1 ]
  [ "$stderr" = "frozen: BIN --version exited 5, not 0 (root V3)" ]
}

@test "a BIN that hangs is refused once TIMEOUT fires" {
  printf '#!/usr/bin/env bash\nexit 124\n' >stubs/timeout
  chmod +x stubs/timeout
  TIMEOUT="$BATS_TEST_TMPDIR/stubs/timeout" run --separate-stderr "$check" ./clean 1.0.688
  [ "$status" -eq 1 ]
  [ "$stderr" = "frozen: BIN --version timed out after 30 s (root V3)" ]
}

@test "stdin is closed, so a BIN waiting for input does not block" {
  printf '#!/usr/bin/env bash\ncat >/dev/null\necho 1.0.688\n' >bin
  chmod +x bin
  run --separate-stderr "$check" ./bin 1.0.688
  [ "$status" -eq 0 ]
}

@test "a listener that cannot start is a finding, not a pass" {
  SOCAT="$BATS_TEST_TMPDIR/stubs/socat-dead" run --separate-stderr "$check" ./clean 1.0.688
  [ "$status" -eq 1 ]
  [ "$stderr" = "frozen: the loopback listener did not start; nothing would count connections (nix:V1)" ]
}

@test "the listener is gone after the check" {
  run --separate-stderr "$check" ./clean 1.0.688
  [ "$status" -eq 0 ]
  run ! pgrep -f "$SOCAT"
}

@test "wrong argument count is usage, exit 2" {
  run --separate-stderr "$check" ./clean
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: frozen.sh BIN VERSION" ]
}
