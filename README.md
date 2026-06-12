# Claude Code Coordinator

> “运筹帷幄之中，决胜千里之外。”  
> 《史记·高祖本纪》

`claude-code-coordinator` 是一个给 Codex / ClaudeCode 用的调度 skill，用来把 Claude Code 后台 session 组织成稳定的执行层。  
它以 `claude --bg`、`claude agents --json`、`claude logs`、`claude attach` 为控制面，以 tmux 作为观察面和人工接管面。  
它适合多 worker 并行、需要 git 隔离、需要持续监督与回收的仓库级工作流。  
它不把 tmux `send-keys` 当主控制方式，也不把多个 Claude Code TUI 当常驻 dashboard，而优先依赖 Claude Code 原生后台 session 机制和纯文本状态面板。  

## 安装

默认安装位置是 `~/.codex/skills/claude-code-coordinator`。

最直接的安装方式：

```bash
mkdir -p ~/.codex/skills
git clone https://github.com/Patrick1159/co-flow.git ~/.codex/skills/claude-code-coordinator
```

如果已经克隆过仓库，只需要更新：

```bash
git -C ~/.codex/skills/claude-code-coordinator pull
```

## 一键 bootstrap

现在推荐直接用一条命令做完整安装：

```bash
~/.codex/skills/claude-code-coordinator/scripts/bootstrap_install.sh
```

它会同时完成两件事：

1. 安装全局 Codex skill：
   `~/.codex/skills/claude-code-coordinator`
2. 安装全局 Claude Code skill / alias：
   - `~/.claude/skills/claude-code-coordinator/SKILL.md`
   - `~/.claude/commands/cc_coord.md`
   - `~/.claude/commands/claude-code-coordinator.md`

这里刻意不向目标 repo 写入 `CLAUDE.md` 或 `.claude/commands/`，避免污染业务仓库。

## 在 Codex 中直接调用

直接在 Codex 对话里显式调用这个 skill，不需要你自己先敲脚本命令。

以下行为已经封装在 skill 里，属于默认工作流，不需要你在每次 prompt 里重复声明：

- 使用 Claude Code background session 执行
- 派发时默认带 `--dangerously-skip-permissions`，避免 worker 卡在权限确认
- 自动建立纯文本 tmux dashboard
- 自动记录 session id 到 `.coord/workers.tsv`
- 自动把每个 worker 的状态、任务、id 和日志落到 `.coord/`
- 在需要人工接管时，给出 `claude attach <id>` 的进入方式

最简单可用的例子：

```text
使用 $claude-code-coordinator，在 /path/to/repo 上处理这个任务：

修复 auth 相关失败测试。
```

Codex 在加载这个 skill 后，会自动优先使用这套方法：

- `claude --bg`
- `claude agents --json`
- `claude logs <id>`
- `claude attach <id>`
- 纯文本 tmux dashboard + 每个 worker 的本地日志 tail 窗口

## 在 Claude Code 中使用

现在支持直接用全局入口，不需要向目标 repo 写任何协调器配置文件。

安装一次全局入口：

```bash
~/.codex/skills/claude-code-coordinator/scripts/bootstrap_install.sh
```

然后在任意目标 repo 的 Claude Code TUI 中直接使用：

- `/cc_coord`
- `/claude-code-coordinator`

最推荐的用法：

1. 直接运行全局 bootstrap：

```bash
~/.codex/skills/claude-code-coordinator/scripts/bootstrap_install.sh
```

2. 在目标 repo 开一个 Claude Code `fable` session 作为 coordinator
3. 直接在 TUI 中运行：

```text
/cc_coord 修复 auth 相关失败测试
```

或者：

```text
/claude-code-coordinator 修复 auth 相关失败测试
```

这样这个 `fable` session 就会按全局 skill / slash command 中定义的协调逻辑，继续调度 `deepseek` 或其他弱模型去执行窄任务。

## 监控与接管

tmux 中的 `dashboard` 窗口会显示：

- 每个 worker 的 `id`
- `name`
- `model`
- `status`
- 当前 `task`
- 可直接复制的 `claude attach <id>`

底部还会给出常用参考命令，包括：

- 手工接入指定 session:
  `claude attach <id>`
- 临时打开 Claude Code Agent View TUI:
  `claude agents --cwd /path/to/repo`
- 看某个 session 的 recent output:
  `claude logs <id>`
- 看本地聚合后的纯文本快照:
  `python3 scripts/status.py --repo /path/to/repo --all`
- 看调度日志:
  `tail -f /path/to/repo/.coord/coordinator.log`
- 看某个 worker 的本地日志:
  `tail -f /path/to/repo/.coord/logs/<worker>.log`

监控面板默认是纯文本加轻量高亮，不常驻运行多个 Claude TUI；`claude agents` 和 `claude attach` 都只在你需要人工检查或接管时临时打开。

如果某个 Claude background session 被停止，dashboard 会把它标记为终态并停止继续抓取 `claude logs`；对应的 tmux worker log 窗口也会自动退出释放，不会一直挂着报 `couldn't read logs`。

## 目录

- `SKILL.md`: Codex 触发与执行说明
- `references/workflow.md`: 完整工作流与兼容性说明
- `scripts/init_board.sh`: 初始化 tmux dashboard 和 `.coord/`
- `scripts/dispatch_worker.sh`: 派发后台 worker 并登记
- `scripts/watch_worker.sh`: `tail -f` 某个 worker 的本地日志文件
- `scripts/status.py`: 聚合 `.coord/workers.tsv`、`claude agents --json --all` 和本地日志落盘
- `scripts/attach_worker.sh`: 通过 worker 名称或 id 直接进入 `claude attach`
- `scripts/bootstrap_install.sh`: 安装全局 Codex / Claude Code 入口
- `scripts/install_claude_md.sh`: 废弃 shim，显式拒绝向目标 repo 写入 `CLAUDE.md`
