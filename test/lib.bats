#!/usr/bin/env bats

load test_helper

setup() {
  make_testspace
  export LNKR_LIB_TEST=true
  source $repo_root/lnkr_lib.sh
}

teardown() {
  print_cmd_output
  rm_testspace
}


@test 'main should print help if no argument is provided' {
  run main
  [ "${lines[0]}" = "SYNOPSIS: $(basename $0) [OPTION]" ]
  [ "$status" -eq 1 ]
}

@test 'main should print help if unkown argument is provided' {
  run main --wrong-argument
  [ "${lines[0]}" = "SYNOPSIS: $(basename $0) [OPTION]" ]
  [ "$status" -eq 1 ]
}

@test 'main should print help when help switch is provided' {
  run main --help
  [ "${lines[0]}" = "SYNOPSIS: $(basename $0) [OPTION]" ]
  [ "$status" -eq 0 ]
}

