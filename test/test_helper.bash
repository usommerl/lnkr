readonly REPO_ROOT=$(git rev-parse --show-toplevel)
readonly TESTSPACE=$BATS_TEST_DIRNAME/testspace

print_output() {
  echo >&2
  for line in ${lines[@]}; do
    echo $line >&2
  done
}

make_testspace() {
  mkdir -p $TESTSPACE
  cd $TESTSPACE
}

rm_testspace() {
  [ -d "$TESTSPACE" ] && rm -rf "$TESTSPACE"
}
