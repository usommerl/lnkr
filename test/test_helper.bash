print_cmd_output() {
  echo >&2
  for line in ${lines[@]}; do
    echo $line >&2
  done
}

make_testspace() {
  export repo_root=$(git rev-parse --show-toplevel)
  export testspace=$repo_root/test/testspace
  mkdir -p $testspace
}

rm_testspace() {
  [ -d "$testspace" ] && rm -rf "$testspace"
}
