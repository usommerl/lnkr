#!/usr/bin/env bats

load test_helper
load stub

setup() {
  make_testspace
  readonly LIB_TEST=true
  readonly LIB_NAME=lnkr_lib.sh
  readonly START_DIRECTORY=$TESTSPACE
  source $REPO_ROOT/$LIB_NAME
}

teardown() {
  print_output
  rm_stubs
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

@test 'lnk should create backup if file exists in target location' {
  local timestamp='2016-08-09T2120:36+02:00'
  local linkname='link'
  local linkpath="$TESTSPACE/$linkname"
  touch $linkpath
  stub date $timestamp
  run lnk "$TESTSPACE/file" $linkname
  [ "$status" -eq 0 ]
  [ "$(ls -l1 ${linkpath}.backup-$timestamp)" ]
  [ -L $linkpath ]
}
@test 'lnk should fail if file with same name as backup file exists' {
  local timestamp='2016-08-09T2120:36+02:00'
  local linkname='link'
  local linkpath="$TESTSPACE/$linkname"
  touch $linkpath
  touch $linkpath.backup-$timestamp
  stub date $timestamp
  run lnk "$TESTSPACE/file" $linkname
  [ "$status" -eq 1 ]
  [ $(echo "${lines[1]}" | grep "Could not create backup" | wc -l) -eq 1 ]
  [ ! -L $linkpath ]
}

@test 'lnk should create parent directories if they do not exist' {
  local linkname='link'
  local parent_dir="$TESTSPACE/does_not_exist"
  local linkpath="$parent_dir/$linkname"
  [ ! -e "$parent_dir" ]
  run lnk "$TESTSPACE/file" $linkpath
  [ -e "$parent_dir" ]
  [ -L $linkpath ]
}
