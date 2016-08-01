#!/usr/bin/env bats

load test_helper

setup() {
  make_testspace
  export LNKR_LIB_TEST=true
  source $REPO_ROOT/lnkr_lib.sh
}

teardown() {
  rm_testspace
  print_cmd_output
}

@test 'main should print help if no argument is provided' {
  run __main
  [ "${lines[0]}" = "SYNOPSIS: $(basename $0) [OPTION]" ]
  [ "$status" -eq 1 ]
}

@test 'main should print help if unkown argument is provided' {
  run __main --wrong-argument
  [ "${lines[0]}" = "SYNOPSIS: $(basename $0) [OPTION]" ]
  [ "$status" -eq 1 ]
}

@test 'main should print help when help switch is provided' {
  run __main --help
  [ "${lines[0]}" = "SYNOPSIS: $(basename $0) [OPTION]" ]
  [ "$status" -eq 0 ]
}

@test 'main should add library to gitignore' {
  run __main
  result=$(wc -l $TESTSPACE/.gitignore | cut -d ' ' -f 1)
  echo $result >&2
  [ "$result" -eq 1 ]
}

@test 'main should not add library multiple times to gitignore' {
  run __main
  run __main
  run __main
  result=$(wc -l $TESTSPACE/.gitignore | cut -d ' ' -f 1)
  echo $result >&2
  [ "$result" -eq 1 ]
}
