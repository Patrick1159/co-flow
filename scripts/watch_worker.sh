#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  watch_worker.sh --log-file <path> [--name <worker-name>] [--id <session-id>] [--lines <n>] \
      [--workers-file <path>] [--poll-interval <seconds>]
EOF
}

LOG_FILE=""
NAME=""
SESSION_ID=""
LINES="200"
WORKERS_FILE=""
POLL_INTERVAL="2"

is_terminal_status() {
    case "${1:-}" in
        stopped|completed|done|failed|error)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

read_worker_status() {
    if [ -z "$WORKERS_FILE" ] || [ ! -f "$WORKERS_FILE" ] || [ -z "$SESSION_ID" ]; then
        return 0
    fi
    awk -F '\t' -v id="$SESSION_ID" 'NR > 1 && $1 == id { print $6; exit }' "$WORKERS_FILE"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --log-file)
            LOG_FILE="${2:-}"
            shift 2
            ;;
        --name)
            NAME="${2:-}"
            shift 2
            ;;
        --id)
            SESSION_ID="${2:-}"
            shift 2
            ;;
        --lines)
            LINES="${2:-}"
            shift 2
            ;;
        --workers-file)
            WORKERS_FILE="${2:-}"
            shift 2
            ;;
        --poll-interval)
            POLL_INTERVAL="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage
            exit 1
            ;;
    esac
done

if [ -z "$LOG_FILE" ]; then
    echo "Missing --log-file" >&2
    usage
    exit 1
fi

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

if [ -n "$NAME" ] || [ -n "$SESSION_ID" ]; then
    echo "worker: ${NAME:--}"
    echo "id: ${SESSION_ID:--}"
    echo "log: $LOG_FILE"
    [ -n "$WORKERS_FILE" ] && echo "workers: $WORKERS_FILE"
    echo
fi

tail -n "$LINES" -f "$LOG_FILE" &
TAIL_PID=$!

cleanup() {
    kill "$TAIL_PID" 2>/dev/null || true
    wait "$TAIL_PID" 2>/dev/null || true
}

trap cleanup EXIT INT TERM

while kill -0 "$TAIL_PID" 2>/dev/null; do
    STATUS="$(read_worker_status || true)"
    if [ -n "$STATUS" ] && is_terminal_status "$STATUS"; then
        printf '\n[watcher] releasing window: session %s is %s\n' "${SESSION_ID:--}" "$STATUS"
        break
    fi
    sleep "$POLL_INTERVAL"
done
