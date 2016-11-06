readonly TESTSPACE=$BATS_TEST_DIRNAME/testspace
readonly LNKR_REPO_ROOT=$(git rev-parse --show-toplevel)
readonly LIB_FILENAME=lnkr_lib.sh
readonly LOCKFILE=.lnkr.lock
readonly LIB_DIRECTORY="${XDG_CACHE_HOME:-$HOME/.cache}/lnkr"

print_output() {
  echo >&2
  for line in ${lines[@]}; do
    echo $line >&2
  done
}

make_testspace() {
  mkdir -p "$TESTSPACE"
  cd "$TESTSPACE"
}

rm_testspace() {
  [ -d "$TESTSPACE" ] && cd "$LNKR_REPO_ROOT" && rm -rf "$TESTSPACE"
}

rm_lib() {
  rm -rf "$LIB_DIRECTORY"
}

make_repo_with_submodule() {
  rm_testspace
  git clone https://github.com/usommerl/configuration-bash.git $TESTSPACE
  cp "$LNKR_REPO_ROOT/$LIB_FILENAME" "$TESTSPACE/"
  cd "$TESTSPACE"
}

assert_lib_exists() {
  local version=$(head -n 1 "$TESTSPACE/$LOCKFILE") 2>&-
  [ -e "$LIB_DIRECTORY/${LIB_FILENAME/%.sh/_$version.sh}" ]
}
