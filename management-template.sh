#!/usr/bin/env bash

############################################################## begin-template

_backupLog=$CURRENT_DIRECTORY/.backup.log
_optionInstallShort='-i'
_optionInstallLong='--install'
_optionRestoreShort='-r'
_optionRestoreLong='--restore-backups'

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
        echo $_backupLocation >> $_backupLog
    fi

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

function _headline() {
    echo -e ">>>>>> \e[1;37m$@\e[0m"
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
            sed -i "/$_pattern/d" $_backupLog
        fi
   else
       fail "Backup location does not exist."
   fi
}

function _defaultRestoreProcedure() {
    if ! [ -e $_backupLog ]; then
        touch $_backupLog
    fi
    local _logContainedLines=false
    while read -r e; do
       _restoreEntry $e
       _logContainedLines=true
    done < $_backupLog
    if ! $_logContainedLines; then
       info "Log file is empty. There are no backups to restore."
    fi
}


function _printHelp() {
    local _indentParameter='  '
    local _indent='      '
    echo -e "\nControls the lifecycle of this module\n"
    echo -e "SYNOPSIS: $(basename $0) [OPTION]\n"
    echo -e "$_indentParameter $_optionInstallShort, $_optionInstallLong\n"
    echo -e "$_indent Installs the configuration settings contained in this module"
    echo -e "$_indent by creating symbolic links in the required locations. This"
    echo -e "$_indent operation won't overwrite any existing configuration files." 
    echo -e "$_indent It will automatically create backups if there are any con-"
    echo -e "$_indent flicting regular files or folders."
    echo ""
    echo -e "$_indentParameter $_optionRestoreShort, $_optionRestoreLong\n"
    echo -e "$_indent Restores backups which where made during a previous install"
    echo -e "$_indent operation."
    echo ""
}

if [ -n "$MODULE" ]; then
    _headlinePrefix="$(echo $MODULE | tr [:lower:] [:upper:]) -"
else
    fail "Module name not defined."
fi

if [ "$1" = $_optionRestoreShort ] || [ "$1" = $_optionRestoreLong ]; then
    _headline "$_headlinePrefix Restore backups"
    if declare -F RESTORE &> /dev/null; then
        RESTORE
    else
        _defaultRestoreProcedure
    fi
elif [ "$1" = $_optionInstallShort ] || [ "$1" = $_optionInstallLong ]; then
    _headline "$_headlinePrefix Install configuration"
    if declare -F INSTALL &> /dev/null; then
        INSTALL
    else
        fail "Install function not defined."
    fi
else
    _printHelp
fi

exit 0

############################################################## end-template
