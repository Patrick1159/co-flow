#!/usr/bin/env python3
import argparse
import csv
import json
import os
import subprocess
import sys
import time


def run_agents(repo: str, include_all: bool) -> list[dict]:
    cmd = ["claude", "agents", "--json", "--cwd", repo]
    if include_all:
        cmd.append("--all")
    out = subprocess.check_output(cmd, text=True)
    return json.loads(out)


def read_workers(path: str) -> list[dict]:
    if not os.path.exists(path):
        return []
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def render(repo: str, coord_dir: str, include_all: bool) -> str:
    workers_tsv = os.path.join(repo, coord_dir, "workers.tsv")
    workers = read_workers(workers_tsv)
    sessions = run_agents(repo, include_all)
    by_short = {}
    for session in sessions:
        short_id = session.get("id") or session.get("sessionId", "")[:8]
        if short_id:
            by_short[short_id] = session

    lines = []
    lines.append(f"repo: {repo}")
    lines.append(f"workers file: {workers_tsv}")
    lines.append("")

    if not workers:
        lines.append("No recorded workers.")
        lines.append("")

    if workers:
        header = f"{'id':8}  {'name':20}  {'status':12}  {'model/agent':18}  cwd"
        lines.append(header)
        lines.append("-" * len(header))
        for row in workers:
            short_id = row["session_id"][:8]
            session = by_short.get(short_id)
            status = session.get("status") if session else row.get("status", "unknown")
            if not status and session:
                status = session.get("state", "unknown")
            status = status or "unknown"
            model_agent = "/".join(x for x in [row.get("model", ""), row.get("agent", "")] if x) or "-"
            cwd = session.get("cwd") if session else row.get("repo", repo)
            cwd = cwd or row.get("repo", repo)
            lines.append(f"{short_id:8}  {row['name'][:20]:20}  {status[:12]:12}  {model_agent[:18]:18}  {cwd}")
        lines.append("")

    lines.append("Active Claude sessions:")
    lines.append("")
    for session in sessions:
        short_id = session.get("id") or session.get("sessionId", "")[:8]
        status = session.get("status") or session.get("state") or "unknown"
        name = session.get("name", "-")
        cwd = session.get("cwd", "-")
        lines.append(
            f"{short_id:8}  {status:12}  {name}  {cwd}"
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
            os.system("clear")
        print(output)
        sys.stdout.flush()
        if not args.watch:
            return 0
        time.sleep(args.interval)


if __name__ == "__main__":
    raise SystemExit(main())
