# Claude Code Coordinator

> “运筹帷幄之中，决胜千里之外。”  
> 《史记·高祖本纪》

`claude-code-coordinator` 是一个给 Codex 用的调度 skill，用来把 Claude Code 后台 session 组织成稳定的执行层。  
它以 `claude --bg`、`claude agents --json`、`claude logs`、`claude attach` 为控制面，以 tmux 作为观察面和人工接管面。  
它适合多 worker 并行、需要 git 隔离、需要持续监督与回收的仓库级工作流。  
它不把 tmux `send-keys` 当主控制方式，而优先依赖 Claude Code 原生后台 session 机制。  

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

## 在 Codex 中直接调用

直接在 Codex 对话里显式调用这个 skill，不需要你自己先敲脚本命令。

以下行为已经封装在 skill 里，属于默认工作流，不需要你在每次 prompt 里重复声明：

- 使用 Claude Code background session 执行
- 自动建立 tmux dashboard
- 自动记录 session id 到 `.coord/workers.tsv`
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
- tmux dashboard + 每个 worker 的日志窗口

## 目录

- `SKILL.md`: Codex 触发与执行说明
- `references/workflow.md`: 完整工作流与兼容性说明
- `scripts/init_board.sh`: 初始化 tmux dashboard 和 `.coord/`
- `scripts/dispatch_worker.sh`: 派发后台 worker 并登记
- `scripts/watch_worker.sh`: 刷新某个 worker 的 `claude logs`
- `scripts/status.py`: 聚合 `.coord/workers.tsv` 与 `claude agents --json`
