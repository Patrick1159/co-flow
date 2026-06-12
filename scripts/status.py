#!/usr/bin/env python3
import argparse
import csv
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import time
from datetime import datetime


ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]")
OSC_RE = re.compile(r"\x1b\][^\x07]*(?:\x07|\x1b\\)")
CTRL_RE = re.compile(r"[\x00-\x08\x0b-\x1f\x7f]")
LOG_UNAVAILABLE_MARKERS = (
    "couldn't read logs",
    "could not read logs",
    "session not found",
    "no such session",
)
TERMINAL_STATUSES = {"stopped", "completed", "done", "failed", "error"}


def strip_ansi(text: str) -> str:
    text = OSC_RE.sub("", text)
    text = ANSI_RE.sub("", text)
    text = CTRL_RE.sub("", text)
    return text


def clean_log(text: str) -> str:
    text = strip_ansi(text).replace("\r", "\n")
    lines = text.splitlines()
    cleaned = []
    skip_warning = False
    for line in lines:
        if line.startswith("Warning: The 'NO_COLOR' env is ignored"):
            skip_warning = True
            continue
        if skip_warning:
            if not line.strip():
                skip_warning = False
            continue
        cleaned.append(line.rstrip())

    text = "\n".join(cleaned)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip() + "\n"


def truncate(text: str, width: int) -> str:
    text = (text or "-").strip()
    if len(text) <= width:
        return text
    if width <= 1:
        return text[:width]
    return text[: width - 1] + "…"


def use_color() -> bool:
    return sys.stdout.isatty() and os.environ.get("NO_COLOR") is None


def paint(text: str, code: str) -> str:
    if not use_color():
        return text
    return f"\033[{code}m{text}\033[0m"


def muted(text: str) -> str:
    return paint(text, "2")


def bold(text: str) -> str:
    return paint(text, "1")


def section(text: str) -> str:
    return paint(text, "1;36")


def accent(text: str) -> str:
    return paint(text, "1;34")


def ok(text: str) -> str:
    return paint(text, "1;32")


def warn(text: str) -> str:
    return paint(text, "1;33")


def bad(text: str) -> str:
    return paint(text, "1;31")


def info(text: str) -> str:
    return paint(text, "1;35")


def status_style(status: str) -> str:
    value = (status or "unknown").lower()
    if value in {"idle", "completed", "done", "success"}:
        return ok(f"{status:<10}")
    if value in {"busy", "working", "running", "launched"}:
        return warn(f"{status:<10}")
    if value in {"failed", "error", "stopped"}:
        return bad(f"{status:<10}")
    return muted(f"{status:<10}")


def term_width() -> int:
    return max(100, shutil.get_terminal_size((140, 40)).columns)


def rule(char: str = "-", width: int | None = None) -> str:
    return muted(char * (width or term_width()))


def run_agents(repo: str, include_all: bool) -> list[dict]:
    cmd = ["claude", "agents", "--json", "--cwd", repo]
    if include_all:
        cmd.append("--all")
    out = subprocess.check_output(cmd, text=True)
    return json.loads(out)


def run_logs(session_id: str) -> str:
    try:
        out = subprocess.check_output(
            ["env", "-u", "FORCE_COLOR", "NO_COLOR=1", "claude", "logs", session_id],
            text=True,
            stderr=subprocess.STDOUT,
        )
    except subprocess.CalledProcessError as exc:
        out = exc.output or ""
    cleaned = clean_log(out)
    lowered = cleaned.lower()
    if any(marker in lowered for marker in LOG_UNAVAILABLE_MARKERS):
        return ""
    return cleaned


def read_workers(path: str) -> tuple[list[str], list[dict]]:
    if not os.path.exists(path):
        return [], []
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f, delimiter="\t")
        return reader.fieldnames or [], list(reader)


