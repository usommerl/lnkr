#!/usr/bin/env bats

load test_helper
load stub

setup() {
  make_testspace
  git init
  cp $LNKR_REPO_ROOT/lnkr $TESTSPACE
  export lnkr=$TESTSPACE/lnkr
}

teardown() {
  print_output
  rm_cache
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

@test '__bootstrap should use cache to determine latest release' {
  run $lnkr --help
  [ "$status" -eq 0 ]
  [ "$(ls -l1 $CACHE_DIR/lnkr_lib*.sh | wc -l)" -eq 1 ]
  rm "$TESTSPACE/$LOCKFILE"
  stub_curl_and_wget
  run $lnkr --help
  [ "$status" -eq 0 ]
}

@test '__bootstrap should fail silently if it is not able to determine version' {
  mkdir -p $CACHE_DIR
  touch $CACHE_DIR/latest
  run $lnkr --help
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "Bootstrap failed" ]
}

@test '__bootstrap should not overwrite existing library' {
  mkdir -p $CACHE_DIR
  local ver='v0.1.0'
  echo 'echo "Fake lnkr library"; exit 254' > "$CACHE_DIR/lnkr_lib_$ver.sh"
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
  stub_curl_and_wget
  run $lnkr --help
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "Bootstrap failed" ]
  [ -e "$TESTSPACE/$LOCKFILE" ]
  [ "$(ls -1 $CACHE_DIR/*.sh | wc -l)" -eq 0 ]
}
