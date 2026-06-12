#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  init_board.sh --repo <repo-path> [--session <tmux-session>] [--coord-dir <dir>] [--interval <seconds>]

Example:
  init_board.sh --repo /path/to/repo --session cc-board
EOF
}

REPO=""
SESSION="cc-board"
COORD_DIR=".coord"
INTERVAL="3"

while [ $# -gt 0 ]; do
    case "$1" in
        --repo)
            REPO="${2:-}"
            shift 2
            ;;
        --session)
            SESSION="${2:-}"
            shift 2
            ;;
        --coord-dir)
            COORD_DIR="${2:-}"
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

if [ -z "$REPO" ]; then
    echo "Missing --repo" >&2
    usage
    exit 1
fi

REPO="$(cd "$REPO" && pwd)"
COORD_PATH="$REPO/$COORD_DIR"
mkdir -p "$COORD_PATH/prompts" "$COORD_PATH/logs" "$COORD_PATH/cache"
touch "$COORD_PATH/coordinator.log"

if [ ! -f "$COORD_PATH/workers.tsv" ]; then
    printf 'session_id\tname\trepo\tmodel\tagent\tstatus\ttask\tprompt_file\tlog_file\tlast_update\n' > "$COORD_PATH/workers.tsv"
fi

if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "tmux session already exists: $SESSION"
    echo "coord dir: $COORD_PATH"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

tmux new-session -d -s "$SESSION" -n dashboard \
    "zsh -lc 'cd $(printf '%q' "$REPO") && python3 $(printf '%q' "$SCRIPT_DIR/status.py") --repo $(printf '%q' "$REPO") --watch --all --interval $(printf '%q' "$INTERVAL"); exec zsh'"

tmux new-window -t "$SESSION" -n coordinator \
    "zsh -lc 'cd $(printf '%q' "$REPO") && tail -f $(printf '%q' "$COORD_PATH/coordinator.log"); exec zsh'"

echo "created tmux session: $SESSION"
echo "repo: $REPO"
echo "coord dir: $COORD_PATH"
