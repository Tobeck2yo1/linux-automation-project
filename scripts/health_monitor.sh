#!/usr/bin/env bash

set -e
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIBRARY_FILE="$PROJECT_ROOT/lib/common.sh"
LOG_DIRECTORY="$PROJECT_ROOT/logs"

if [[ ! -f "$LIBRARY_FILE" ]]; then
    printf '[ERROR] Function library not found: %s\n' "$LIBRARY_FILE" >&2
    exit 1
fi

source "$LIBRARY_FILE"

DISK_THRESHOLD="${1:-80}"
MEMORY_THRESHOLD="${2:-80}"
CPU_THRESHOLD="${3:-80}"

TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="$LOG_DIRECTORY/health_${TIMESTAMP}.log"
TEMP_FILE=""

cleanup() {
    local exit_code=$?

    if [[ -n "$TEMP_FILE" && -f "$TEMP_FILE" ]]; then
        rm -f "$TEMP_FILE"
    fi

    if (( exit_code == 0 )); then
        log_success "Health monitor completed successfully."
    else
        log_error "Health monitor detected a problem or failed."
    fi
}

trap cleanup EXIT
trap 'log_warning "Health monitor interrupted."; exit 130' INT TERM

check_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        log_error "Required command is not installed: $command_name"
        return 1
    fi
}

get_disk_usage() {
    df -P / | awk 'NR == 2 {gsub("%", "", $5); print $5}'
}

get_memory_usage() {
    free | awk '
        /^Mem:/ {
            if ($2 == 0) {
                print 0
            } else {
                printf "%.0f", ($3 / $2) * 100
            }
        }
    '
}

get_cpu_usage() {
    ps -eo pcpu= | awk '
        {
            total += $1
        }
        END {
            printf "%.0f", total
        }
    '
}

check_threshold() {
    local resource_name="$1"
    local current_usage="$2"
    local threshold="$3"

    if (( current_usage >= threshold )); then
        echo "WARNING: $resource_name usage is ${current_usage}%."
        echo "Threshold: ${threshold}%."
        return 1
    else
        echo "OK: $resource_name usage is ${current_usage}%."
        echo "Threshold: ${threshold}%."
        return 0
    fi
}

main() {
    validate_number "$DISK_THRESHOLD" "Disk threshold"
    validate_number "$MEMORY_THRESHOLD" "Memory threshold"
    validate_number "$CPU_THRESHOLD" "CPU threshold"

    check_command df
    check_command free
    check_command ps
    check_command awk

    mkdir -p "$LOG_DIRECTORY"
    TEMP_FILE="$(mktemp)"

    local disk_usage
    local memory_usage
    local cpu_usage
    local hostname_value
    local kernel_version
    local uptime_value
    local overall_status=0

    disk_usage="$(get_disk_usage)"
    memory_usage="$(get_memory_usage)"
    cpu_usage="$(get_cpu_usage)"
    hostname_value="$(hostname)"
    kernel_version="$(uname -r)"
    uptime_value="$(uptime -p 2>/dev/null || uptime)"

    {
        echo "System Health Report"
        echo "===================="
        echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Hostname: $hostname_value"
        echo "Kernel: $kernel_version"
        echo "Uptime: $uptime_value"
        echo

        check_threshold "Disk" "$disk_usage" "$DISK_THRESHOLD"
        disk_status=$?

        echo

        check_threshold "Memory" "$memory_usage" "$MEMORY_THRESHOLD"
        memory_status=$?

        echo

        check_threshold "CPU" "$cpu_usage" "$CPU_THRESHOLD"
        cpu_status=$?

        echo
        echo "Top five processes by memory usage:"
        ps -eo pid,user,%cpu,%mem,comm --sort=-%mem | head -n 6

        if (( disk_status != 0 || memory_status != 0 || cpu_status != 0 )); then
            overall_status=1
            echo
            echo "Overall status: WARNING"
        else
            echo
            echo "Overall status: HEALTHY"
        fi
    } > "$TEMP_FILE" || overall_status=1

    mv "$TEMP_FILE" "$LOG_FILE"
    TEMP_FILE=""

    cat "$LOG_FILE"
    echo
    log_info "Health report saved to: $LOG_FILE"

    if (( overall_status == 0 )); then
        return 0
    fi

    return 1
}

set +e
main "$@"
script_status=$?
set -e

if (( script_status == 0 )); then
    log_success "Exit code $script_status: all checks passed."
else
    log_warning "Exit code $script_status: one or more thresholds were exceeded."
fi

exit "$script_status"
