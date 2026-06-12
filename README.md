# Claude Code Coordinator

> “运筹帷幄之中，决胜千里之外。”  
> 《史记·高祖本纪》

`claude-code-coordinator` 是一个给 Codex 用的调度 skill，用来把 Claude Code 后台 session 组织成稳定的执行层。  
它以 `claude --bg`、`claude agents --json`、`claude logs`、`claude attach` 为控制面，以 tmux 作为观察面和人工接管面。  
它适合多 worker 并行、需要 git 隔离、需要持续监督与回收的仓库级工作流。  
它不把 tmux `send-keys` 当主控制方式，而优先依赖 Claude Code 原生后台 session 机制。  

## 开箱即用

1. 初始化 dashboard：

```bash
~/.codex/skills/claude-code-coordinator/scripts/init_board.sh \
  --repo /path/to/repo \
  --session cc-board
```

2. 写一个 worker prompt：

```bash
mkdir -p /path/to/repo/.coord/prompts
cat > /path/to/repo/.coord/prompts/auth-fix.md <<'EOF'
You are a Claude Code worker.

Task:
Fix auth-related failing tests.

Constraints:
- Only modify auth-related files.
- Do not refactor unrelated code.
- Do not merge branches.

Acceptance:
- Relevant tests pass.
- Report changed files, commands run, results, and residual risks.
EOF
```

3. 派发后台 worker：

```bash
~/.codex/skills/claude-code-coordinator/scripts/dispatch_worker.sh \
  --repo /path/to/repo \
  --name auth-fix \
  --prompt-file /path/to/repo/.coord/prompts/auth-fix.md \
  --model fable
```

4. 查看状态：

```bash
python ~/.codex/skills/claude-code-coordinator/scripts/status.py \
  --repo /path/to/repo \
  --all
```

5. 需要时人工接管：

```bash
claude attach <session-id>
```

## 目录

- `SKILL.md`: Codex 触发与执行说明
- `references/workflow.md`: 完整工作流与兼容性说明
- `scripts/init_board.sh`: 初始化 tmux dashboard 和 `.coord/`
- `scripts/dispatch_worker.sh`: 派发后台 worker 并登记
- `scripts/watch_worker.sh`: 刷新某个 worker 的 `claude logs`
- `scripts/status.py`: 聚合 `.coord/workers.tsv` 与 `claude agents --json`
