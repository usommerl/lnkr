#!/usr/bin/env bats

setup() {
  export repo_root=$(git rev-parse --show-toplevel)
  export testspace=$repo_root/test/testspace
  mkdir -p $testspace
  cp $repo_root/lnkr.template $testspace
  export lnkr=$testspace/lnkr.template
}

teardown() {
  [ -d "$testspace" ] && rm -rf "$testspace"
  echo >&2
  for line in ${lines[@]}; do
    echo $line >&2
  done
}

@test "bootstrap should dowload library if it does not exist" {
  run $lnkr
  [ "$status" -eq 0 ]
  [ -e "$testspace/lnkr_lib.sh" ]
}

@test "bootstrap should not overwrite existing library" {
  echo 'echo "Fake lnkr library"; exit 254' > $testspace/lnkr_lib.sh
  run $lnkr
  [ "$output" = "Fake lnkr library" ]
  [ "$status" -eq 254 ]
}
