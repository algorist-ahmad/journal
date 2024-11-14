#!/bin/bash

# default variables, manually add to reveal_variables()

CACHE="$HOME/.cache" # default cache location where cached data is stored
DEBUG=0              # reveals environment variables if true
EDIT=0
DELETE=0
HOME_DIR=''          # this script's parent directory
INPUT_ARGS="$@"      # arguments received by main script
PARSED_ARGS=''       # arguments parsed
LOG=''               # where stderr go defined in .env
JRNL=''              # the true jrnl command wrapped by this one defined in .env
OK=1                 # if everything is OK, continue execution of arguments
WRITE_MODE='off'
WRITE_MODE_INDICATOR_FILE="$CACHE/jrnl/write.mode.bool"

log() { echo "$@" >> "$LOG"; };

function main() {
    verify_program_integrity # makes sure .env is present among other things
    source_env
    prepare_true_command
    check_write_mode
    # parse_args $INPUT_ARGS
    [[ "$1" == "debug" ]] && shift && reveal_variables 
    [[ $OK -eq 1 ]] && route_args "$@"
}

# TODO: route to programs instead and also move data to private and this code to public
route_args() {

    log "jrnl-main: ARGS = $@"

    # Put non-terminating case first
    # --printenv ) 
    #         shift; printenv=1 ;;

    # terminating cases
    case "$1" in
        # NO ARGUMENT

        '') show_today_jrnl ;;

        # SPECIAL COMMANDS

        -\?) 
            print_info ;; # such as context, number of todos, consumed status, etc...
        --)
            shift; bypass_wrapper "$@";; # go directly to the true jrnl program
        --amend | -a | amend)
            shift; edit_today_journal;;
        --date  | -d | dat*) 
            shift; view_journal_on_date "$@" ;;
        --template | -T | temp*) 
            load_template "$2" ;;
        --todo | -t)
            edit_today_todo "$@" ;;
        --undo | -u | und*)
            shift; execute_true_jrnl --delete -1 ;;
        --write | -w | wri*) 
            shift; "$HOME_DIR/jrnl-write.sh" "$@" ; exit "$?" ;;
        --no-editor | -wn | -nw )
            shift; "$HOME_DIR/jrnl-write.sh" "-n" ; exit "$?" ;;
        src  | -D) 
            shift; debug_code "$@" ;;
        git    | -g) 
            shift; execute_git "$@" ;;
        conf*  | -C) 
            shift; config_jrnl "$@" ;;
        cont*  | -c) 
            shift; context "$@" ; exit "$?";;
        push   | -p) 
            shift; push_to_remote ;;
        view   | ?d) 
            view_entries_in_terminal "$@" ;;
        yest*)
            view_journal_yesterday "$@" ;;

        # Cases where $1 begins with '-' or '@', pass directly to jrnl without processing
        -* | @*) $JRNL $@ ;;

        # If no case matched above, then treat it as a filter by default
        *) filter_journal "$@"

    esac
}

verify_program_integrity() {
    export HOME_DIR="$(dirname "$(readlink -f "$0")")"
    export env="$HOME_DIR/.env"
    # env not exist
    if [[ ! -f "$env" ]]; then echo "NO $env FOUND. Create one in $HOME_DIR"; exit 1; fi
}

source_env() {
    tmp=$HOME_DIR
    # Load config variables
    source "$HOME_DIR/.env"
    # verify contents, issue warning if needed
    if [[ "$HOME_DIR" != "$tmp" ]]; then echo "Warning: HOME_DIR [$HOME_DIR] not matching actual parent ($tmp)"; fi
    # does LOG exists?
    if [[ ! -f "$LOG" ]]; then
        echo "$LOG DOES NOT EXIST IN $tmp/.env. Will send output to $tmp/jrnl.log instead."
        export LOG="$tmp/jrnl.log"
    fi
}

parse_args() {
    EDIT=0
    DELETE=0
    ON=0
    FUCK=0
    SHIT=0
    last_opt=''

    for arg in $@; do
        echo "$arg"
        sleep 0.1
    done

    # Iterate over arguments using a while loop
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --edit)
                export EDIT=1
                last_opt='--edit'
                shift  # Move to next argument
                ;;
            delete)
                export DELETE=1
                last_opt='delete'
                shift
                ;;
            on)
                export ON=1
                shift
                ;;
            *)
                # Handle unknown argument
                echo "$last_opt: $1"
                shift
                ;;
        esac
    done

    echo "EDIT=$EDIT"
    echo "DELETE=$DELETE"
    echo "ON=$ON"
}

