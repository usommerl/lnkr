#!/usr/bin/env bash

readonly LOG_NAME='lnkr.log'
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

info() {
  __logger_base '[info]' "$@"
}

warn() {
  __logger_base '\e[1;33m[warn]' "$@"
}

fail() {
  __logger_base '\e[1;31m[fail]' "$@"
  exit 1
}

lnk() {
  local link_target=$1
  local link_location=$2
  if [ ! -e "$link_target" ]; then
    warn "Link target $link_target does not exist. You will create a dead link!"
  fi
  [ -e "$link_location" ] && __create_backup "$link_location"
  mkdir -p $(dirname "$link_location")
  info "ln -sfT $(ln -vsfT $link_target $link_location)"
  __record_link "$link_target" "$link_location"
}

__create_backup() {
  local link_location=$1
  local backup_location="${link_location}.backup-$(__timestamp)"
  warn "Link location is occupied. Creating backup of file ${link_location}"
  [ -e "$backup_location" ] && fail "Could not create backup"
  warn "mv -n  $(mv -vn $link_location $backup_location)"
  __record_backup "$backup_location"
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

__operation() {
  local callback="__$(echo $1 | tr '[:upper:]' '[:lower:]')"
  info "$1 repository '$REPO_NAME'"
  if declare -F "$callback" &> /dev/null; then
    $callback
  else
    fail "Function $callback is not defined"
  fi
  info "-"
  printf "\n" | __output_writer
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
  if declare -F install &> /dev/null; then
    install
  else
    fail 'Function install() is not defined'
  fi
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
  printf "\e[0m$(__timestamp) $1\e[0m $2\n" | __output_writer
}

__output_writer() {
  local log=$START_DIRECTORY/$LOG_NAME
  tee >(sed 's/\x1b\[[0-9;]*m//g' >> $log)
}

__add_to_gitignore() {
  for filename in "$LIB_NAME" "$LOG_NAME" "$JOURNAL_NAME"; do
    grep -E "$filename\$" .gitignore &> /dev/null
    [ "$?" -ne 0 ] && echo "$filename" >> .gitignore
  done
}

__print_help() {
  local script_name=$(basename $0)
  local indent_option='  '
  local indent='      '
  echo ""
  echo -e "SYNOPSIS: ${script_name} [OPTION]\n"
  echo -e "${indent_option} ${INSTALL_SWITCH_SHORT}, ${INSTALL_SWITCH_LONG}\n"
  echo -e "${indent} Executes the install procedure defined in install_hook."
  echo -e "${indent} Symbolic links that are created with lnk and su_lnk won't"
  echo -e "${indent} overwrite existing files. These functions create backups"
  echo -e "${indent} that will be restored automatically if you run this script"
  echo -e "${indent} with the ${REMOVE_SWITCH_LONG} option."
  echo ""
  echo -e "${indent_option} ${REMOVE_SWITCH_SHORT}, ${REMOVE_SWITCH_LONG}\n"
  echo -e "${indent} Removes created links and restores all backups that where"
  echo -e "${indent} made during a previous install."
  echo ""
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

[ -n "$LIB_TEST" ] && return

__main "$@"
exit 0
