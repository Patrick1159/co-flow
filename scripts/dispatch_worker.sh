#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  dispatch_worker.sh --repo <repo-path> --name <worker-name> --prompt-file <file> \
      [--session <tmux-session>] [--coord-dir <dir>] [--model <model>] [--agent <agent>] \
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
mkdir -p "$COORD_PATH/prompts" "$COORD_PATH/logs"
touch "$COORD_PATH/coordinator.log"
if [ ! -f "$COORD_PATH/workers.tsv" ]; then
    printf 'session_id\tname\trepo\tmodel\tagent\tstatus\tprompt_file\n' > "$COORD_PATH/workers.tsv"
fi

PROMPT="$(cat "$PROMPT_FILE")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

CLAUDE_ARGS=(--bg --name "$NAME")
[ -n "$MODEL" ] && CLAUDE_ARGS+=(--model "$MODEL")
[ -n "$AGENT" ] && CLAUDE_ARGS+=(--agent "$AGENT")
[ -n "$PERMISSION_MODE" ] && CLAUDE_ARGS+=(--permission-mode "$PERMISSION_MODE")
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

printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$SESSION_ID" "$NAME" "$REPO" "${MODEL:-}" "${AGENT:-}" "launched" "$PROMPT_FILE" >> "$COORD_PATH/workers.tsv"

if [ "$WATCH" = "true" ] && tmux has-session -t "$SESSION" 2>/dev/null; then
    tmux new-window -t "$SESSION" -n "$NAME" \
        "$(printf '%q' "$SCRIPT_DIR/watch_worker.sh") --repo $(printf '%q' "$REPO") --id $(printf '%q' "$SESSION_ID") --name $(printf '%q' "$NAME")"
fi

echo "session_id=$SESSION_ID"
echo "name=$NAME"
