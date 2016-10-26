#!/usr/bin/env bash

readonly JOURNAL_NAME='.lnkr.journal'
readonly JOURNAL_FILE=$START_DIRECTORY/$JOURNAL_NAME
readonly REPO_NAME=$(basename $(git rev-parse --show-toplevel))
readonly ACTION_LINK='LNK'
readonly ACTION_BACKUP='BAK'
readonly INSTALL_SWITCH_SHORT='-i'
readonly INSTALL_SWITCH_LONG='--install'
readonly REMOVE_SWITCH_SHORT='-r'
readonly REMOVE_SWITCH_LONG='--remove'
readonly HELP_SWITCH_SHORT='-h'
readonly HELP_SWITCH_LONG='--help'
readonly LOG_TO_SYSLOG=$(command -v logger)

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

link() {
  local link_target=$1
  local link_location=$2
  if [ ! -e "$link_target" ]; then
    warn "Link target $link_target does not exist. You will create a dead link!"
  fi
  [ -e "$link_location" ] && __create_backup "$link_location"
  mkdir -p $(dirname "$link_location")
  ln -sfT $link_target $link_location &&
    info "Create link: $link_location -> $link_target" &&
      __record_link "$link_target" "$link_location"
}

setup_submodules() {
  init_and_update_submodules
  modify_submodules_push_url
}

init_and_update_submodules() {
  info "Initialize and update all submodules"
  git submodule update --init
}

modify_submodules_push_url() {
  info 'Modify push-url of all submodules from github.com (Use SSH instead of HTTPS)'
  git submodule foreach '
  pattern="^.*https:\/\/(github.com)\/(.*\.git).*"
  orgURL=$(git remote -v show | grep origin | grep push)
  newURL=$(echo $orgURL | sed -r "/$pattern/{s/$pattern/git@\1:\2/;q0}; /$pattern/!{q1}")
  if [ "$?" -eq 0 ]; then
    command="git remote set-url --push origin $newURL"
    echo "$command"
    $($command)
  fi
  '
}

__main() {
  __add_to_gitignore
  case "$1" in
    $REMOVE_SWITCH_SHORT | $REMOVE_SWITCH_LONG)
      __operation 'Remove'
      ;;
    $INSTALL_SWITCH_SHORT | $INSTALL_SWITCH_LONG)
      __operation 'Install'
      ;;
    $HELP_SWITCH_SHORT | $HELP_SWITCH_LONG)
      __print_help
      ;;
    *)
      __print_help
      exit 1
      ;;
  esac
}

__operation() {
  local callback="__$(echo $1 | tr '[:upper:]' '[:lower:]')"
  info "$1 repository $REPO_NAME"
  if declare -F "$callback" &> /dev/null; then
    $callback
  else
    fail "Function $callback is not defined"
  fi
  info "$1 finished"
  printf "\n"
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
  if [ -s "$JOURNAL_FILE" ]; then
    fail "Journal is not empty. Repository $REPO_NAME already installed?"
  elif declare -F install &> /dev/null; then
    install
  else
    fail 'Function install() is not defined'
  fi
}

__create_backup() {
  local link_location=$1
  local backup_location="${link_location}.backup-$(__timestamp)"
  [ ! -e "$backup_location" ] && mv -n $link_location $backup_location &&
    info "Create backup: $link_location -> $backup_location" &&
      __record_backup "$backup_location" || fail "Could not create backup"
}

__revert_recorded_actions() {
  if [ ! -s "$JOURNAL_FILE" ]; then
    warn "Abort remove: Journal contains no entries" && return
  fi
  while read -r line; do
    remove_journal_entry='true'
    __revert_action "$line"
    [ "$remove_journal_entry" == 'true' ] && __remove_journal_entry "$line"
  done < <(tac "$JOURNAL_FILE")
  unset line remove_journal_entry
}

__revert_action() {
  local user="$(__extract_field "$1" "1")"
  local action="$(__extract_field "$1" "3")"
  local args="$(__extract_field "$1" "4-")"
  [ "$user" == "$(id -un)" ] && local sudo="sudo -u $user "
  case "$action" in
    "$ACTION_LINK")
      __remove_link "$sudo" "$args"
      ;;
    "$ACTION_BACKUP")
      __restore_bakup "$sudo" "$args"
      ;;
  esac
}

__remove_link() {
  local link_target="$(__extract_field "$2" "1")"
  local link_location="$(__extract_field "$2" "2")"
  if [ ! -L "$link_location" ]; then
    warn "Could not delete link: '$link_location' is not a symlink"
  else
    eval "${1}rm $link_location" &&
      info "Deleted link: '$link_location'" ||
        remove_journal_entry='false'
  fi
}

__restore_bakup() {
  local backup_location="$(__extract_field "$2" "1")"
  local original_location="$(printf "$backup_location" | sed 's/\.backup.*$//')"
  if [ -e "$original_location" ]; then
    warn "Could not restore backup: Path '$original_location' is occupied"
    remove_journal_entry='false'
  elif [ ! -e "$backup_location" ]; then
    warn "Could not restore backup: '$backup_location' does not exist"
  else
    eval "${1}mv -n $backup_location $original_location" &&
      info "Restored backup: '$backup_location' -> '$original_location'" ||
        remove_journal_entry='false'
  fi
}

__remove_journal_entry() {
  local pattern="^$(__extract_field "$1" "1")"
  sed -i "/$pattern/d" "$JOURNAL_FILE"
}

__extract_field() {
  printf "$1" | cut -d $'\t' -f "$2"
}

__timestamp() {
  echo "$(date --iso-8601=s)"
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
  local sha="$(printf "$(__timestamp)$(id -un)$1" | sha1sum | cut -d " " -f 1)"
  printf "%s\t%s\t" "$sha" "$(id -un)" >> $JOURNAL_FILE
  printf "$1\n" >> $JOURNAL_FILE
}

__logger_base() {
  local level=$1
  local color=$(__to_term_color $level)
  local priority=$([ "$level" == 'fail' ] && printf 'err' || printf "$level")
  printf "${color}[$level]\e[0m $2\n"
  [ "$LOG_TO_SYSLOG" ] && logger -t $(basename $0) -p $priority "$2"
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

__add_to_gitignore() {
  for filename in "$LIB_NAME" "$JOURNAL_NAME"; do
    grep -E "$filename\$" .gitignore &> /dev/null
    [ "$?" -ne 0 ] && echo "$filename" >> .gitignore
  done
}

__print_help() {
  local script_name=$(basename $0)
  local indent1='  %s\n\n'
  local indent2='      %s\n'
  printf '\n'
  printf "SYNOPSIS: ${script_name} [OPTION]\n\n"
  printf "$indent1" "${INSTALL_SWITCH_SHORT}, ${INSTALL_SWITCH_LONG}"
  printf "$indent2" "Executes the install procedure defined in install()."
  printf "$indent2" "Symbolic links that are created with lnk and su_lnk won't"
  printf "$indent2" "overwrite existing files. These functions create backups"
  printf "$indent2" "that will be restored automatically if you run this script"
  printf "$indent2" "with the ${REMOVE_SWITCH_LONG} option."
  printf '\n'
  printf "$indent1" "${REMOVE_SWITCH_SHORT}, ${REMOVE_SWITCH_LONG}"
  printf "$indent2" "Removes links and restores all backups that where"
  printf "$indent2" "made during a previous install."
  printf '\n'
}

[ -n "$LIB_TEST" ] && return

__main "$@"
exit 0
