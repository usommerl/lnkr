#!/usr/bin/env bats

load test_helper

setup() {
  make_testspace
  readonly LIB_TEST=true
  readonly LIB_NAME=lnkr_lib.sh
  readonly START_DIRECTORY=$TESTSPACE
  source $REPO_ROOT/$LIB_NAME
}

teardown() {
  print_output
  rm_testspace
}

@test '__main should print help if no argument is provided' {
  run __main
  [ "${lines[0]}" = "SYNOPSIS: $(basename $0) [OPTION]" ]
  [ "$status" -eq 1 ]
}

@test '__main should print help if unkown argument is provided' {
  run __main --wrong-argument
  [ "${lines[0]}" = "SYNOPSIS: $(basename $0) [OPTION]" ]
  [ "$status" -eq 1 ]
}

@test '__main should print help when help switch is provided' {
  run __main --help
  [ "${lines[0]}" = "SYNOPSIS: $(basename $0) [OPTION]" ]
  [ "$status" -eq 0 ]
}

@test '__main should add library and log file to gitignore' {
  run __main
  [ -f "$TESTSPACE/.gitignore" ]
  [ "$(cat $TESTSPACE/.gitignore | wc -l)" -eq 2 ]
  [ "$(grep 'lnkr_lib.sh' $TESTSPACE/.gitignore | wc -l)" -eq 1 ]
  [ "$(grep 'lnkr.log' $TESTSPACE/.gitignore | wc -l)" -eq 1 ]
}

@test '__main should not add library multiple times to gitignore' {
  run __main
  run __main
  [ "$(wc -l $TESTSPACE/.gitignore | cut -d ' ' -f 1)" -eq 2 ]
  [ "$(grep 'lnkr_lib.sh' $TESTSPACE/.gitignore | wc -l)" -eq 1 ]
  [ "$(grep 'lnkr.log' $TESTSPACE/.gitignore | wc -l)" -eq 1 ]
}
