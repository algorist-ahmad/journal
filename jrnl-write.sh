#!/bin/bash

# imports
source "$HOME_DIR/.env"
source "$HOME_DIR/logger.sh"

date='' # the date to write for

function main() {

    log "jrnl-write: ARGS = $@"
    abort_write_if_running

    case "$1" in
        '') new_entry_with_default_template ;;
        -n) new_entry_with_no_editor ;;
        -T) new_entry_with_template ;; #TODO:
        -d | --date) echo "No editor won't work with date." ; exit 1 ;; # export date="$(date --date="$2" +"%Y-%m-%d"):" ; log "date is $date" ; shift 2; main "$@" ;; # no args provided
        *) confirm_write "$@" ;;
    esac
    
    # # COMMAND
    # ## jrnl $selected_journal --config-file $CONFIG_FILE_PATH optional_date: var_args"
    # log "EXECUTED: $JRNL $date $@"
    # $JRNL $date $@
}

abort_write_if_running() {
    if [[ "$WRITE_MODE" == "on" ]]; then
        err "jrnl-write is already running!"
        echo "Either finish editing or write to temporary file to avoid overwriting"
        exit 5
    fi
}

new_entry_with_default_template() {
    template_file="$TEMPLATES/tmp"
    uuid=$(uuidgen | head -c 8)
    # generate uuid in template
    echo -e "entry $uuid\n" > "$template_file"
    # define journal used
    journal=$JOURNAL
    # write mode ON
    echo 'on' > "$WRITE_MODE_INDICATOR_FILE"
    # execute command
    $JRNL --config-override editor 'micro +3:1' --template "$template_file" ; status="$?"
    # output new id if insert successful
    [[ $status -eq 0 ]] && echo -e "id: $uuid"
    # clear template
    echo '[removed]' > "$template_file"
    # write mode OFF
    echo 'off' > "$WRITE_MODE_INDICATOR_FILE"
    # done
    exit $status
}

new_entry_with_micro() {
    generate_uuid
    # get journal
    journal=$JOURNAL
    # execute command
    # write mode ON
    echo 'on' > "$WRITE_MODE_INDICATOR_FILE"
    $JRNL --config-override editor micro
    # write mode OFF
    echo 'off' > "$WRITE_MODE_INDICATOR_FILE"
    exit "$?"
}

new_entry_with_no_editor() {
    generate_uuid
    err "Beware: cannot use jrnl in 2 terminals at once."
    # get journal
    journal=$JOURNAL
    # execute command
    # write mode ON
    echo 'on' > "$WRITE_MODE_INDICATOR_FILE"
    $JRNL --config-override editor ''
    # write mode OFF
    echo 'off' > "$WRITE_MODE_INDICATOR_FILE"
    exit "$?"
}

# generate short form uuid
generate_uuid() {
    uuid=$(uuidgen | head -c 8)
    # Using ANSI escape codes to style the output
    echo -e "entry id: \033[1;37;41m$uuid\033[0m (include manually)"
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
