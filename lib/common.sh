#!/usr/bin/env bash

# Shared functions used by the project scripts.

log_info() {
    local message="$1"
    printf '[INFO] %s\n' "$message"
}

log_success() {
    local message="$1"
    printf '[SUCCESS] %s\n' "$message"
}

log_warning() {
    local message="$1"
    printf '[WARNING] %s\n' "$message"
}

log_error() {
    local message="$1"
    printf '[ERROR] %s\n' "$message" >&2
}

validate_directory() {
    local directory="$1"

    if [[ -z "$directory" ]]; then
        log_error "A directory path is required."
        return 1
    fi

    if [[ "$directory" == "/" ]]; then
        log_error "The root directory cannot be used as the project output path."
        return 1
    fi

    if [[ -e "$directory" && ! -d "$directory" ]]; then
        log_error "'$directory' exists but is not a directory."
        return 1
    fi

    return 0
}

validate_number() {
    local value="$1"
    local name="$2"

    if [[ ! "$value" =~ ^[0-9]+$ ]]; then
        log_error "$name must be a whole number."
        return 1
    fi

    if (( value < 0 || value > 100 )); then
        log_error "$name must be between 0 and 100."
        return 1
    fi

    return 0
}
