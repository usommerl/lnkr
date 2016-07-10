#!/usr/bin/env bats

load test_helper
load stub

setup() {
  export repo_root=$(git rev-parse --show-toplevel)
  export testspace=$repo_root/test/testspace
  mkdir -p $testspace
  cp $repo_root/lnkr $testspace
  export lnkr=$testspace/lnkr
}

teardown() {
  [ -d "$testspace" ] && rm -rf "$testspace"
  print_cmd_output
  rm_stubs
}

@test "bootstrap should dowload library if it does not exist" {
  run $lnkr
  [ "$status" -eq 0 ]
  [ -e "$testspace/lnkr_lib.sh" ]
}

@test "bootstrap should not overwrite existing library" {
  echo 'echo "Fake lnkr library"; exit 254' > $testspace/lnkr_lib.sh
  run $lnkr
  [ "$output" = "Fake lnkr library" ]
  [ "$status" -eq 254 ]
}

@test "bootstrap should use curl or wget to download library" {
  stub curl "bash: curl: command not found" 1
  run $lnkr
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "bash: curl: command not found" ]
  [ -e "$testspace/lnkr_lib.sh" ]
}

@test "bootstrap should abort if it is not able to download library" {
  stub curl "bash: curl: command not found" 1
  stub wget "bash: wget: command not found" 1
  run $lnkr
  [ "$status" -eq 1 ]
  [ "${lines[2]}" = "Bootstrap failed. Aborting." ]
  [ ! -e "$testspace/lnkr_lib.sh" ]
}
