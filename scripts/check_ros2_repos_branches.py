#!/usr/bin/env python3
"""Check ros2.repos version entries against checked-out branches/HEAD.

Exits non-zero if any mismatches, unknown (detached), or missing repos are found.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import subprocess
import sys


def parse_repos(repos_file: Path) -> dict[str, dict[str, str]]:
    text = repos_file.read_text(encoding="utf-8")
    repos: dict[str, dict[str, str]] = {}
    current: str | None = None
    for line in text.splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if re.match(r"^\s{2}[^:]+:$", line):
            name = line.strip()[:-1]
            current = name
            repos[current] = {}
            continue
        if current and re.match(r"^\s{4}version:\s*", line):
            repos[current]["version"] = line.split(":", 1)[1].strip()
    return repos


def run_git(repo_path: Path, args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", "-C", str(repo_path)] + args,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        check=False,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repos",
        default="ros2/ros2.repos",
        help="Path to ros2.repos (default: ros2/ros2.repos)",
    )
    parser.add_argument(
        "--src",
        default="ros2/src",
        help="Source workspace root (default: ros2/src)",
    )
    args = parser.parse_args()

    root = Path.cwd()
    repos_file = (root / args.repos).resolve()
    src_root = (root / args.src).resolve()

    if not repos_file.exists():
        print(f"ERROR: repos file not found: {repos_file}")
        return 2
    if not src_root.exists():
        print(f"ERROR: source root not found: {src_root}")
        return 2

    repos = parse_repos(repos_file)

    missing: list[tuple[str, str, str]] = []
    mismatch: list[tuple[str, str, str]] = []
    unknown: list[tuple[str, str, str]] = []

    for name, meta in repos.items():
        version = meta.get("version")
        if not version:
            continue
        repo_path = src_root / name
        if not repo_path.exists():
            missing.append((name, version, "missing path"))
            continue
        if not (repo_path / ".git").exists():
            missing.append((name, version, "not a git repo"))
            continue

        head = run_git(repo_path, ["rev-parse", "--abbrev-ref", "HEAD"]).stdout.strip()
        head_commit = run_git(repo_path, ["rev-parse", "HEAD"]).stdout.strip()

        if re.fullmatch(r"[0-9a-f]{7,40}", version):
            if head_commit.startswith(version):
                continue
            mismatch.append((name, version, f"HEAD {head_commit[:12]}"))
            continue

        if head == "HEAD":
            tag = run_git(repo_path, ["describe", "--tags", "--exact-match"]).stdout.strip()
            if tag == version:
                continue
            unknown.append((name, version, f"detached HEAD {head_commit[:12]}"))
            continue

        if head != version:
            mismatch.append((name, version, f"branch {head}"))

    if mismatch:
        print("MISMATCH")
        for name, version, got in mismatch:
            print(f" - {name} expected {version} got {got}")
        print()
    if unknown:
        print("UNKNOWN")
        for name, version, got in unknown:
            print(f" - {name} expected {version} got {got}")
        print()
    if missing:
        print("MISSING")
        for name, version, status in missing:
            print(f" - {name} expected {version} status {status}")
        print()

    if mismatch or unknown or missing:
        return 1
    print("OK: all repos match ros2.repos versions")
    return 0


if __name__ == "__main__":
    sys.exit(main())
