export PATH="$BATS_TEST_DIRNAME/stub:$PATH"

stub() {
  if [ ! -d $BATS_TEST_DIRNAME/stub ]; then
    mkdir $BATS_TEST_DIRNAME/stub
  fi
  touch $BATS_TEST_DIRNAME/stub/$1
  echo "(>&${4:-'1'} echo $2); exit ${3:-'0'}" > $BATS_TEST_DIRNAME/stub/$1
  chmod +x $BATS_TEST_DIRNAME/stub/$1
}

rm_stubs() {
  /bin/rm -rf $BATS_TEST_DIRNAME/stub
}

stub_curl_and_wget() {
  stub curl "bash: curl: command not found" 127 2
  stub wget "bash: wget: command not found" 127 2
}
