readonly REPO_ROOT=$(git rev-parse --show-toplevel)
readonly TESTSPACE=$BATS_TEST_DIRNAME/testspace
readonly LIB_FILENAME=lnkr_lib.sh

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

repo_with_submodules() {
  rm $TESTSPACE/$LIB_FILENAME
  git clone https://github.com/usommerl/configuration-bash.git $TESTSPACE
  cp $REPO_ROOT/$LIB_FILENAME $TESTSPACE/
}
