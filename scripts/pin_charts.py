#!/usr/bin/env python3
"""Replace `targetRevision: PIN_LATEST` in Argo CD apps with the latest published chart version.

Reads the nearest preceding `repoURL:` and `chart:` lines of each marker and asks Helm:
    helm show chart <chart> --repo <repoURL>      (falls back to `helm repo add` + `helm search repo`)
Run it on your machine (needs helm and network), review the diff, commit.
Use --list to only print what would change.
"""
import json
import pathlib
import re
import subprocess
import sys

APPS = pathlib.Path(__file__).resolve().parent.parent / "05-gitops" / "apps"
MARK = "PIN_LATEST"


def _helm(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["helm", *args], capture_output=True, text=True)


def latest_version(chart: str, repo: str) -> str:
    """Latest chart version. Tries `helm show chart --repo`, then falls back to a repo alias + search."""
    r = _helm("show", "chart", chart, "--repo", repo)
    if r.returncode == 0 and (m := re.search(r"^version:\s*(\S+)", r.stdout, re.M)):
        return m.group(1)
    first_error = (r.stderr or r.stdout).strip()

    host = re.sub(r"[^a-z0-9]+", "-", repo.split("//")[-1].lower()).strip("-")
    alias = f"pin-{host}"
    steps = [("repo", "add", "--force-update", alias, repo), ("repo", "update", alias)]
    for step in steps:
        r = _helm(*step)
        if r.returncode != 0:
            raise SystemExit(
                f"helm could not reach {repo} for chart '{chart}'.\n"
                f"  `helm show chart` said: {first_error}\n"
                f"  `helm {' '.join(step)}` said: {(r.stderr or r.stdout).strip()}\n"
                "Check your network/VPN/proxy, then run the failing command by hand."
            )
    r = _helm("search", "repo", f"{alias}/{chart}", "-o", "json")
    if r.returncode == 0:
        try:
            rows = json.loads(r.stdout)
        except json.JSONDecodeError:
            rows = []
        for row in rows:
            if row.get("name") == f"{alias}/{chart}":
                return row["version"]
    raise SystemExit(f"chart '{chart}' not found in {repo}. Output: {(r.stderr or r.stdout).strip()}")


def main() -> int:
    dry = "--list" in sys.argv
    changed = 0
    for path in sorted(APPS.glob("*.yaml")):
        lines = path.read_text().split("\n")
        repo = chart = None
        for i, line in enumerate(lines):
            if m := re.search(r"repoURL:\s*(\S+)", line):
                repo, chart = m.group(1), None
            elif m := re.search(r"\bchart:\s*(\S+)", line):
                chart = m.group(1)
            if MARK in line and "targetRevision:" in line:
                if not (repo and chart):
                    raise SystemExit(f"{path.name}: {MARK} without repoURL/chart above it")
                version = latest_version(chart, repo)
                print(f"{path.name}: {chart} -> {version}")
                if not dry:
                    lines[i] = line.replace(MARK, version)
                    changed += 1
        if not dry:
            path.write_text("\n".join(lines))
    print(f"{'would update' if dry else 'updated'} {changed} marker(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
