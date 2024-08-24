#!/bin/bash

# should I define default log here!

log() { 
    if [[ -z "$LOG" ]]; then >&2 echo "$0: define \$LOG before using me!"; exit 1; fi
    echo "$@" >> "$LOG";
}
