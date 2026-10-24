#!/usr/bin/env bats
# gate/name-guard.sh (gate:V2, root V6, paradigm/V37): the denylist half
# of the name guard. The planted names here are made up.

setup() {
  guard="$BATS_TEST_DIRNAME/../../../gate/name-guard.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  printf '# a comment, not an entry\n\nzorblax\n  Quuxcorp  \n' >denylist
  export NAME_GUARD_DENYLIST="$BATS_TEST_TMPDIR/denylist"
}

@test "clean files pass" {
  printf 'nothing to see\n' >clean.txt
  run "$guard" clean.txt
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a listed name is refused by entry number, never by name" {
  printf 'line one\nwe ship to quuxcorp now\n' >leak.txt
  run "$guard" leak.txt
  [ "$status" -eq 1 ]
  [ "$output" = "name-guard: leak.txt:2: private name (denylist entry 2)" ]
  [[ "$output" != *[Qq]uuxcorp* ]]
}

@test "names match case-insensitively and every hit is listed" {
  printf 'ZORBLAX\nzorBlax again\n' >a.txt
  printf 'Quuxcorp\n' >b.txt
  run "$guard" a.txt b.txt
  [ "$status" -eq 1 ]
  [ "${#lines[@]}" -eq 3 ]
  [ "${lines[0]}" = "name-guard: a.txt:1: private name (denylist entry 1)" ]
  [ "${lines[1]}" = "name-guard: a.txt:2: private name (denylist entry 1)" ]
  [ "${lines[2]}" = "name-guard: b.txt:1: private name (denylist entry 2)" ]
}

@test "a file that is gone or binary is skipped" {
  printf 'zorblax\0binary\n' >blob.bin
  run "$guard" gone.txt blob.bin
  [ "$status" -eq 0 ]
}

@test "without a denylist it says so and passes" {
  export NAME_GUARD_DENYLIST="$BATS_TEST_TMPDIR/absent"
  printf 'zorblax\n' >leak.txt
  run "$guard" leak.txt
  [ "$status" -eq 0 ]
  [[ "$output" == *"no private name was checked"* ]]
}
