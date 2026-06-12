---
name: claude-code-coordinator
description: Coordinate Claude Code background sessions as a multi-agent execution layer. Use when Codex should decompose work, dispatch parallel Claude Code workers with `claude --bg`, monitor them with `claude agents --json` and `claude logs`, expose status in tmux, and take over a worker with `claude attach`. Best for repo-scoped execution workflows that need isolation, supervision, and human takeover rather than raw tmux input injection.
---

# Claude Code Coordinator

Use Claude Code background sessions as workers, tmux as the operator dashboard, and Codex as the scheduler.

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
   - tmux window `agents`
   - tmux window `coordinator`
   - tmux worker windows created by `dispatch_worker.sh`
   - `scripts/status.py --repo /path/to/repo --all`
6. Take over any worker with `claude attach <id>`.

## Operating Rules

- Treat Codex as the only scheduler.
- Use Claude Code background sessions as the execution layer.
- Use tmux for observation and manual takeover, not as the primary control plane.
- Isolate concurrent edits with git worktrees or Claude Code worktree isolation.
- Give each worker a narrow file boundary, explicit acceptance criteria, and a concrete stop condition.
- Review worker diffs and run targeted verification before merging or reporting success.

## Workflow

1. Read the user request and break it into independent worker tasks.
2. Initialize the coordination board for the target repo if it does not exist.
3. Write one prompt file per worker under `.coord/prompts/`.
4. Dispatch each worker with `scripts/dispatch_worker.sh`.
5. Poll `claude agents --json` and inspect `claude logs <id>` when a worker stalls, asks for help, or completes.
6. Use `claude attach <id>` only when manual takeover is necessary.
7. Review worker output with `git status`, `git diff`, and focused tests.
8. Close or stop finished sessions and keep `.coord/workers.tsv` current.

## Scripts

- `scripts/init_board.sh`
  Create `.coord/`, seed tracker files, and create a tmux session with `agents` and `coordinator` windows.
- `scripts/dispatch_worker.sh`
  Launch a background Claude Code worker, record its session ID, append coordinator logs, and create a tmux watch window.
- `scripts/watch_worker.sh`
  Continuously refresh `claude logs <id>` in a tmux window.
- `scripts/status.py`
  Merge `.coord/workers.tsv` with `claude agents --json` and print a concise status table.

## References

- `references/workflow.md`
  Detailed operating model, dashboard layout, prompt template, and compatibility notes.

## Prompting Guidance

- Use stronger structure for weaker models: explicit read-first files, boundaries, acceptance criteria, and forbidden actions.
- Give stronger models shorter but still testable goals.
- Separate task execution from review. Use different workers when the risk justifies it.

## Compatibility

- If `claude --bg` is unavailable on the local machine, do not use the automation scripts blindly.
- Prefer upgrading Claude Code first.
- Only fall back to tmux-driven interactive orchestration when background sessions are genuinely unavailable.
