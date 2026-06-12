#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  watch_worker.sh --repo <repo-path> --id <session-id> --name <worker-name> [--interval <seconds>]
EOF
}

REPO=""
SESSION_ID=""
NAME=""
INTERVAL="3"

while [ $# -gt 0 ]; do
    case "$1" in
        --repo)
            REPO="${2:-}"
            shift 2
            ;;
        --id)
            SESSION_ID="${2:-}"
            shift 2
            ;;
        --name)
            NAME="${2:-}"
            shift 2
            ;;
        --interval)
            INTERVAL="${2:-}"
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

if [ -z "$REPO" ] || [ -z "$SESSION_ID" ] || [ -z "$NAME" ]; then
    echo "Missing required arguments" >&2
    usage
    exit 1
fi

cd "$REPO"

while true; do
    clear
    date
    echo "worker: $NAME"
    echo "id: $SESSION_ID"
    echo "repo: $REPO"
    echo
    claude logs "$SESSION_ID" || true
    sleep "$INTERVAL"
done
