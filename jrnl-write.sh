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
        *) echo "jrnl-write: I don't know what to do with $@ yet" ;;
    esac
    
    # COMMAND
    ## jrnl $selected_journal --config-file $CONFIG_FILE_PATH optional_date: var_args"
    log "EXECUTED: $JRNL $date $@"
    $JRNL $date $@
}

new_entry_with_no_editor() {
    journal=$JOURNAL
    $JRNL --config-override editor ""
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

main "$@"
