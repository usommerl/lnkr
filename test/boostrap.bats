#!/usr/bin/env bats

load test_helper
load stub

setup() {
  make_testspace
  cp $LNKR_REPO_ROOT/lnkr $TESTSPACE
  export lnkr=$TESTSPACE/lnkr
}

teardown() {
  print_output
  rm_lib
  rm_testspace
  rm_stubs
}

@test '__bootstrap should download library if it does not exist' {
  run $lnkr --help
  [ "$status" -eq 0 ]
  [ -e "$TESTSPACE/$LOCKFILE" ]
  assert_lib_exists
}

@test '__bootstrap should not ignore lockfile' {
  local ver='v0.1.0'
  echo $ver > $TESTSPACE/$LOCKFILE
  run $lnkr --help
  [ "$status" -eq 0 ]
  assert_lib_exists
}

@test '__bootstrap should not overwrite existing library' {
  mkdir -p $LIB_DIRECTORY
  local ver='v0.1.0'
  echo 'echo "Fake lnkr library"; exit 254' > "$LIB_DIRECTORY/lnkr_lib_$ver.sh"
  echo $ver > $TESTSPACE/$LOCKFILE
  run $lnkr --help
  [ "$output" = "Fake lnkr library" ]
  [ "$status" -eq 254 ]
  assert_lib_exists
}

@test '__bootstrap should use curl or wget to download library' {
  stub curl "bash: curl: command not found" 127
  run $lnkr --help
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "bash: curl: command not found" ]
  [ -e "$TESTSPACE/$LOCKFILE" ]
  assert_lib_exists
}

@test '__bootstrap should abort if it is not able to download library' {
  stub curl "bash: curl: command not found" 127
  stub wget "bash: wget: command not found" 127
  run $lnkr --help
  [ "$status" -eq 1 ]
  [ "${lines[2]}" = "Bootstrap failed. Aborting." ]
  [ -e "$TESTSPACE/$LOCKFILE" ]
  [ "$(ls -1 $LIB_DIRECTORY/*.sh | wc -l)" -eq 0 ]
}
