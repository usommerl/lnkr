#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace
set -o functrace

readonly REPOSITORY_ROOT="$(readlink -f "$(git rev-parse --show-toplevel)")"
readonly REPOSITORY_NAME="$(basename "$REPOSITORY_ROOT")"
readonly JOURNAL_FILENAME="$(printf "%s.journal" "${REPOSITORY_ROOT#'/'}" | tr '/' '%')"
readonly JOURNAL_DIRECTORY="${XDG_DATA_HOME:-$HOME/.local/share}/lnkr"
readonly JOURNAL="$JOURNAL_DIRECTORY/$JOURNAL_FILENAME"
readonly ACTION_LINK='LNK'
readonly ACTION_BACKUP='BAK'
readonly RECURSE_SWITCH_SHORT='-r'
readonly RECURSE_SWITCH_LONG='--recurse-submodules'
readonly VERSION_SWITCH_SHORT='-v'
readonly VERSION_SWITCH_LONG='--version'
readonly HELP_SWITCH_SHORT='-h'
readonly HELP_SWITCH_LONG='--help'
readonly LOG_TO_SYSLOG="$(command -v logger)"
[ -z "${LNKR_LIB_TEST:-}" ] && readonly SUDO_CMD="$(command -v sudo)"
[ -d "$JOURNAL_DIRECTORY" ] || mkdir -p "$JOURNAL_DIRECTORY" &>/dev/null

info() {
  __logger_base 'info' "$@"
}

warn() {
  __logger_base 'warn' "$@"
}

fail() {
  __logger_base 'fail' "$@"
  exit 1
}

sudo() {
  [ -z "${SUDO_CMD:-}" ] && fail 'Command sudo is not available'
  if [ "$1" == 'link' ]; then
    sudo_link="$SUDO_CMD "
    eval "$@"
    unset sudo_link
  else
    eval "$SUDO_CMD $*"
  fi
}

link() {
  local link_target=$1
  local link_location=$2
  if [ ! -e "$link_target" ]; then
    warn "Link target $link_target does not exist. You will create a dead link!"
  fi
  [ -e "$link_location" ] && __create_backup "$link_location"
  eval "${sudo_link:-}mkdir -p $(dirname "$link_location")"
  eval "${sudo_link:-}ln -sfT $link_target $link_location" &&
    info "Create link: $link_location -> $link_target" &&
      __record_link "$link_target" "$link_location"
}

setup_submodules() {
  info "Setup submodules"
  git submodule update --init
  [ "${1:-}" = '--keep-push-url' ] || __modify_submodules_push_url
}

__modify_submodules_push_url() {
  git submodule -q foreach '
    pattern="^.*https:\/\/(github.com)\/(.*\.git).*"
    orgURL=$(git remote -v show | grep origin | grep push)
    newURL=$(echo $orgURL | sed -r "/$pattern/{s/$pattern/git@\1:\2/;q0}; /$pattern/!{q1}")
    if [ "$?" -eq 0 ]; then
      command="git remote set-url --push origin $newURL"
      echo "$command"
      $($command)
    fi'
}

__parse_args() {
  while [ $# -ge 1 ]; do
    case "$1" in
      $RECURSE_SWITCH_SHORT | $RECURSE_SWITCH_LONG)
        readonly RECURSE=true
        ;;
      $VERSION_SWITCH_SHORT | $VERSION_SWITCH_LONG)
        readonly PRINT_VERSION=true
        ;;
      $HELP_SWITCH_SHORT | $HELP_SWITCH_LONG)
        readonly PRINT_HELP=true
        ;;
      install | remove)
        readonly OPERATION="$1"
        ;;
      *)
        readonly PARSE_ERROR=true
        ;;
    esac
    shift
  done
}

__main() {
  __parse_args "$@"
  [ -n "${PRINT_VERSION:-}" ] && __print_version && exit 0
  if [[ -n "${PARSE_ERROR:-}" || -n "${PRINT_HELP:-}" || -z "${OPERATION:-}" ]]; then
    __print_help
    [ -n "${PRINT_HELP:-}" ] && exit 0 || exit 1
  fi
  __operation "$OPERATION"
  [ -n "${RECURSE:-}" ] && __recurse_operation "$@" || true
}

__operation() {
  local callback="__$1"
  local operation="${1^}"
  printf '\n'
  info "$operation repository $REPOSITORY_NAME using $(__version)"
  if declare -F "$callback" &> /dev/null; then
    $callback
  else
    fail "Function $callback is not defined"
  fi
  info "$operation finished"
}

__recurse_operation() {
  local script_name="$(basename "$0")"
  git submodule foreach -q "[ -e \"$script_name\" ] && ./$script_name $*; exit 0"
}

__remove() {
  if declare -F pre_remove_hook &> /dev/null; then
      pre_remove_hook
  fi
  __revert_recorded_actions
  if declare -F post_remove_hook &> /dev/null; then
      post_remove_hook
  fi
}

__install() {
  if [ -s "$JOURNAL" ]; then
    fail "Journal is not empty. Repository $REPOSITORY_NAME already installed?"
  elif declare -F install &> /dev/null; then
    install
  else
    fail 'Function install() is not defined'
  fi
}

