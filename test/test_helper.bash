print_cmd_output() {
  echo >&2
  for line in ${lines[@]}; do
    echo $line >&2
  done
}