def write_workers(path: str, fieldnames: list[str], rows: list[dict]) -> None:
    tmp = f"{path}.tmp"
    with open(tmp, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()
        writer.writerows(rows)
    os.replace(tmp, path)


def ensure_layout(repo: str, coord_dir: str) -> tuple[str, str, str]:
    coord = os.path.join(repo, coord_dir)
    logs = os.path.join(coord, "logs")
    cache = os.path.join(coord, "cache")
    os.makedirs(logs, exist_ok=True)
    os.makedirs(cache, exist_ok=True)
    return coord, logs, cache


def is_terminal_status(status: str) -> bool:
    return (status or "").lower() in TERMINAL_STATUSES


def merge_status(repo: str, coord_dir: str, include_all: bool) -> tuple[list[dict], list[dict]]:
    coord, logs_dir, cache_dir = ensure_layout(repo, coord_dir)
    workers_path = os.path.join(coord, "workers.tsv")
    fieldnames, rows = read_workers(workers_path)
    if not fieldnames:
        fieldnames = [
            "session_id",
            "name",
            "repo",
            "model",
            "agent",
            "status",
            "task",
            "prompt_file",
            "log_file",
            "last_update",
        ]

    sessions = run_agents(repo, include_all)
    by_short = {}
    for session in sessions:
        short_id = session.get("id") or session.get("sessionId", "")[:8]
        if short_id:
            by_short[short_id] = session

    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    for row in rows:
        short_id = row.get("session_id", "")[:8]
        session = by_short.get(short_id)
        status = row.get("status", "unknown")
        if session:
            status = session.get("status") or session.get("state") or status
            row["repo"] = session.get("cwd") or row.get("repo", repo)
        elif not is_terminal_status(status):
            status = "stopped"
        row["status"] = status or "unknown"
        row["last_update"] = now

        log_file = row.get("log_file") or os.path.join(logs_dir, f"{row.get('name', short_id)}.log")
        row["log_file"] = log_file
        current = ""
        if session and not is_terminal_status(row["status"]):
            current = run_logs(short_id)
        cache_file = os.path.join(cache_dir, f"{short_id}.last")
        previous = ""
        if os.path.exists(cache_file):
            with open(cache_file, "r", encoding="utf-8") as f:
                previous = f.read()
        if current != previous:
            header = (
                f"worker: {row.get('name', '-')}\n"
                f"id: {short_id}\n"
                f"model: {row.get('model', '-') or '-'}\n"
                f"status: {row['status']}\n"
                f"task: {row.get('task', '-')}\n"
                f"attach: claude attach {short_id}\n"
                f"log_file: {log_file}\n"
                f"updated: {now}\n"
                f"{'-' * 72}\n"
            )
            os.makedirs(os.path.dirname(log_file), exist_ok=True)
            with open(log_file, "a", encoding="utf-8") as f:
                if previous and current.startswith(previous):
                    suffix = current[len(previous):]
                    if suffix:
                        f.write(suffix)
                else:
                    if os.path.getsize(log_file) > 0:
                        f.write("\n")
                    f.write(header)
                    f.write(current)
            with open(cache_file, "w", encoding="utf-8") as f:
                f.write(current)

    write_workers(workers_path, fieldnames, rows)
    return rows, sessions


def render(repo: str, coord_dir: str, include_all: bool) -> str:
    rows, sessions = merge_status(repo, coord_dir, include_all)
    workers_path = os.path.join(repo, coord_dir, "workers.tsv")

    lines = [
        bold("Claude Code Coordinator Board"),
        rule("="),
        f"{accent('repo:')} {repo}",
        f"{accent('workers:')} {workers_path}",
        "",
    ]

    active_sessions = len(sessions)
    status_counts = {}
    for row in rows:
        key = row.get("status", "unknown").lower()
        status_counts[key] = status_counts.get(key, 0) + 1
    if rows:
        summary_parts = [f"recorded={len(rows)}", f"active={active_sessions}"]
        for key in sorted(status_counts):
            summary_parts.append(f"{key}={status_counts[key]}")
        lines.append(f"{accent('summary:')} " + "  ".join(summary_parts))
        lines.append("")

    if not rows:
        lines.append(muted("No recorded workers."))
        lines.append("")
    else:
        task_width = 48
        header = f"{'id':8}  {'name':18}  {'model':12}  {'status':10}  {'task':{task_width}}  {'updated':19}"
        lines.append(section("Workers"))
        lines.append(rule("-"))
        lines.append(bold(header))
        lines.append(rule("-"))
        for row in rows:
            session_id = row.get("session_id", "")[:8]
            model = (row.get("model", "-") or "-")[:12]
            status = row.get("status", "unknown")[:10]
            task = truncate(row.get("task", "-"), task_width)
            updated = row.get("last_update", "-")[:19]
            lines.append(
                f"{accent(f'{session_id:8}')}  "
                f"{row.get('name', '-')[:18]:18}  "
                f"{info(f'{model:12}')}  "
                f"{status_style(status)}  "
                f"{task:{task_width}}  "
                f"{muted(updated)}"
            )
        lines.append("")

        lines.append(section("Takeover"))
        lines.append(rule("-"))
        for row in rows:
            short_id = row.get("session_id", "")[:8]
            name = row.get("name", "-")
            lines.append(f"{accent(f'{short_id:8}')}  {bold(f'claude attach {short_id}')}  {muted('#')} {name}")
        lines.append("")

    lines.append(section("Active Claude Sessions"))
    lines.append(rule("-"))
    for session in sessions:
        short_id = session.get("id") or session.get("sessionId", "")[:8]
        status = session.get("status") or session.get("state") or "unknown"
        name = session.get("name", "-")
        cwd = session.get("cwd", "-")
        lines.append(
            f"{accent(f'{short_id:8}')}  "
            f"{status_style(status[:10])}  "
            f"{name}  "
            f"{muted(cwd)}"
        )

    if not sessions:
        lines.append(muted("No active Claude background sessions under this repo filter."))

    repo_quoted = shlex.quote(repo)
    example_id = rows[0].get("session_id", "")[:8] if rows else "<id>"
    example_name = rows[0].get("name", "<worker>") if rows else "<worker>"
    coord_path = os.path.join(repo, coord_dir)

    lines.extend(
        [
            "",
            section("Reference Commands"),
            rule("-"),
            f"{bold('Attach worker:')}      claude attach {example_id}",
            f"{bold('Agent View TUI:')}    claude agents --cwd {repo_quoted}",
            f"{bold('Recent logs:')}       claude logs {example_id}",
            f"{bold('Board snapshot:')}    python3 scripts/status.py --repo {repo_quoted} --all",
            f"{bold('Coordinator log:')}   tail -f {os.path.join(coord_path, 'coordinator.log')}",
            f"{bold('Worker log:')}        tail -f {os.path.join(coord_path, 'logs', f'{example_name}.log')}",
            rule("="),
        ]
    )

    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    parser.add_argument("--coord-dir", default=".coord")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--watch", action="store_true")
    parser.add_argument("--interval", type=float, default=3.0)
    args = parser.parse_args()

    repo = os.path.abspath(args.repo)
    while True:
        output = render(repo, args.coord_dir, args.all)
        if args.watch:
            sys.stdout.write("\033[H\033[J")
        print(output)
        sys.stdout.flush()
        if not args.watch:
            return 0
        time.sleep(args.interval)


if __name__ == "__main__":
    raise SystemExit(main())
