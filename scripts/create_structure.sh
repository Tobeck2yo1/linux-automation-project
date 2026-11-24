#!/usr/bin/env bash

set -e
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIBRARY_FILE="$PROJECT_ROOT/lib/common.sh"

if [[ ! -f "$LIBRARY_FILE" ]]; then
    printf '[ERROR] Function library not found: %s\n' "$LIBRARY_FILE" >&2
    exit 1
fi

# Load the shared function library.
source "$LIBRARY_FILE"

TARGET_DIRECTORY="${1:-$PROJECT_ROOT/output}"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
TEMP_FILE=""

cleanup() {
    local exit_code=$?

    if [[ -n "$TEMP_FILE" && -f "$TEMP_FILE" ]]; then
        rm -f "$TEMP_FILE"
        log_info "Temporary file removed."
    fi

    if (( exit_code != 0 )); then
        log_error "The directory creation script ended unexpectedly."
    fi
}

trap cleanup EXIT
trap 'log_warning "Script interrupted by the user."; exit 130' INT TERM

create_directory() {
    local directory="$1"

    if [[ -d "$directory" ]]; then
        log_info "Directory already exists: $directory"
    else
        mkdir -p "$directory"
        log_success "Created directory: $directory"
    fi
}

create_file_if_missing() {
    local file_path="$1"
    local content="$2"

    if [[ -f "$file_path" ]]; then
        log_info "File already exists and was not overwritten: $file_path"
    else
        touch "$file_path"
        echo "$content" > "$file_path"
        log_success "Created file: $file_path"
    fi
}

main() {
    validate_directory "$TARGET_DIRECTORY"

    create_directory "$TARGET_DIRECTORY"
    create_directory "$TARGET_DIRECTORY/config"
    create_directory "$TARGET_DIRECTORY/data/raw"
    create_directory "$TARGET_DIRECTORY/data/processed"
    create_directory "$TARGET_DIRECTORY/reports"

    create_file_if_missing \
        "$TARGET_DIRECTORY/config/application.conf" \
        "environment=development"

    create_file_if_missing \
        "$TARGET_DIRECTORY/data/raw/input.txt" \
        "Raw data created on $(date '+%Y-%m-%d %H:%M:%S')"

    create_file_if_missing \
        "$TARGET_DIRECTORY/data/processed/result.txt" \
        "No processed result is available yet."

    local report_file
    report_file="$TARGET_DIRECTORY/reports/report_${TIMESTAMP}.txt"

    TEMP_FILE="$(mktemp)"

    {
        echo "Automation Report"
        echo "================="
        echo "Created: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Target directory: $TARGET_DIRECTORY"
        echo "User: ${USER:-unknown}"
        echo "Hostname: $(hostname)"
    } > "$TEMP_FILE"

    mv "$TEMP_FILE" "$report_file"
    TEMP_FILE=""

    log_success "Timestamped report created: $report_file"
    log_success "Directory and file automation completed successfully."
}

main "$@"