prepare_true_command() {
    if [[ ! -f "$TRUE_JRNL" ]]; then echo "$TRUE_JRNL DOES NOT EXIST."; exit 1; fi
    if [[ ! -f "$CONFIG_FILE_PATH" ]]; then echo "CONFIG FILE $CONFIG_FILE_PATH DOES NOT EXIST. Create or update in .env"; exit 2; fi
    if [[ ! -n "$DEFAULT_JOURNAL"  ]]; then echo "NO DEFAULT JOURNAL DEFINED IN .env"; fi

    journal=$(get_journal)
    export JRNL="$TRUE_JRNL $journal --config-file $CONFIG_FILE_PATH"
    log "$JRNL"
}

bypass_wrapper() {
    #"$JRNL" "$@"
    echo "that shit wont work"
}

check_write_mode() {
    # if running, abort, if not, mark as rnning
    touch "$WRITE_MODE_INDICATOR_FILE"
    WRITE_MODE=$(<$WRITE_MODE_INDICATOR_FILE)
    export WRITE_MODE
    export WRITE_MODE_INDICATOR_FILE
}

config_jrnl() {
    if [[ $(systemd-detect-virt) == "wsl" ]]; then
        "$EDITOR" "$CONFIG_WSL"
    else
        "$EDITOR" "$CONFIG"
    fi
}

context() {
    context_value=$(get_context)
    case "$1" in
        -? | "")                      print_selected_journal=1 ; list_context=1 ;;
        -s | selected)                print_selected_journal=1 ;;
        -l | list)                    list_context=1 ;;
        -n | none)                    set_context='none' ;;
        -w | work)                    set_context='work' ;;
        *)                            warn 'Usage: $ jrnl context [ list | none | acad | work | flex ]'; exit 1 ;;
    esac
    if [[ -n $print_selected_journal ]]; then
        case "$context_value" in
            none)  warn "Main journal selected." ;;
            work)  warn "Work journal selected." ;;
            *)     err  "No journal named $context_value exists." ; warn "this could be a bug check function `context`" ; exit 1 ;;
        esac
    fi
    if [[ -n $list_context ]]; then
        echo -e "  -none\n  -work"
    fi
    if [[ -n $set_context ]]; then
        echo "$set_context" > "$CONTEXT"
        warn "Context set to [$set_context]"
    fi
}

debug() {
    # show debug message if enabled
    if [[ $DEBUG -eq 1 ]]; then
        echo -e "\e[36m$@\e[0m"
    fi
}

debug_code() {
    if [[ -n "$@" ]]
        then editor="$@"
        else editor="micro"
    fi
    "$editor" "$0"
    exit "$?"
}

edit_today_journal() {
    $JRNL -on today --edit
    exit "$?"
}

edit_today_todo() {
    $JRNL -on today -contains 'TODO' $2
}

execute_git() {
    git -C "$DOMAIN" "$@"
    exit "$?"
}

execute_true_jrnl() {
    J=$(get_journal)
    debug "$jrnl" "$J" "$@"
    "$jrnl" "$J" "$@" ; x="$?"
    context selected
    exit "$x"
    #confirmation code
    # warn "Do you want to execute $jrnl $C $@ ? [Y/n] "
    # read -r answer
    # 
    # if [ -z "$answer" ]; then
        # answer="yes"  # Default to "yes" if user just presses Enter
    # fi
    # 
    # if [ "$answer" == "yes" ] || [ "$answer" == "y" ]; then
        # $jrnl $C $@
    # elif [ "$answer" == "no" ] || [ "$answer" == "n" ]; then
        # echo "Exiting..."
        # # Do nothing, just exit
    # else
        # echo "Invalid input. Defaulting to 'no'."
        # echo "Exiting..."
        # # Do nothing, just exit
    # fi
}

filter_journal() {
    # Capture the output of the journal command
    search_result=$($JRNL -contains "$@")

    if [[ -z $search_result ]]; then exit 0; fi

    # $JRNL -contains "$@" | grep --color=always -E "$@|$" | less -R

      # Capture the output of the journal command
    output=$($JRNL -contains "$@" 2> /dev/null | grep --color=always -E "$@|$")

    # Use `grep` to check if the output is "no entries found" and handle accordingly
    echo "$output" | less -R
}

# sub-command, PUT IN ITS OWN SCRIPT TODO:
jrnl_write() {
    case "$1" in
        '') new_entry_with_no_editor ;;
        *) echo "jrnl-write: I don't know what to do with $1 yet" ;;
    esac
    exit "$?"
}

# generate short form uuid
generate_uuid() {
    uuid=$(uuidgen | head -c 8)
    # Using ANSI escape codes to style the output
    echo -e "entry id: \033[1;37;41m$uuid\033[0m (must include manually!)"
}

