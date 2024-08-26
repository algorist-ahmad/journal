#!/bin/bash

# imports
source "$HOME_DIR/.env"
source "$HOME_DIR/logger.sh"

date='' # the date to write for

function main() {

    log "jrnl-write: ARGS = $@"

    case "$1" in
        '') new_entry_with_no_editor ;;
        -d | --date) echo "No editor won't work with date." ; exit 1 ;; # export date="$(date --date="$2" +"%Y-%m-%d"):" ; log "date is $date" ; shift 2; main "$@" ;; # no args provided
        *) confirm_write "$@" ;;
    esac
    
    # # COMMAND
    # ## jrnl $selected_journal --config-file $CONFIG_FILE_PATH optional_date: var_args"
    # log "EXECUTED: $JRNL $date $@"
    # $JRNL $date $@
}

new_entry_with_no_editor() {
    # generate uuid to establish reference between entry and real world objects
    uuid=$(uuidgen)
    # Using ANSI escape codes to style the output
    echo -e "entry id: \033[1;37;41m$uuid\033[0m (must include manually!)"
    # get journal
    journal=$JOURNAL
    # execute command
    $JRNL --config-override editor ''
    exit "$?"
}

get_context() {
    if [[ ! -f "$CONTEXT" ]]; then
        echo "none" > "$CONTEXT"
        echo "none"
    else
        cat "$CONTEXT"
    fi
}

get_journal() {
    local context=$(get_context)
    case "$context" in
        none)  echo 'main'; exit 0 ;;
        work)  echo 'work'; exit 0 ;;
        *) warn "unverified journal, see get_journal()" ; echo $context ;;
    esac
}

confirm_write() {
    OK=$(get_confirmation "$*")
    if [[ $OK -gt 0 ]]; then
        $JRNL $@
        exit 0
    else
        err Not written.
        exit 0
    fi
}

get_confirmation() {
    read -p "Write
    \"$1\"
to journal $(get_journal)? > " -n 1 -r
    >&2 echo   # new line
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        echo 1
        exit 0
    fi
    echo 0
}

err()  { echo -e "\e[31m$@\e[0m" >&2; }

main "$@"
