#!/usr/bin/env bash

readonly LOG_NAME='lnkr.log'
readonly JOURNAL_NAME='.lnkr.journal'
readonly JOURNAL_FILE=$START_DIRECTORY/$JOURNAL_NAME
readonly REPO_NAME=$(basename $(git rev-parse --show-toplevel))
readonly INSTALL_SWITCH_SHORT='-i'
readonly INSTALL_SWITCH_LONG='--install'
readonly REMOVE_SWITCH_SHORT='-r'
readonly REMOVE_SWITCH_LONG='--remove'
readonly HELP_SWITCH_SHORT='-h'
readonly HELP_SWITCH_LONG='--help'
readonly SEP='\t\0'

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

restore_entry() {
  local backup_location=$1
  local original_location=$(echo $backup_location | sed 's/\.backup.*$//')

  info "Recorded backup location is ${backup_location}"
  if [[ -e $backup_location ]] && ! [[ -L $backup_location ]]; then
    if [[ -L $original_location ]]; then
      rm $original_location
    fi
    if [[ -e $original_location ]]; then
      fail "Could not move backup to ${original_location}"
    else
      # Look for a different solution
      info "mv -n $(mv -nv $backup_location $original_location)"
      local pattern=$(echo $backup_location | sed -r 's/(.*)(backup.*$)/\2/')
      sed -i "/${pattern}/d" "$LOGFILE"
    fi
  else
    fail 'Backup location does not exist'
  fi
}

default_remove_procedure() {
  #if ! [[ -e $LOGFILE ]]; then
  #touch $LOGFILE
  #fi
  local log_contained_lines=false
  while read -r e; do
    restore_entry $e
    log_contained_lines=true
  done < $LOGFILE
  if ! $log_contained_lines; then
    info 'Log file is empty. There are no backups to restore.'
  fi
}

print_divider() {
  echo -e "------ \e[1;37m${REPO_NAME} $@\e[0m"
}

__remove() {
  print_divider 'Remove'
  if declare -F restore_hook &> /dev/null; then
      restore_hook
  else
      default_remove_procedure
  fi
  print_divider
}

__install() {
  print_divider 'Install'
  if declare -F install_hook &> /dev/null; then
    install_hook
  else
    fail 'Function install_hook() is not defined'
  fi
  print_divider
}

__timestamp() {
  echo "$(date --iso-8601=s)"
}

__record_backup() {
  __journal_base "BAK$SEP$1"
}

__record_link() {
  local link_target=$1
  local link_location=$2
  __journal_base "LNK$SEP$link_target$SEP$link_location"
}

__journal_base() {
  printf "$(__timestamp)$SEP$(id -u)$SEP$1\n" >> $JOURNAL_FILE
}

__logger_base() {
  local log=$START_DIRECTORY/$LOG_NAME
  printf "\e[0m$(__timestamp) $1\e[0m $2\n" | \
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
      __remove
      ;;
    $INSTALL_SWITCH_SHORT | $INSTALL_SWITCH_LONG)
      __install
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
