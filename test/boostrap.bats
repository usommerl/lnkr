#!/usr/bin/env bats

load test_helper
load stub

setup() {
  make_testspace
  cp $REPO_ROOT/lnkr $TESTSPACE
  export lnkr=$TESTSPACE/lnkr
}

teardown() {
  print_cmd_output
  rm_testspace
  rm_stubs
}

@test 'bootstrap should dowload library if it does not exist' {
  run $lnkr --help
  [ "$status" -eq 0 ]
  [ -e "$TESTSPACE/lnkr_lib.sh" ]
}

@test 'bootstrap should not overwrite existing library' {
  echo 'echo "Fake lnkr library"; exit 254' > $TESTSPACE/lnkr_lib.sh
  run $lnkr --help
  [ "$output" = "Fake lnkr library" ]
  [ "$status" -eq 254 ]
}

@test 'bootstrap should use curl or wget to download library' {
  stub curl "bash: curl: command not found" 127
  run $lnkr --help
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "bash: curl: command not found" ]
  [ -e "$TESTSPACE/lnkr_lib.sh" ]
}

@test 'bootstrap should abort if it is not able to download library' {
  stub curl "bash: curl: command not found" 127
  stub wget "bash: wget: command not found" 127
  run $lnkr --help
  [ "$status" -eq 1 ]
  [ "${lines[2]}" = "Bootstrap failed. Aborting." ]
  [ ! -e "$TESTSPACE/lnkr_lib.sh" ]
}
