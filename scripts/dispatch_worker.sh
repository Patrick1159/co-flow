#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  dispatch_worker.sh --repo <repo-path> --name <worker-name> --prompt-file <file> \
      [--session <tmux-session>] [--coord-dir <dir>] [--model <model>] [--agent <agent>] [--task <text>] \
      [--permission-mode <mode>] [--worktree <name>] [--no-watch]

Example:
  dispatch_worker.sh \
      --repo /path/to/repo \
      --name auth-fix \
      --prompt-file /path/to/repo/.coord/prompts/auth-fix.md \
      --model fable
EOF
}

REPO=""
NAME=""
PROMPT_FILE=""
SESSION="cc-board"
COORD_DIR=".coord"
MODEL=""
AGENT=""
TASK=""
PERMISSION_MODE=""
WORKTREE=""
WATCH="true"

while [ $# -gt 0 ]; do
    case "$1" in
        --repo)
            REPO="${2:-}"
            shift 2
            ;;
        --name)
            NAME="${2:-}"
            shift 2
            ;;
        --prompt-file)
            PROMPT_FILE="${2:-}"
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
        --model)
            MODEL="${2:-}"
            shift 2
            ;;
        --agent)
            AGENT="${2:-}"
            shift 2
            ;;
        --task)
            TASK="${2:-}"
            shift 2
            ;;
        --permission-mode)
            PERMISSION_MODE="${2:-}"
            shift 2
            ;;
        --worktree)
            WORKTREE="${2:-}"
            shift 2
            ;;
        --no-watch)
            WATCH="false"
            shift 1
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

if [ -z "$REPO" ] || [ -z "$NAME" ] || [ -z "$PROMPT_FILE" ]; then
    echo "Missing required arguments" >&2
    usage
    exit 1
fi

REPO="$(cd "$REPO" && pwd)"
PROMPT_FILE="$(cd "$(dirname "$PROMPT_FILE")" && pwd)/$(basename "$PROMPT_FILE")"

if [ ! -f "$PROMPT_FILE" ]; then
    echo "Prompt file not found: $PROMPT_FILE" >&2
    exit 1
fi

COORD_PATH="$REPO/$COORD_DIR"
mkdir -p "$COORD_PATH/prompts" "$COORD_PATH/logs" "$COORD_PATH/cache"
touch "$COORD_PATH/coordinator.log"
if [ ! -f "$COORD_PATH/workers.tsv" ]; then
    printf 'session_id\tname\trepo\tmodel\tagent\tstatus\ttask\tprompt_file\tlog_file\tlast_update\n' > "$COORD_PATH/workers.tsv"
fi

PROMPT="$(cat "$PROMPT_FILE")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

extract_task() {
    local prompt_file="$1"
    awk '
        BEGIN { in_task = 0 }
        /^Task:[[:space:]]*$/ { in_task = 1; next }
        in_task && NF { print; exit }
        !in_task && NF && $0 !~ /^You are/ { print; exit }
    ' "$prompt_file"
}

if [ -z "$TASK" ]; then
    TASK="$(extract_task "$PROMPT_FILE")"
fi
[ -n "$TASK" ] || TASK="$NAME"

LOG_FILE="$COORD_PATH/logs/${NAME}.log"
WORKERS_FILE="$COORD_PATH/workers.tsv"
touch "$LOG_FILE"

CLAUDE_ARGS=(--bg --name "$NAME")
[ -n "$MODEL" ] && CLAUDE_ARGS+=(--model "$MODEL")
[ -n "$AGENT" ] && CLAUDE_ARGS+=(--agent "$AGENT")
if [ -n "$PERMISSION_MODE" ]; then
    CLAUDE_ARGS+=(--permission-mode "$PERMISSION_MODE")
else
    CLAUDE_ARGS+=(--dangerously-skip-permissions)
fi
[ -n "$WORKTREE" ] && CLAUDE_ARGS+=(--worktree "$WORKTREE")

OUT="$(
    cd "$REPO"
    claude "${CLAUDE_ARGS[@]}" "$PROMPT"
)"

printf '%s\n' "$OUT" | tee -a "$COORD_PATH/coordinator.log" > "$COORD_PATH/logs/${NAME}.launch.log"

SESSION_ID="$(printf '%s\n' "$OUT" | awk '/backgrounded/ {print $3; exit}')"
if [ -z "$SESSION_ID" ]; then
    echo "Failed to parse session ID from claude output" >&2
    exit 1
fi

printf '[%s] launched %s (%s) task=%s\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" "$NAME" "$SESSION_ID" "$TASK" >> "$COORD_PATH/coordinator.log"

printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$SESSION_ID" "$NAME" "$REPO" "${MODEL:-}" "${AGENT:-}" "launched" "$TASK" "$PROMPT_FILE" "$LOG_FILE" "$(date '+%Y-%m-%d %H:%M:%S')" >> "$COORD_PATH/workers.tsv"

if [ "$WATCH" = "true" ] && tmux has-session -t "$SESSION" 2>/dev/null; then
    WATCH_CMD="cd $(printf '%q' "$REPO") && bash $(printf '%q' "$SCRIPT_DIR/watch_worker.sh") --log-file $(printf '%q' "$LOG_FILE") --workers-file $(printf '%q' "$WORKERS_FILE") --id $(printf '%q' "$SESSION_ID") --name $(printf '%q' "$NAME")"
    tmux new-window -d -t "$SESSION:" -n "${NAME}-log" \
        "zsh -lc $(printf '%q' "$WATCH_CMD")"
fi

echo "session_id=$SESSION_ID"
echo "name=$NAME"
