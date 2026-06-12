---
name: claude-code-coordinator
description: Coordinate Claude Code background sessions as a multi-agent execution layer. Use when Codex should decompose work, dispatch parallel Claude Code workers with `claude --bg`, monitor them with `claude agents --json` and `claude logs`, expose status in tmux, and take over a worker with `claude attach`. Best for repo-scoped execution workflows that need isolation, supervision, and human takeover rather than raw tmux input injection.
---

# Claude Code Coordinator

Use Claude Code background sessions as workers, tmux as a pure-text operator dashboard, and Codex as the scheduler.

Prefer this skill over tmux `send-keys` orchestration when the machine's Claude Code version supports:

- `claude --bg`
- `claude agents --json`
- `claude logs <id>`
- `claude attach <id>`

## Quick Start

1. Verify local support:
   - `claude logs --help`
   - `claude attach --help`
   - `claude agents --json --cwd <repo>`
   - `claude --bg "test"` and then `claude stop <id>`
2. Initialize the repo-local coordination area and tmux dashboard:
   - `scripts/init_board.sh --repo /path/to/repo`
3. Write each worker prompt into `<repo>/.coord/prompts/<task>.md`.
4. Dispatch workers with `scripts/dispatch_worker.sh`.
5. Monitor with:
   - tmux window `dashboard`
   - tmux window `coordinator`
   - tmux worker log windows created by `dispatch_worker.sh`
   - `scripts/status.py --repo /path/to/repo --all`
6. Take over any worker with `claude attach <id>` or `scripts/attach_worker.sh`.

## Operating Rules

- Treat Codex as the only scheduler.
- Use Claude Code background sessions as the execution layer.
- Dispatch workers with `--dangerously-skip-permissions` by default so they do not stall on permission prompts.
- Do not keep multiple Claude Code TUI views running in tmux as a permanent board.
- Use tmux for pure-text observation and manual takeover, not as the primary control plane.
- Isolate concurrent edits with git worktrees or Claude Code worktree isolation.
- Give each worker a narrow file boundary, explicit acceptance criteria, and a concrete stop condition.
- Review worker diffs and run targeted verification before merging or reporting success.

## Workflow

1. Read the user request and break it into independent worker tasks.
2. Initialize the coordination board for the target repo if it does not exist.
3. Write one prompt file per worker under `.coord/prompts/`.
4. Dispatch each worker with `scripts/dispatch_worker.sh`.
   - Default behavior uses `claude --bg --dangerously-skip-permissions`.
   - Override with `--permission-mode <mode>` only when a safer permission model is explicitly required.
5. Let `scripts/status.py --watch` maintain `.coord/workers.tsv` and `.coord/logs/*.log` from `claude agents --json --all` and `claude logs <id>`.
   - The dashboard should keep each worker's `id`, `name`, `model`, `status`, and `task` directly visible.
   - Show a plain `claude attach <id>` command for each worker so takeover is immediate.
6. Watch tmux pure-text windows rather than permanent Claude Code TUI panes.
7. Use `claude attach <id>` only when manual takeover is necessary.
8. Review worker output with `git status`, `git diff`, and focused tests.
9. Close or stop finished sessions and keep `.coord/workers.tsv` current.

## Scripts

- `scripts/init_board.sh`
  Create `.coord/`, seed tracker files, and create a tmux session with `dashboard` and `coordinator` windows.
- `scripts/dispatch_worker.sh`
  Launch a background Claude Code worker, record its session ID, append coordinator logs, and create a tmux log tail window.
- `scripts/watch_worker.sh`
  Tail a worker's plain-text `.coord/logs/<worker>.log` file in a tmux window.
- `scripts/status.py`
  Merge `.coord/workers.tsv` with `claude agents --json --all`, write worker log snapshots into `.coord/logs/`, and print a concise status table.
- `scripts/attach_worker.sh`
  Resolve a worker by name or ID and run `claude attach`.
- `scripts/install_claude_md.sh`
  Deprecated shim that refuses repo-local CLAUDE.md installation to avoid polluting target repositories.
- `scripts/bootstrap_install.sh`
  Install the Codex skill and the Claude Code global skill/aliases in one step.

## References

- `references/workflow.md`
  Detailed operating model, board layout, prompt template, and compatibility notes.
- `references/claude-code.md`
  Gap analysis and the supported path for using the coordinator workflow from a Claude Code session.

## Prompting Guidance

- Use stronger structure for weaker models: explicit read-first files, boundaries, acceptance criteria, and forbidden actions.
- Give stronger models shorter but still testable goals.
- Separate task execution from review. Use different workers when the risk justifies it.

## Compatibility

- If `claude --bg` is unavailable on the local machine, do not use the automation scripts blindly.
- Prefer upgrading Claude Code first.
- Only fall back to tmux-driven interactive orchestration when background sessions are genuinely unavailable.
- Do not treat `claude agents` TUI as the stable dashboard; reserve it for occasional inspection only.
