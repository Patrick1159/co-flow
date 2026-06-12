# Claude Code Coordinator Workflow

## Purpose

Use this skill when Codex should coordinate Claude Code workers instead of doing all work in one foreground terminal.

This skill assumes:

- Codex is the scheduler.
- Claude Code background sessions are the workers.
- tmux is the observation and takeover surface.
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
  0: agents
  1: coordinator
  2..N: one watch window per worker
```

`agents` window:

```bash
claude agents --cwd <repo>
```

`coordinator` window:

```bash
tail -f <repo>/.coord/coordinator.log
```

Worker watch windows:

```bash
claude logs <id>
```

wrapped in a small refresh loop.

## Dispatch Pattern

1. Write the worker prompt to `.coord/prompts/<task>.md`.
2. Launch the worker with:

```bash
claude --bg --name "<name>" "<prompt>"
```

3. Parse the returned session ID.
4. Append the worker record to `.coord/workers.tsv`.
5. Create a tmux watch window for `claude logs <id>`.

## Worker Record Format

`workers.tsv` should stay machine-readable:

```text
session_id	name	repo	model	agent	status	prompt_file
23f01141	auth-fix	/path/to/repo	fable	coder	launched	/path/to/repo/.coord/prompts/auth-fix.md
```

Keep the header row.

## Review Loop

Use this control loop:

1. `claude agents --json --cwd <repo>`
2. `claude logs <id>`
3. `git -C <repo> status --short`
4. `git -C <repo> diff`
5. Targeted tests

Then decide:

- `running`
  Keep watching.
- `needs_input`
  Inspect logs and either reply or attach.
- `completed`
  Review diff and verify.
- `failed`
  Summarize the blocker and decide whether to re-dispatch.

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

## Isolation

Prefer one of these:

- Claude Code's repo-local worktree isolation
- Explicit `git worktree`
- Explicit narrow file boundaries in the prompt

Do not let multiple workers edit the same files without a reasoned merge plan.

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
