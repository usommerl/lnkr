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

@test '__main should add library, log and journal to gitignore' {
  run __main
  [ -f "$TESTSPACE/.gitignore" ]
  [ "$(cat $TESTSPACE/.gitignore | wc -l)" -eq 3 ]
  [ "$(grep 'lnkr_lib.sh' $TESTSPACE/.gitignore | wc -l)" -eq 1 ]
  [ "$(grep 'lnkr.log' $TESTSPACE/.gitignore | wc -l)" -eq 1 ]
  [ "$(grep '.lnkr.journal' $TESTSPACE/.gitignore | wc -l)" -eq 1 ]
}

@test '__main should not add library multiple times to gitignore' {
  run __main
  run __main
  [ "$(wc -l $TESTSPACE/.gitignore | cut -d ' ' -f 1)" -eq 3 ]
  [ "$(grep 'lnkr_lib.sh' $TESTSPACE/.gitignore | wc -l)" -eq 1 ]
  [ "$(grep 'lnkr.log' $TESTSPACE/.gitignore | wc -l)" -eq 1 ]
  [ "$(grep '.lnkr.journal' $TESTSPACE/.gitignore | wc -l)" -eq 1 ]
}

@test '__logger_base should print to file and STDOUT' {
  run info 'line1'
  [ $(echo "${lines[0]}" | grep 'info.*line1' | wc -l) -eq 1 ]
  run warn 'line2'
  [ $(echo "${lines[0]}" | grep 'warn.*line2' | wc -l) -eq 1 ]
  run fail 'line3'
  [ $(echo "${lines[0]}" | grep 'fail.*line3' | wc -l) -eq 1 ]
  run cat $TESTSPACE/lnkr.log
  [ $(echo "${lines[0]}" | grep 'info.*line1' | wc -l) -eq 1 ]
  [ $(echo "${lines[1]}" | grep 'warn.*line2' | wc -l) -eq 1 ]
  [ $(echo "${lines[2]}" | grep 'fail.*line3' | wc -l) -eq 1 ]
}

@test 'install should fail if function install() is not defined' {
  run __main --install
  [ "$status" -eq 1 ]
  [ $(echo "${lines[@]}" | grep 'install.*not defined' | wc -l) -eq 1 ]
}

@test 'install should succeed if function install() is defined' {
  install() {
    printf 'fake install function\n'
  }
  run __main --install
  [ "$status" -eq 0 ]
  [ $(echo "${lines[@]}" | grep 'fake install' | wc -l) -eq 1 ]
}

@test 'remove should call pre and post hooks' {
  pre_remove_hook() {
    printf 'pre_remove\n'
  }
  post_remove_hook() {
    printf 'post_remove\n'
  }
  run __main --remove
  [ "$status" -eq 0 ]
  [ $(echo "${lines[@]}" | grep 'pre_remove.*post_remove' | wc -l) -eq 1 ]
}

@test 'remove should warn if journal is empty' {
  run __main --remove
  [ "$status" -eq 0 ]
  [ $(echo "${lines[@]}" | grep -i 'journal.*empty' | wc -l) -eq 1 ]
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
  local linktarget="$TESTSPACE/file"
  touch "$linkpath" "$linktarget" "$linkpath.backup-$timestamp"
  stub date $timestamp
  run lnk $linktarget $linkname
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

@test 'lnk should warn about dead links' {
  local linkname='link'
  local linkpath="$TESTSPACE/$linkname"
  local linktarget="$TESTSPACE/file"
  run lnk $linktarget $linkname
  [ "$status" -eq 0 ]
  [ $(echo "${lines[0]}" | grep "dead link" | wc -l) -eq 1 ]
}

@test 'lnk should record link and backup in journal' {
  local ts='2016-08-09T21:20:36+02:00'
  local linkname='link'
  local id=$(id -u)
  touch "$TESTSPACE/$linkname"
  stub date $ts
  run lnk "$TESTSPACE/file" $linkname
  run cat $TESTSPACE/.lnkr.journal; 
  [ "${#lines[@]}" -eq 2 ]
  [ $(echo "${lines[0]}" | grep "$ts.*$id.*BAK.*link.backup-$ts" | wc -l) -eq 1 ]
  [ $(echo "${lines[1]}" | grep "$ts.*$id.*LNK.*file.*link" | wc -l) -eq 1 ]
}

@test 'fail should abort script with exit code 1' {
  run fail 'ERROR'
  [ "$status" -eq 1 ]
}