load_template() {
    if [[ -z "$TEMPLATES" ]]; then err "\$TEMPLATES is NOT defined in $HOME_DIR/.env!"; exit 88; fi;
    template_file="$TEMPLATES/$1"
    echo $template_file
    if [[ -d "$template_file" ]]; then err "$template_file is a directory"; exit 89; fi
    if [[ ! -f "$template_file" ]]; then err "$template_file DOES NOT EXIST"; exit 90; fi
    generate_uuid
    # write mode ON
    echo 'on' > "$WRITE_MODE_INDICATOR_FILE"
    $JRNL --template "$template_file"
    # write mode OFF
    echo 'off' > "$WRITE_MODE_INDICATOR_FILE"
    exit "$?"
}

get_context() {
    if [[ ! -f "$CONTEXT" ]]; then
        dirname=$(dirname $CONTEXT)
        mkdir -pv $dirname
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

print_info() {
    context selected
    context list
    exit 0
}

# Help function to display usage information and option descriptions
print_help() {
    # # ANSI color codes for colors without using \e[33m and \e[31m
    # GREEN='\033[0;32m'
    # BLUE='\033[0;34m'
    # NC='\033[0m' # No Color
# 
    # echo "Usage: $(basename "$0") [OPTIONS]"
    # echo "Options:"
    # for option in "${!option_descriptions[@]}"; do
        # printf "  ${GREEN}%-12s${NC} %s\n" "$option" "${option_descriptions[$option]}"
    # done
    # exit 0
    echo 'case "$1" in
            "")   new_entry "$@" ;;
            -?) print_info ;; # such as context
            .) view_journal_today "$@" ;;
            ..) view_journal_yesterday "$@" ;;
            help   | -h) shift; print_help ;;
            debug  | -D) shift; debug_code "$@" ;;
            git    | -g) shift; execute_git "$@" ;;
            config | -C) shift; config_jrnl "$@" ;;
            context| -c) shift; context "$@" ;;
            update | -u) shift; update "$DOMAIN" -add "." -commit "updating from $HOSTNAME" ;;
            push   | +p) shift; push_to_remote ;;
            view   | ?d) view_entries_in_terminal "$@" ;;
            *) execute_true_jrnl "$@" ;;
        esac'
    exit 0
}

# exit-function
push_to_remote() {
    git -C $DOMAIN add .
    git -C $DOMAIN commit -m "updating from $HOSTNAME"
    git -C $DOMAIN push
    exit "$?"
}

reveal_variables() {
    echo "DEBUG=True"
    echo "For real debug, do jrnl --debug"
    echo ""
    echo "WRITE_MODE=$WRITE_MODE"
    echo "WRITE_MODE_INDICATOR_FILE=$WRITE_MODE_INDICATOR_FILE"
    echo "TRUE_JRNL=$TRUE_JRNL"
    echo "JRNL_DATA=$JRNL_DATA"
    echo "TEMPLATES=$TEMPLATES"
    echo "CONFIG_FILE_PATH=$CONFIG_FILE_PATH"
    echo "CONTEXT=$CONTEXT"
    echo "DEFAULT_JOURNAL=$DEFAULT_JOURNAL"
    echo "SECONDARY_EDITOR=$SECONDARY_EDITOR"
    echo "CACHE=$CACHE"
    echo "HOME_DIR=$HOME_DIR"
    echo "INPUT_ARGS=$INPUT_ARGS"
    echo "PARSED_ARGS=$PARSED_ARGS"
    echo "LOG=$LOG"
    echo "JRNL=$JRNL"
    echo "OK=$OK"
}

show_today_jrnl() {
    warn "Today's entries:"
    view_journal_today
    warn "To read journal on specific date, do jrnl -d DATE"
    warn "To start writing, do jrnl -w"
    warn "Use one of the available templates in $JRNL_DATA/templates!"
    exit 0
}

get_pager() {
    if [ -f '/bin/bat' ]; then
        echo 'bat -p'
    else
        echo 'less -R'
    fi
}

# exit function
view_entries_in_terminal() {
    context selected
    J=$(get_journal)
    length="${1:0:1}"
    limit="$2"
    debug "d = $length"
    _date=$(date -d "$length days ago" "+%a %b %e %Y")
    debug "date = $_date"
    "$jrnl" "$J" -on $(date -d "$_date" +%F) -n $limit
    warn "Viewing entries for $_date"
    exit "$?"
}

view_journal_today() {
    pager=$(get_pager) 
    $JRNL -on today | $pager
    echo "$JRNL -on today" >> "$LOG"
}

view_journal_on_date() {
    J=$(get_journal)
    warn "Journal: $J"
    date_args="$*"
    date=$(date -d "$date_args" +"%Y-%m-%d")
    if [ -z "$date" ]; then exit 9; fi
    log "$JRNL -on $date"
    $JRNL -on $date ; x="$?"
    exit "$x"
}

view_journal_yesterday() {
    J=$(get_journal)
    $JRNL "$J" -on yesterday ; x="$?"
    context selected
    exit "$x"
}

warn() { echo -e "\e[33m$@\e[0m" >&2; }
err()  { echo -e "\e[31m$@\e[0m" >&2; }

main "$@"
