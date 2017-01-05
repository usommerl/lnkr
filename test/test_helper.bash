readonly TESTSPACE=$BATS_TEST_DIRNAME/testspace
readonly BUILDSPACE=$BATS_TEST_DIRNAME/buildspace
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
  for directory in "$TESTSPACE" "$BUILDSPACE"; do
    [ -d "$directory" ] && cd "$LNKR_REPO_ROOT" && rm -rf "$directory" || true
  done
  unset directory
}

rm_cache() {
  rm -rf "$CACHE_DIR"
}

rm_journal() {
  rm -f "$TEST_JOURNAL"
}

assert_lib_exists() {
  local version=$(head -n 1 "$TESTSPACE/$LOCKFILE") 2>&-
  [ -e "$CACHE_DIR/${LIB_FILENAME/%.sh/_$version.sh}" ]
}

make_repo_with_submodule() {
  rm_testspace
  for repo in submodule toplevel; do
    local path="$BUILDSPACE/$repo"
    mkdir -p "$path" && git -C "$path" init
    case "$repo" in
      submodule)
        echo $repo >> "$path/$repo" && git -C "$path" add "$repo"
        ;;
      toplevel)
        git -C "$path" submodule add "file://$BUILDSPACE/submodule"
        ;;
    esac
    git -C "$path" commit -m 'message'
    mv "$path" "$path.tmp"
    git -C "$BUILDSPACE" clone --bare "$path.tmp" "$repo"
    rm -rf "$path.tmp"
  done
  git clone --no-hardlinks "file://$BUILDSPACE/toplevel" "$TESTSPACE"
  cd "$TESTSPACE"
}
