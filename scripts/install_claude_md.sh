#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  install_claude_md.sh

This installer is deprecated.
Use bootstrap_install.sh instead.
EOF
}

usage
echo >&2
echo "Refusing to write CLAUDE.md or .claude/commands into the target repo." >&2
echo "Use: ~/.codex/skills/claude-code-coordinator/scripts/bootstrap_install.sh" >&2
exit 1
