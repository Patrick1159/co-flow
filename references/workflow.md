# Claude Code Coordinator Workflow

## Purpose

Use this skill when Codex should coordinate Claude Code workers instead of doing all work in one foreground terminal.

If the coordinator is a Claude Code session rather than Codex, use the globally installed skill or global slash commands. Do not write coordinator instruction files into the target repository.

After installation, Claude Code TUI can enter the workflow through either slash command:

- `/cc_coord`
- `/claude-code-coordinator`

This skill assumes:

- Codex is the scheduler.
- Claude Code background sessions are the workers.
- tmux is the pure-text observation and takeover surface.
- A target git repo exists.

## Coordination Layout

Use a repo-local `.coord/` directory:

```text
.coord/
  coordinator.log
  workers.tsv
  prompts/
  logs/
```

- `coordinator.log`
  Scheduler decisions, dispatch outputs, and review summaries.
- `workers.tsv`
  Worker registry. One row per dispatched worker.
- `prompts/`
  Prompt files written before dispatch.
- `logs/`
  Optional captured launcher output and helper artifacts.

## Tmux Dashboard

Recommended session layout:

```text
cc-board
  0: dashboard
  1: coordinator
  2..N: one log tail window per worker
```

`dashboard` window:

```bash
python scripts/status.py --repo <repo> --watch --all
```

It should show, in plain text:

- worker `id`
- `name`
- `model`
- `status`
- current `task`
- a ready-to-run `claude attach <id>` command
- a footer with common operator commands

Recommended footer commands:

```bash
claude attach <id>
claude agents --cwd <repo>
claude logs <id>
python3 scripts/status.py --repo <repo> --all
tail -f <repo>/.coord/coordinator.log
tail -f <repo>/.coord/logs/<worker>.log
```

`coordinator` window:

```bash
tail -f <repo>/.coord/coordinator.log
```

Worker log windows:

```bash
tail -f .coord/logs/<worker>.log
```

Do not keep `claude agents` TUI running as a permanent dashboard window. It is useful for occasional interactive inspection, but it is noisy and unstable when several tmux panes constantly redraw.

Use light ANSI color, section dividers, and fixed-width columns in the dashboard to keep the board readable without turning it back into an interactive TUI.

## Dispatch Pattern

1. Write the worker prompt to `.coord/prompts/<task>.md`.
2. Launch the worker with:

```bash
claude --bg --dangerously-skip-permissions --name "<name>" "<prompt>"
```

3. Parse the returned session ID.
4. Append the worker record to `.coord/workers.tsv`.
5. Create a tmux log tail window for `.coord/logs/<worker>.log`.

## Worker Record Format

`workers.tsv` should stay machine-readable and directly useful for humans:

```text
session_id	name	repo	model	agent	status	task	prompt_file	log_file	last_update
23f01141	auth-fix	/path/to/repo	fable	coder	running	Fix auth tests	/path/to/repo/.coord/prompts/auth-fix.md	/path/to/repo/.coord/logs/auth-fix.log	2026-06-12 15:20:00
```

Keep the header row.

## Review Loop

Use this control loop:

1. `claude agents --json --all --cwd <repo>`
2. `claude logs <id>`
3. `git -C <repo> status --short`
4. `git -C <repo> diff`
5. Targeted tests

Then decide:

- `running`
  Keep watching.
- `needs_input`
  Inspect `.coord/logs/<worker>.log` and either reply or attach.
- `completed`
  Review diff and verify.
- `failed`
  Summarize the blocker and decide whether to re-dispatch.

In the default board, `scripts/status.py --watch` performs the polling and log capture loop. It updates:

- `.coord/workers.tsv`
- `.coord/logs/<worker>.log`

## Prompt Template

Use a prompt with these fields:

```text
You are a Claude Code worker.

Task:
<goal>

Repo:
<repo>

Read first:
- <file 1>
- <file 2>

Constraints:
- <boundary 1>
- <boundary 2>

Acceptance:
- <check 1>
- <check 2>

Deliver:
- changed files
- commands run
- results
- residual risks
```

Keep prompts narrow. Do not ask one worker to both implement and broadly rethink the product unless that is the actual task.

## Permissions

Default to `--dangerously-skip-permissions` for dispatched workers so background sessions do not block on edit or shell approvals.

Only override this default when:

- the repo or machine requires stricter controls, or
- the task is risky enough that interactive approvals are part of the intended workflow.

## Isolation

Prefer one of these:

- Claude Code's repo-local worktree isolation
- Explicit `git worktree`
- Explicit narrow file boundaries in the prompt

Do not let multiple workers edit the same files without a reasoned merge plan.

## TUI Policy

Do not run multiple Claude Code TUI panes permanently inside `cc-board`.

Avoid these as always-on board panes:

- `claude agents`
- `claude logs <id>` in a full-screen redraw loop
- `claude attach <id>`

Use them only when needed:

- `claude agents`
  Occasional interactive inspection
- `claude attach <id>`
  Temporary human takeover

For normal operation, keep the board pure-text and let Codex maintain the state files.

## Compatibility Notes

Check local support before relying on automation:

```bash
claude logs --help
claude attach --help
claude agents --json --cwd <repo>
claude --bg "test"
```

If `claude --bg` succeeds, stop the probe session afterwards:

```bash
claude stop <id>
```

If the local Claude Code build lacks `--bg`, treat this skill as a design guide and downgrade to manual orchestration rather than pretending automation exists.
