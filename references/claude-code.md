# Claude Code Integration

## What Works Today

The coordinator repository already contains the execution scripts:

- `scripts/init_board.sh`
- `scripts/dispatch_worker.sh`
- `scripts/status.py`
- `scripts/attach_worker.sh`

Claude Code can run these scripts directly.

## Supported Path

Recommended bootstrap:

```bash
/home/zhimin/.codex/skills/claude-code-coordinator/scripts/bootstrap_install.sh
```

This installs:

- global Codex skill
- global Claude Code skill / alias

After that, start a Claude Code session in the target repo, ideally with `fable` or `opus` for the coordinator.

The installed global slash commands let you invoke the workflow directly from Claude Code TUI:

- `/cc_coord`
- `/claude-code-coordinator`

This path deliberately avoids writing `CLAUDE.md` or `.claude/commands/` into the target repo.

## Recommended Claude Code Usage

- Coordinator session: `fable` by default
- Strong review / hard debugging: `opus`
- Narrow execution workers: `deepseek`

Suggested bootstrap prompt to the coordinator session:

```text
Act as the coordinator, break down my request into worker tasks, dispatch them with background sessions, and monitor them through the .coord board.
```

Equivalent TUI usage after installation:

```text
/cc_coord fix the failing auth tests
/claude-code-coordinator audit the current pipeline and dispatch workers
```
