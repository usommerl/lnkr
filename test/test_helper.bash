readonly TESTSPACE=$BATS_TEST_DIRNAME/testspace
readonly LNKR_REPO_ROOT=$(git rev-parse --show-toplevel)
readonly LIB_FILENAME=lnkr_lib.sh
readonly LOCKFILE=lnkr.lock
readonly CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/lnkr"
readonly TEST_JOURNAL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/lnkr"
readonly TEST_JOURNAL_NAME="$(printf "%s.journal" ${TESTSPACE#'/'} | tr '/' '%')"
readonly TEST_JOURNAL="$TEST_JOURNAL_DIR/$TEST_JOURNAL_NAME"

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
  [ -d "$TESTSPACE" ] && cd "$LNKR_REPO_ROOT" && rm -rf "$TESTSPACE" || true
}

rm_cache() {
  rm -rf "$CACHE_DIR"
}

rm_journal() {
  rm -f "$TEST_JOURNAL"
}

assert_lib_exists() {
  [ "$(ls -l1 "$CACHE_DIR"/lnkr_lib_"${1:-}"*.sh | wc -l)" -eq 1 ]
}

make_repo_with_submodule() {
  rm_testspace
  git clone https://github.com/usommerl/configuration-bash.git $TESTSPACE
  cp "$LNKR_REPO_ROOT/$LIB_FILENAME" "$TESTSPACE/"
  cd "$TESTSPACE"
}
