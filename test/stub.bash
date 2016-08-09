export PATH="$BATS_TEST_DIRNAME/stub:$PATH"

stub() {
  if [ ! -d $BATS_TEST_DIRNAME/stub ]; then
    mkdir $BATS_TEST_DIRNAME/stub
  fi
  touch $BATS_TEST_DIRNAME/stub/$1
  [ -z "$3" ] && local rc=0 || local rc="$3"
  echo "echo $2; exit $rc" > $BATS_TEST_DIRNAME/stub/$1
  chmod +x $BATS_TEST_DIRNAME/stub/$1
}

rm_stubs() {
  rm -rf $BATS_TEST_DIRNAME/stub
}