__create_backup() {
  local link_location=$1
  local backup_location="${link_location}.backup-$(__timestamp)"
  [ ! -e "$backup_location" ] && eval "${sudo_link:-}mv -n $link_location $backup_location" &&
    info "Create backup: $link_location -> $backup_location" &&
      __record_backup "$backup_location" || fail "Could not create backup"
}

__revert_recorded_actions() {
  if [ ! -s "$JOURNAL" ]; then
    warn "Journal contains no entries. Nothing to remove." && return
  fi
  while read -r line; do
    remove_journal_entry='true'
    __revert_action "$line"
    [ "$remove_journal_entry" == 'true' ] && __remove_journal_entry "$line"
  done < <(tac "$JOURNAL")
  unset line remove_journal_entry
  [ ! -s "$JOURNAL" ] && rm -f "$JOURNAL"
}

__revert_action() {
  local user="$(__extract_field "$1" "1")"
  local action="$(__extract_field "$1" "3")"
  local args="$(__extract_field "$1" "4-")"
  [ "$user" == "root" ] && local sudo_revert="sudo "
  case "$action" in
    "$ACTION_LINK")
      __remove_link "${sudo_revert:-}" "$args"
      ;;
    "$ACTION_BACKUP")
      __restore_bakup "${sudo_revert:-}" "$args"
      ;;
  esac
}

__remove_link() {
  local link_target="$(__extract_field "$2" "1")"
  local link_location="$(__extract_field "$2" "2")"
  if [ ! -L "$link_location" ]; then
    warn "Could not delete link: '$link_location' is not a symlink"
  else
    eval "${1:-}rm $link_location" &&
      info "Deleted link: '$link_location'" ||
        remove_journal_entry='false'
  fi
}

__restore_bakup() {
  local backup_location="$(__extract_field "$2" "1")"
  local original_location="${backup_location%.backup*}"
  if [ -e "$original_location" ]; then
    warn "Could not restore backup: Path '$original_location' is occupied"
    remove_journal_entry='false'
  elif [ ! -e "$backup_location" ]; then
    warn "Could not restore backup: '$backup_location' does not exist"
  else
    eval "${1:-}mv -n $backup_location $original_location" &&
      info "Restored backup: '$backup_location' -> '$original_location'" ||
        remove_journal_entry='false'
  fi
}

__remove_journal_entry() {
  local pattern="^$(__extract_field "$1" "1")"
  sed -i "/$pattern/d" "$JOURNAL"
}

__extract_field() {
  echo "$1" | cut -d $'\t' -f "$2"
}

__timestamp() {
  date --iso-8601=s
}

__record_backup() {
  __journal_base "$ACTION_BACKUP\t$1"
}

__record_link() {
  local link_target=$1
  local link_location=$2
  __journal_base "$ACTION_LINK\t$link_target\t$link_location"
}

__journal_base() {
  [ -n "${sudo_link:-}" ] && local user='root' || local user="$(id -un)"
  local sha="$(echo "$(__timestamp) $user $1" | sha1sum | cut -d " " -f 1)"
  printf "%s\t%s\t" "$sha" "$user" >> "$JOURNAL"
  printf "$1\n" >> "$JOURNAL"
}

__logger_base() {
  local level=$1
  local color="$(__to_term_color "$level")"
  local priority=$([ "$level" == 'fail' ] && echo 'err' || echo "$level")
  printf "${color}[$level]\e[0m ${2:-}\n"
  [ "$LOG_TO_SYSLOG" ] && logger -t "$(basename "$0")" -p "$priority" -- "${2:-}"
}

__to_term_color() {
  case "$1" in
    'warn')
      printf '\e[1;97m'
      ;;
    'fail')
      printf '\e[1;31m'
      ;;
    *)
      printf '\e[0m'
      ;;
  esac
}

__print_help() {
  local script_name="$(basename "$0")"
  local indent1='  %s\n\n'
  local indent2='      %s\n'
  printf '\n'
  printf "SYNOPSIS: ${script_name} [OPTIONS] <install|remove>\n\n"
  printf "$indent1" "${RECURSE_SWITCH_SHORT}, ${RECURSE_SWITCH_LONG}"
  printf "$indent2" "Checks all git submodules whether they contain a $script_name"
  printf "$indent2" "file and executes them with the same arguments."
  printf '\n'
  printf "$indent1" "${VERSION_SWITCH_SHORT}, ${VERSION_SWITCH_LONG}"
  printf "$indent2" "Print version information"
  printf '\n'
  printf "$indent1" "${HELP_SWITCH_SHORT}, ${HELP_SWITCH_LONG}"
  printf "$indent2" "Print this help text"
  printf '\n'
}

__version() {
  local file="${BASH_SOURCE[0]}"
  local strip_prefix="${file##*lnkr_lib_}"
  echo "${strip_prefix%%.sh}"
}

__print_version() {
  printf 'lnkr %s\n' "$(__version)"
}

[ -n "${LNKR_LIB_TEST:-}" ] && return

__main "$@"
exit 0
