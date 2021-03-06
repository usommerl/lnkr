#!/usr/bin/env bats

load test_helper
load stub

setup() {
  BATS_TEST_SKIPPED=''
  readonly LNKR_LIB_TEST=true
  make_testspace && cd $TESTSPACE && git init
  cp $LNKR_REPO_ROOT/$LIB_FILENAME .
  source "$LIB_FILENAME"
}

teardown() {
  print_output
  rm_stubs
  rm_testspace
  rm_journal
}

@test '__main should print help if no argument is provided' {
  run __main
  [ "${lines[0]}" = "SYNOPSIS: $(basename $0) [OPTIONS] <install|remove>" ]
  [ "$status" -eq 1 ]
}

@test '__main should print help if unknown argument is provided' {
  run __main --wrong-argument
  [ "${lines[0]}" = "SYNOPSIS: $(basename $0) [OPTIONS] <install|remove>" ]
  [ "$status" -eq 1 ]
}

@test '__main should print help if help switch is provided' {
  run __main --help
  [ "${lines[0]}" = "SYNOPSIS: $(basename $0) [OPTIONS] <install|remove>" ]
  [ "$status" -eq 0 ]
}

@test '__main should print version if version switch is provided' {
  run __main --version
  [ $(echo "${lines[0]}" | grep 'lnkr.*' | wc -l) -eq 1 ]
  [ "$status" -eq 0 ]
}

@test '__logger_base should print to STDOUT' {
  run info 'line1'
  [ $(echo "${lines[0]}" | grep 'info.*line1' | wc -l) -eq 1 ]
  run warn 'line2'
  [ $(echo "${lines[0]}" | grep 'warn.*line2' | wc -l) -eq 1 ]
  run fail 'line3'
  [ $(echo "${lines[0]}" | grep 'fail.*line3' | wc -l) -eq 1 ]
}

@test '__logger_base should allow empty log message' {
  run info
  [ $(echo "${lines[0]}" | grep 'info.*' | wc -l) -eq 1 ]
}

