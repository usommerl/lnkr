#!/usr/bin/env bash

set -e
declare -r CURRENT_DIRECTORY=$(git rev-parse --show-toplevel)
declare -r MODULE_NAME=$(basename $CURRENT_DIRECTORY)
declare -r LOGFILE=$CURRENT_DIRECTORY/.lnkr.log
declare -r INSTALL_SWITCH_SHORT='-i'
declare -r INSTALL_SWITCH_LONG='--install'
declare -r REMOVE_SWITCH_SHORT='-r'
declare -r REMOVE_SWITCH_LONG='--remove'

function info() {
    echo -e "[info] $@"
}

function warn() {
    echo -e "\e[1;33m[warn]\e[0m $@"
}

function fail() {
    echo -e "\e[1;31m[fail]\e[0m $@ Aborting."
    exit 1
}

function requires() {
   command -v $1 &> /dev/null || {
     fail "The command ‘$1’ is required."
   }
}

function link() {
    requires date
    local _target=$1
    local _linkname=$2

    if [ -e $_linkname ] && ! [ -L $_linkname ]; then
        local _timestamp=$(date +"%Y-%m-%dT%T")
        local _backupLocation="$_linkname.backup-$_timestamp"
        warn "Object at $_linkname is not a symbolic link. Creating backup..."
        if [ -e $_backupLocation ]; then
            fail "Could not create backup."
        fi
        warn "mv -n  $(mv -vn $_linkname $_backupLocation)"
        echo $_backupLocation >> $LOGFILE
    fi

    mkdir -p $(dirname $_linkname)
    info "ln -sf $(ln -vsfT $_target $_linkname)"
}

function setupSubmodules() {
    initializeAndUpdateAllSubmodules
    modifySubmodulesPushUrl
}

function initializeAndUpdateAllSubmodules() {
    info "Initialize and update all submodules"
    cd $CURRENT_DIRECTORY
    requires git
    git submodule update --init
}

function modifySubmodulesPushUrl() {
info "Modify push-url of all submodules from github.com (Use SSH instead of HTTPS)"
    cd $CURRENT_DIRECTORY
    requires git
    requires sed
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

function _blockMark() {
    echo -e "------ \e[1;37m$@\e[0m"
}

function _restoreEntry() {
   requires sed
   local _backupLocation=$1
   local _originalLocation=$(echo $_backupLocation | sed 's/\.backup.*$//')

   info "Recorded backup location is $_backupLocation"
   if [ -e $_backupLocation ] && ! [ -L $_backupLocation ]; then
        if [ -L $_originalLocation ]; then
            rm $_originalLocation
        fi
        if [ -e $_originalLocation ]; then
            fail "Could not move backup to $_originalLocation"
        else
            info "mv -n $(mv -nv $_backupLocation $_originalLocation)"
            local _pattern=$(echo $_backupLocation | sed -r 's/(.*)(backup.*$)/\2/')
            sed -i "/$_pattern/d" $LOGFILE
        fi
   else
       fail "Backup location does not exist."
   fi
}

function _defaultRestoreProcedure() {
    if ! [ -e $LOGFILE ]; then
        touch $LOGFILE
    fi
    local _logContainedLines=false
    while read -r e; do
       _restoreEntry $e
       _logContainedLines=true
    done < $LOGFILE
    if ! $_logContainedLines; then
       info "Log file is empty. There are no backups to restore."
    fi
}

function remove() {
  _blockMark "${MODULE_NAME} Restore backups"
  if declare -F RESTORE &> /dev/null; then
      RESTORE
  else
      _defaultRestoreProcedure
  fi
  _blockMark "${MODULE_NAME} End"
}

function install {
  _blockMark "${MODULE_NAME} Install configuration"
  if declare -F install_hook &> /dev/null; then
      install_hook
  else
      fail "Install hook not defined."
  fi
  _blockMark "${MODULE_NAME} End"
}


function print_help() {
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

function main() {
  case "$1" in
    $REMOVE_SWITCH_SHORT | $REMOVE_SWITCH_LONG)
      remove
      ;;
    $INSTALL_SWITCH_SHORT | $INSTALL_SWITCH_LONG)
      install
      ;;
    *)
      print_help
      ;;
  esac
}

main "$@"
exit 0
