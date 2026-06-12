#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  bootstrap_install.sh [--force]

Examples:
  bootstrap_install.sh

Behavior:
  - Installs the global Codex skill under $CODEX_HOME/skills or ~/.codex/skills
  - Installs the global Claude Code skill under $CLAUDE_HOME/skills or ~/.claude/skills
  - Installs global Claude Code commands /cc_coord and /claude-code-coordinator under $CLAUDE_HOME/commands
EOF
}

FORCE="false"

while [ $# -gt 0 ]; do
    case "$1" in
        --force)
            FORCE="true"
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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_NAME="claude-code-coordinator"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
CLAUDE_HOME_DIR="${CLAUDE_HOME:-$HOME/.claude}"
CODEX_SKILLS_DIR="$CODEX_HOME_DIR/skills"
CLAUDE_SKILLS_DIR="$CLAUDE_HOME_DIR/skills"
CLAUDE_COMMANDS_DIR="$CLAUDE_HOME_DIR/commands"
CODEX_TARGET="$CODEX_SKILLS_DIR/$SKILL_NAME"
CLAUDE_SKILL_TARGET="$CLAUDE_SKILLS_DIR/$SKILL_NAME"
CLAUDE_GLOBAL_ALIAS_TARGET="$CLAUDE_COMMANDS_DIR/cc_coord.md"
CLAUDE_GLOBAL_LONG_COMMAND_TARGET="$CLAUDE_COMMANDS_DIR/claude-code-coordinator.md"
CLAUDE_GLOBAL_SKILL_TEMPLATE="$SKILL_DIR/assets/claude_global_skill.SKILL.md.template"
CLAUDE_GLOBAL_ALIAS_TEMPLATE="$SKILL_DIR/assets/cc_coord.md.template"
CLAUDE_GLOBAL_LONG_COMMAND_TEMPLATE="$SKILL_DIR/assets/claude-code-coordinator-command.md.template"

mkdir -p "$CODEX_SKILLS_DIR" "$CLAUDE_SKILLS_DIR" "$CLAUDE_COMMANDS_DIR"

install_symlink() {
    local source="$1"
    local target="$2"
    local source_real=""
    local target_real=""

    source_real="$(cd "$source" && pwd -P)"
    if [ -e "$target" ] || [ -L "$target" ]; then
        target_real="$(cd "$(dirname "$target")" && pwd -P)/$(basename "$target")"
        if [ -d "$target" ]; then
            target_real="$(cd "$target" && pwd -P)"
        elif [ -L "$target" ]; then
            target_real="$(cd "$(dirname "$target")" && cd "$(dirname "$(readlink "$target")")" 2>/dev/null && pwd -P)/$(basename "$(readlink "$target")")"
        fi
    fi

    if [ "$source_real" = "$target_real" ]; then
        echo "exists: $target"
        return 0
    fi

    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
        echo "exists: $target -> $source"
        return 0
    fi

    if [ -e "$target" ] || [ -L "$target" ]; then
        if [ "$FORCE" != "true" ]; then
            echo "Target already exists: $target" >&2
            echo "Use --force to replace it." >&2
            exit 1
        fi
        rm -rf "$target"
    fi

    ln -s "$source" "$target"
    echo "installed: $target -> $source"
}

install_from_template() {
    local template="$1"
    local target="$2"

    if [ -e "$target" ] && [ "$FORCE" != "true" ]; then
        echo "Target already exists: $target" >&2
        echo "Use --force to replace it." >&2
        exit 1
    fi

    mkdir -p "$(dirname "$target")"
    sed "s|__SKILL_DIR__|$SKILL_DIR|g" "$template" > "$target"
    echo "installed: $target"
}

if [ ! -f "$CLAUDE_GLOBAL_SKILL_TEMPLATE" ] || [ ! -f "$CLAUDE_GLOBAL_ALIAS_TEMPLATE" ] || [ ! -f "$CLAUDE_GLOBAL_LONG_COMMAND_TEMPLATE" ]; then
    echo "Missing bootstrap templates under $SKILL_DIR/assets" >&2
    exit 1
fi

install_symlink "$SKILL_DIR" "$CODEX_TARGET"
install_from_template "$CLAUDE_GLOBAL_SKILL_TEMPLATE" "$CLAUDE_SKILL_TARGET/SKILL.md"
install_from_template "$CLAUDE_GLOBAL_ALIAS_TEMPLATE" "$CLAUDE_GLOBAL_ALIAS_TARGET"
install_from_template "$CLAUDE_GLOBAL_LONG_COMMAND_TEMPLATE" "$CLAUDE_GLOBAL_LONG_COMMAND_TARGET"
