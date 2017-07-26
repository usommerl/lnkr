#!/usr/bin/env bats

load test_helper
load stub

setup() {
  make_testspace
  export lnkr=$TESTSPACE/lnkr
  cat >$lnkr << EOF
#!/usr/bin/env bash

install() {
  info 'Bootstrap test'
}

source <(curl -Ls https://goo.gl/zo4yfW)
EOF
  chmod 744 $lnkr
  export LNKR_VERSION='master'
  git init
}

teardown() {
  print_output
  rm_cache
  rm_testspace
  rm_stubs
}

@test '__bootstrap should download library if it does not exist' {
  run $lnkr --version
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "lnkr $LNKR_VERSION" ]
  assert_lib_exists "$LNKR_VERSION"
}

@test '__bootstrap should use cache to determine latest release' {
  unset LNKR_VERSION
  run $lnkr --help
  [ "$status" -eq 0 ]
  assert_lib_exists
  stub_curl_and_wget
  run $lnkr --help
  [ "$status" -eq 0 ]
}

@test '__bootstrap should fail silently if it is not able to determine version' {
  mkdir -p $CACHE_DIR
  touch $CACHE_DIR/latest
  unset LNKR_VERSION
  run $lnkr --help
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "Bootstrap failed" ]
}

@test '__bootstrap should not overwrite existing library' {
  mkdir -p $CACHE_DIR
  local ver="$LNKR_VERSION"
  echo 'echo "Fake lnkr library"; exit 254' > "$CACHE_DIR/lnkr_lib_$ver.sh"
  run $lnkr --help
  [ "$output" = "Fake lnkr library" ]
  [ "$status" -eq 254 ]
  assert_lib_exists
}
