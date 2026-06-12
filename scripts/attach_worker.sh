#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  attach_worker.sh --repo <repo-path> (--id <session-id> | --name <worker-name>) [--coord-dir <dir>]
EOF
}

REPO=""
SESSION_ID=""
NAME=""
COORD_DIR=".coord"

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
        --coord-dir)
            COORD_DIR="${2:-}"
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

if [ -z "$REPO" ] || { [ -z "$SESSION_ID" ] && [ -z "$NAME" ]; }; then
    echo "Missing required arguments" >&2
    usage
    exit 1
fi

REPO="$(cd "$REPO" && pwd)"
WORKERS="$REPO/$COORD_DIR/workers.tsv"

if [ -z "$SESSION_ID" ]; then
    SESSION_ID="$(awk -F '\t' -v name="$NAME" 'NR > 1 && $2 == name { print $1; exit }' "$WORKERS")"
fi

if [ -z "$SESSION_ID" ]; then
    echo "Worker session not found" >&2
    exit 1
fi

cd "$REPO"
exec claude attach "$SESSION_ID"
