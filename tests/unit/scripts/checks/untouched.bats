#!/usr/bin/env bats
# scripts/checks/untouched.sh (pkgs:V1, pkgs:V2, D3): the installed
# binary and tree-sitter.wasm against the tarball members. The binaries
# are fakes with a Mach-O or ELF magic; readelf and objcopy are stubs
# through the READELF and OBJCOPY seams that read `NEEDED <lib>` and
# `BUN <bytes>` lines out of the fake ELF.

bats_require_minimum_version 1.5.0

setup() {
  check="$BATS_TEST_DIRNAME/../../../../scripts/checks/untouched.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir -p stubs member darwin/libexec/codebuff linux/libexec/codebuff
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  cat >stubs/readelf <<'EOF'
#!/usr/bin/env bash
echo "readelf $*" >>"$STUB_LOG"
[ "$1" = -d ] || exit 9
sed -n 's/^NEEDED \(.*\)$/ 0x0000000000000001 (NEEDED)             Shared library: [\1]/p' "$2"
EOF
  cat >stubs/objcopy <<'EOF'
#!/usr/bin/env bash
echo "objcopy $*" >>"$STUB_LOG"
[ "$1" = --dump-section ] || exit 9
dump=${2#.bun=}
grep -q '^BUN ' "$3" || { echo "objcopy: $3: can't dump section '.bun' - it does not exist" >&2; exit 1; }
grep '^BUN ' "$3" >"$dump"
cp "$3" "$4"
EOF
  chmod +x stubs/readelf stubs/objcopy
  export READELF="$BATS_TEST_TMPDIR/stubs/readelf"
  export OBJCOPY="$BATS_TEST_TMPDIR/stubs/objcopy"
  printf '\0asm\1\0\0\0' >member/tree-sitter.wasm
  # darwin: the members, installed untouched.
  printf '\xcf\xfa\xed\xfe bun runtime\n__BUN payload\n' >member/codebuff
  tar -czf darwin.tar.gz -C member codebuff tree-sitter.wasm
  cp member/codebuff member/tree-sitter.wasm darwin/libexec/codebuff/
  # linux: what autoPatchelfHook does, a new interpreter and an rpath.
  printf '\x7fELF\nINTERP /lib64/ld-linux-x86-64.so.2\nNEEDED libc.so.6\nNEEDED libm.so.6\nBUN payload-1\nBUN payload-2\n' >member/codebuff
  tar -czf linux.tar.gz -C member codebuff tree-sitter.wasm
  cp member/tree-sitter.wasm linux/libexec/codebuff/
  sed -e 's|^INTERP .*|INTERP /nix/store/glibc/lib/ld-linux-x86-64.so.2|' -e '$a RPATH /nix/store/glibc/lib' \
    member/codebuff >linux/libexec/codebuff/codebuff
}

@test "darwin: a byte-identical binary and wasm pass, quietly, without readelf" {
  run --separate-stderr "$check" darwin darwin.tar.gz
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ ! -e "$STUB_LOG" ]
}

@test "darwin: a modified binary is refused (pkgs:V1)" {
  printf 'resigned\n' >>darwin/libexec/codebuff/codebuff
  run --separate-stderr "$check" darwin darwin.tar.gz
  [ "$status" -eq 1 ]
  [ "$stderr" = "untouched: darwin/libexec/codebuff/codebuff is not byte-identical to the tarball member (pkgs:V1, D3)" ]
}

@test "a modified tree-sitter.wasm is refused" {
  printf 'x' >>darwin/libexec/codebuff/tree-sitter.wasm
  run --separate-stderr "$check" darwin darwin.tar.gz
  [ "$status" -eq 1 ]
  [ "$stderr" = "untouched: darwin/libexec/codebuff/tree-sitter.wasm is not byte-identical to the tarball member (pkgs:V1, pkgs:V2)" ]
}

@test "linux: only the interpreter and rpath changed, so it passes, quietly" {
  run --separate-stderr "$check" linux linux.tar.gz
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  grep -Fx "readelf -d linux/libexec/codebuff/codebuff" "$STUB_LOG"
  [ "$(grep -c '^objcopy --dump-section \.bun=' "$STUB_LOG")" -eq 2 ]
}

@test "linux: objcopy works on copies; the installed binary is left alone" {
  cp linux/libexec/codebuff/codebuff before
  run --separate-stderr "$check" linux linux.tar.gz
  [ "$status" -eq 0 ]
  cmp before linux/libexec/codebuff/codebuff
  run ! grep -E '^objcopy .* linux/libexec/codebuff/codebuff( |$)' "$STUB_LOG"
}

@test "linux: a NEEDED set that grew is refused (pkgs:V2)" {
  printf 'NEEDED libstdc++.so.6\n' >>linux/libexec/codebuff/codebuff
  run --separate-stderr "$check" linux linux.tar.gz
  [ "$status" -eq 1 ]
  [ "$stderr" = "untouched: NEEDED differs: installed libc.so.6 libm.so.6 libstdc++.so.6, tarball libc.so.6 libm.so.6 (pkgs:V2)" ]
}

@test "linux: a changed .bun section is refused (pkgs:V2)" {
  sed -i.bak 's/^BUN payload-2$/BUN stripped/' linux/libexec/codebuff/codebuff
  run --separate-stderr "$check" linux linux.tar.gz
  [ "$status" -eq 1 ]
  [ "$stderr" = "untouched: the .bun section differs from the tarball member's (pkgs:V2, R5)" ]
}

@test "linux: a .bun section that is gone is refused (pkgs:V2)" {
  sed -i.bak '/^BUN /d' linux/libexec/codebuff/codebuff
  run --separate-stderr "$check" linux linux.tar.gz
  [ "$status" -eq 1 ]
  [ "$stderr" = "untouched: linux/libexec/codebuff/codebuff has no .bun section to dump (pkgs:V2, R5)" ]
}

@test "a binary that is neither Mach-O nor ELF is refused" {
  printf '#!/bin/sh\n' >darwin/libexec/codebuff/codebuff
  run --separate-stderr "$check" darwin darwin.tar.gz
  [ "$status" -eq 1 ]
  [ "$stderr" = "untouched: darwin/libexec/codebuff/codebuff is neither Mach-O nor ELF" ]
}

@test "a tarball without the members is refused, each named" {
  tar -czf empty.tar.gz -C stubs readelf
  run --separate-stderr "$check" darwin empty.tar.gz
  [ "$status" -eq 1 ]
  [ "${#stderr_lines[@]}" -eq 2 ]
  [ "${stderr_lines[0]}" = "untouched: empty.tar.gz has no member codebuff" ]
  [ "${stderr_lines[1]}" = "untouched: empty.tar.gz has no member tree-sitter.wasm" ]
}

@test "an installed file that is missing is refused" {
  rm darwin/libexec/codebuff/tree-sitter.wasm
  run --separate-stderr "$check" darwin darwin.tar.gz
  [ "$status" -eq 1 ]
  [ "$stderr" = "untouched: darwin/libexec/codebuff/tree-sitter.wasm does not exist" ]
}

@test "a tarball that does not unpack is a finding" {
  printf 'not gzip\n' >bad.tar.gz
  run --separate-stderr "$check" darwin bad.tar.gz
  [ "$status" -eq 1 ]
  [ "${stderr_lines[-1]}" = "untouched: bad.tar.gz does not unpack" ]
}

@test "wrong argument count is usage, exit 2" {
  run --separate-stderr "$check" darwin
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: untouched.sh OUT TARBALL" ]
}