@test '__logger_base should not fail if message begins with hyphen' {
  run info '----'
  [ $(echo "${lines[0]}" | grep 'info.*----' | wc -l) -eq 1 ]
  [ "$(echo "${#lines[@]}")" -eq 1 ]
}

@test '__operation should fail if callback is not defined' {
  run __operation "test"
  [ "$status" -eq 1 ]
  [ $(echo "${lines[@]}" | grep 'fail.*__test.*not defined' | wc -l) -eq 1 ]
}

@test 'link should create backup if file exists in target location' {
  local timestamp='2016-08-09T2120:36+02:00'
  local linkname='link'
  local linkpath="$TESTSPACE/$linkname"
  touch "$linkpath"
  stub date $timestamp
  run link "$TESTSPACE/file" "$linkname"
  [ "$status" -eq 0 ]
  [ "$(ls -l1 "${linkpath}.backup-$timestamp")" ]
  [ -L "$linkpath" ]
}

@test 'link should not fail if target name contains spaces' {
  local timestamp='2020-03-27T21:53:00+01:00'
  local linkname='link - with - spaces'
  local linkpath="$TESTSPACE/$linkname"
  touch "$linkpath"
  stub date $timestamp
  run link "$TESTSPACE/file" "$linkname"
  [ "$status" -eq 0 ]
  [ "$(ls -l1 "${linkpath}.backup-$timestamp")" ]
  [ -L "$linkpath" ]
}

@test 'link should fail if file with same name as backup file exists' {
  local timestamp='2016-08-09T2120:36+02:00'
  local linkname='link'
  local linkpath="$TESTSPACE/$linkname"
  local linktarget="$TESTSPACE/file"
  touch "$linkpath" "$linktarget" "$linkpath.backup-$timestamp"
  stub date $timestamp
  run link $linktarget $linkname
  [ "$status" -eq 1 ]
  [ $(echo "${lines[@]}" | grep "Could not create backup" | wc -l) -eq 1 ]
  [ ! -L "$linkpath" ]
}

@test 'link should create parent directories if they do not exist' {
  local linkname='link'
  local parent_dir="$TESTSPACE/does_not_exist"
  local linkpath="$parent_dir/$linkname"
  [ ! -e "$parent_dir" ]
  run link "$TESTSPACE/file" $linkpath
  [ -e "$parent_dir" ]
  [ -L "$linkpath" ]
}

@test 'link should warn about dead links' {
  local linkname='link'
  local linkpath="$TESTSPACE/$linkname"
  local linktarget="$TESTSPACE/file"
  run link $linktarget $linkname
  [ "$status" -eq 0 ]
  [ $(echo "${lines[0]}" | grep "dead link" | wc -l) -eq 1 ]
}

@test 'link should record link and backup in journal' {
  local ts='2016-08-09T21:20:36+02:00'
  local linkname='link'
  local id=$(id -un)
  touch "$TESTSPACE/$linkname"
  stub date $ts
  run link "$TESTSPACE/file" $linkname
  run cat $TEST_JOURNAL
  [ "${#lines[@]}" -eq 2 ]
  [ $(echo "${lines[0]}" | grep "$id.*BAK.*link.backup-$ts" | wc -l) -eq 1 ]
  [ $(echo "${lines[1]}" | grep "$id.*LNK.*file.*link" | wc -l) -eq 1 ]
}

@test 'sudo function should enable sudo mode for link function' {
  stub_sudo
  local linkname='link'
  touch "$TESTSPACE/$linkname"
  run sudo link "$TESTSPACE/file" "$TESTSPACE/$linkname"
  [ "$status" -eq 0 ]
  [ $(echo "${lines[1]}" | grep "sudo mv .*link .*link.backup-.*" | wc -l) -eq 1 ]
  [ $(echo "${lines[2]}" | grep "Create backup" | wc -l) -eq 1 ]
  [ $(echo "${lines[3]}" | grep "sudo mkdir.*" | wc -l) -eq 1 ]
  [ $(echo "${lines[4]}" | grep "sudo ln .*file .*link" | wc -l) -eq 1 ]
  [ $(echo "${lines[5]}" | grep "Create link" | wc -l) -eq 1 ]
}

@test 'sudo function should use sudo command for every argument other than link' {
  stub_sudo
  run sudo date
  [ $(echo "${lines[@]}" | grep "sudo date" | wc -l) -eq 1 ]
  [ "$status" -eq 0 ]
}

@test 'sudo function should fail if sudo command is not available' {
  run sudo link target_location link_location
  [ "$status" -eq 1 ]
  [ $(echo "${lines[@]}" | grep 'sudo.*not available' | wc -l) -eq 1 ]
}

@test 'fail should abort script with exit code 1' {
  run fail 'ERROR'
  [ "$status" -eq 1 ]
}

@test 'setup_submodules should initialize submodules' {
  make_repo_with_submodule
  run setup_submodules
  local submodule=$(git submodule status | head -n 1 | cut -d ' ' -f 3)
  [ "$(ls -1 "$submodule" | wc -l)" -gt 0 ]
}

@test 'setup_submodules should modify push url' {
  make_repo_with_submodule
  git submodule update --init
  local submodule="$(git submodule status | head -n 1 | cut -d ' ' -f 3)"
  git -C "$submodule" remote set-url --push origin https://github.com/user/repo.git
  run setup_submodules
  cd "$submodule"
  [ "$(git remote -vv show | grep -e 'git@github.com.*(push)' | wc -l)" -eq 1 ]
}

@test 'setup_submodules should not modify push url if it is explicitly requested' {
  make_repo_with_submodule
  local submodule="$(git submodule status | head -n 1 | cut -d ' ' -f 3)"
  run setup_submodules --keep-push-url
  cd "$submodule"
  [ "$(git remote -vv show | grep -e 'https://github.com.*(push)' | wc -l)" -eq 1 ]
}

@test 'recurse option should call script in submodule' {
  make_repo_with_submodule
  git submodule update --init
  local submodule="$(git submodule status | head -n 1 | cut -d ' ' -f 3)"
  local script_name="$(basename "$0")"
  printf 'echo "MYARGS: $@"; exit 1' > "$submodule/$script_name"
  install() {
    printf 'fake install function\n'
  }
  run __main -r install
  [ "$status" -eq 0 ]
  [ $(echo "${lines[@]}" | grep 'MYARGS: -r install' | wc -l) -eq 1 ]
}

@test 'install operation should fail if function install() is not defined' {
  run __main install
  [ "$status" -eq 1 ]
  [ $(echo "${lines[@]}" | grep 'install.*not defined' | wc -l) -eq 1 ]
}

@test 'install operation should succeed if function install() is defined' {
  install() {
    printf 'fake install function\n'
  }
  run __main install
  [ "$status" -eq 0 ]
  [ $(echo "${lines[@]}" | grep 'fake install' | wc -l) -eq 1 ]
}

@test 'install operation should fail if journal is not empty' {
  install() {
    link "$TESTSPACE/file" 'link'
  }
  touch "$TESTSPACE/file"
  run __main install
  [ $(cat "$TEST_JOURNAL" | wc -l) -gt 0 ]
  run __main install
  [ "$status" -eq 1 ]
  [ $(echo "${lines[@]}" | grep -i 'journal.*not empty' | wc -l) -eq 1 ]
}

@test 'remove operation should call pre and post hooks' {
  pre_remove_hook() {
    printf 'pre_remove\n'
  }
  post_remove_hook() {
    printf 'post_remove\n'
  }
  run __main remove
  [ "$status" -eq 0 ]
  [ $(echo "${lines[@]}" | grep 'pre_remove.*post_remove' | wc -l) -eq 1 ]
}

@test 'remove operation should warn if journal is empty' {
  run __main remove
  [ "$status" -eq 0 ]
  [ $(echo "${lines[@]}" | grep -i 'journal.*no entries' | wc -l) -eq 1 ]
}

@test 'remove operation should revert journal entries' {
  local linkname='link'
  printf 'file.orig\n' > "$TESTSPACE/$linkname"
  printf 'file.linked\n' > "$TESTSPACE/file"
  run link "$TESTSPACE/file" "$linkname"
  [ $(cat "$TEST_JOURNAL" | wc -l) -eq 2 ]
  run __main remove
  [ "$status" -eq 0 ]
  [ $(grep 'file.orig' "$TESTSPACE/$linkname" | wc -l) -eq 1 ]
  [ ! -e "$TEST_JOURNAL" ]
}

@test 'remove operation should revert journal entries that where created with sudo' {
  stub_sudo
  local linkname='link'
  printf 'file.orig\n' > "$TESTSPACE/$linkname"
  printf 'file.linked\n' > "$TESTSPACE/file"
  run sudo link "$TESTSPACE/file" "$linkname"
  [ $(cat "$TEST_JOURNAL" | wc -l) -eq 2 ]
  [ $(echo "${lines[3]}" | grep "sudo ln.*file link" | wc -l) -eq 1 ]
  run __main remove
  [ "$status" -eq 0 ]
  [ $(grep 'file.orig' "$TESTSPACE/$linkname" | wc -l) -eq 1 ]
  [ $(echo "${lines[1]}" | grep "sudo rm link" | wc -l) -eq 1 ]
  [ $(echo "${lines[3]}" | grep "sudo mv -n link.backup-.* link" | wc -l) -eq 1 ]
  [ ! -e "$TEST_JOURNAL" ]
}

@test 'remove operation should revert journal entries with names that contain spaces' {
  local linkname='link - with - spaces'
  printf 'file.orig\n' > "$TESTSPACE/$linkname"
  printf 'file.linked\n' > "$TESTSPACE/file"
  run link "$TESTSPACE/file" "$linkname"
  [ $(cat "$TEST_JOURNAL" | wc -l) -eq 2 ]
  run __main remove
  [ "$status" -eq 0 ]
  [ $(grep 'file.orig' "$TESTSPACE/$linkname" | wc -l) -eq 1 ]
  [ ! -e "$TEST_JOURNAL" ]
}

@test 'remove operation should not remove new file at recorded link location' {
  local linkname='link'
  printf 'file.orig\n' > "$TESTSPACE/$linkname"
  printf 'file.linked\n' > "$TESTSPACE/file"
  run link "$TESTSPACE/file" "$linkname"
  rm "$TESTSPACE/$linkname" && printf 'file.new\n' > "$TESTSPACE/$linkname"
  run __main remove
  [ "$status" -eq 0 ]
  [ $(grep 'file.new' "$TESTSPACE/$linkname" | wc -l) -eq 1 ]
  [ $(grep 'BAK' "$TEST_JOURNAL" | wc -l) -eq 1 ]
}

@test 'remove operation should not fail if backup was removed' {
  local linkname='link'
  printf 'file.orig\n' > "$TESTSPACE/$linkname"
  printf 'file.linked\n' > "$TESTSPACE/file"
  run link "$TESTSPACE/file" "$linkname"
  rm -v $TESTSPACE/$linkname.backup-*
  run __main remove
  [ "$status" -eq 0 ]
  [ ! -f "$TESTSPACE/$linkname" ]
  [ $(echo "${lines[@]}" | grep -i 'backup.*does not exist' | wc -l) -eq 1 ]
  [ ! -e "$TEST_JOURNAL" ]
}

@test 'remove operation should not delete journal entry if link removal fails' {
  local linkname='link'
  printf 'file.linked\n' > "$TESTSPACE/file"
  run link "$TESTSPACE/file" "$linkname"
  stub rm "Unkown rm error" "1"
  run __main remove
  [ "$status" -eq 0 ]
  [ -f "$TESTSPACE/$linkname" ]
  [ $(echo "${lines[@]}" | grep -i 'Unkown rm error' | wc -l) -eq 1 ]
  [ $(cat "$TEST_JOURNAL" | wc -l) -eq 1 ]
  [ $(grep 'LNK' "$TEST_JOURNAL" | wc -l) -eq 1 ]
}

@test 'remove operation should not delete journal entry if backup recreation fails' {
  local linkname='link'
  printf 'file.orig\n' > "$TESTSPACE/$linkname"
  printf 'file.linked\n' > "$TESTSPACE/file"
  run link "$TESTSPACE/file" "$linkname"
  stub mv "Unkown mv error" "1"
  run __main remove
  [ "$status" -eq 0 ]
  [ ! -f "$TESTSPACE/$linkname" ]
  [ $(echo "${lines[@]}" | grep -i 'Unkown mv error' | wc -l) -eq 1 ]
  [ $(cat "$TEST_JOURNAL" | wc -l) -eq 1 ]
  [ $(grep 'BAK' "$TEST_JOURNAL" | wc -l) -eq 1 ]
}

