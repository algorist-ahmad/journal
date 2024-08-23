#!/bin/bash

# global variables

HOME_DIR=''  # this script's parent directory
LOG=''       # where stderr go defined in .env
JRNL=''      # the true jrnl command wrapped by this one defined in .env
function main() {

    verify_program_integrity # should be called verify dependencies
    source_env
    prepare_true_command
    route_args "$@"
    
    # CATCH-ALL
    $JRNL $@
}

# TODO: route to programs instead and also move data to private and this code to public
route_args() {
    case "$1" in
        '') show_today_jrnl ;; # no args provided
        -\?) print_info ;; # such as context, number of todos, consumed status, etc...
        '.' ) view_journal_today "$@" ;;
        '..') view_journal_yesterday "$@" ;;
        write  | -w) shift; jrnl_write "$@" ;;
        help   | -h) shift; print_help ;;
        debug  | -D) shift; debug_code "$@" ;;
        git    | -g) shift; execute_git "$@" ;;
        conf*  | -C) shift; config_jrnl "$@" ;;
        cont*  | -c) shift; context "$@" ; exit "$?";;
        update | -u) shift; update "$DOMAIN" -add "." -commit "updating from $HOSTNAME" ;;
        push   | -p) shift; push_to_remote ;;
        view   | ?d) view_entries_in_terminal "$@" ;;
    esac
    
    # SHORTCUTS
    case "$1" in
        tags | -T) shift; execute_true_jrnl --tags ;;
        todo | -t) shift; execute_true_jrnl "@TODO" "$@" ;;
        del* | -d) shift; execute_true_jrnl --delete -n "$1" ;;
        edit | -e) shift; execute_true_jrnl -on today --edit ;;
        undo | -z) shift; execute_true_jrnl --delete -1 ;;
    esac
}

verify_program_integrity() {
    HOME_DIR="$(dirname "$(readlink -f "$0")")"
    env="$HOME_DIR/.env"
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
        echo "LOG DOES NOT EXIST IN $tmp/.env. Will send output to $tmp/jrnl.log instead."
        LOG="$tmp/jrnl.log"
    fi
}

prepare_true_command() {
    if [[ ! -f "$TRUE_JRNL" ]]; then echo "$TRUE_JRNL DOES NOT EXIST."; exit 1; fi
    if [[ ! -f "$CONFIG_FILE_PATH" ]]; then echo "CONFIG FILE $CONFIG_FILE_PATH DOES NOT EXIST. Create or update in .env"; exit 2; fi
    if [[ ! -n "$DEFAULT_JOURNAL"  ]]; then echo "NO DEFAULT JOURNAL DEFINED IN .env"; fi

    journal=$(get_journal)
    JRNL="$TRUE_JRNL $journal --config-file $CONFIG_FILE_PATH"
    echo "$JRNL" >> "$LOG"
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
            acad*) warn "Academic journal selected." ;;
            work)  warn "Work journal selected." ;;
            flex*) warn "CST8319 project journal selected." ;;
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

# sub-command, PUT IN ITS OWN SCRIPT TODO:
jrnl_write() {
    case "$1" in
        '') new_entry_with_no_editor ;;
        *) echo "jrnl-write: I don't know what to do with $1 yet" ;;
    esac
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

new_entry_with_no_editor() {
    context selected
    journal=$(get_journal)
    $JRNL --config-override editor ""
    exit "$?"
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

show_today_jrnl() {
    warn "Today's entries:"
    view_journal_today
    warn "To start writing, do jrnl -w"
    exit 0
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

get_pager() {
    if [ -f '/bin/bat' ]; then
        echo 'bat -p'
    else
        echo 'less -R'
    fi
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
