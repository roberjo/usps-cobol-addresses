"""Shared helpers: reset the database, run the EBUPD01 job, query Postgres.

These tests run inside the toolchain container (make test), where PG* point
at the compose database and bin/ holds the compiled programs.
"""
from __future__ import annotations

import os
import subprocess
from dataclasses import dataclass
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "data" / "out"
WORK = ROOT / "data" / "work"
GOLDEN = ROOT / "tests" / "golden"


@dataclass
class JobResult:
    rc: int
    log: str


def psql(sql: str) -> str:
    return subprocess.run(["psql", "-At", "-F", "|", "-v", "ON_ERROR_STOP=1", "-c", sql],
                          check=True, capture_output=True, text=True).stdout


def reset_db() -> None:
    for f in ("db/schema.sql", "db/seed.sql"):
        subprocess.run(["psql", "-q", "-v", "ON_ERROR_STOP=1", "-f", f], cwd=ROOT,
                       check=True, capture_output=True)


def sysin(**overrides: str) -> Path:
    """Write a control-card file based on ctl/ebupd01.sysin with overrides."""
    cards = {}
    for line in (ROOT / "ctl" / "ebupd01.sysin").read_text().splitlines():
        k, _, v = line.partition("=")
        cards[k] = v
    cards.update(overrides)
    WORK.mkdir(parents=True, exist_ok=True)
    path = WORK / "sysin.test"
    path.write_text("".join(f"{k}={v}\n" for k, v in cards.items()))
    return path


def run_job(*args: str, sysin_path: Path | None = None, **env: str) -> JobResult:
    e = dict(os.environ, **env)
    if "EBUPDT_ABEND_AFTER" not in env:
        e.pop("EBUPDT_ABEND_AFTER", None)
    if sysin_path:
        e["SYSIN"] = str(sysin_path)
    else:
        e.pop("SYSIN", None)
    p = subprocess.run([str(ROOT / "jobs" / "ebupd01.sh"), *args], cwd=ROOT, env=e,
                       capture_output=True, text=True)
    return JobResult(p.returncode, p.stdout + p.stderr)


def dump_db() -> str:
    return subprocess.run([str(ROOT / "tools" / "dump_db.sh")], cwd=ROOT, check=True,
                          capture_output=True, text=True).stdout


def active_rows() -> set[tuple]:
    out = psql("SELECT zip5, route_id, dlvy_seq, rtrim(primary_nbr), rtrim(street_name), "
               "coalesce(rtrim(unit), ''), coalesce(zip4, '') "
               "FROM ams_address WHERE status_cd = 'A'")
    return {tuple(line.split("|")) for line in out.splitlines()}


@pytest.fixture(scope="session")
def normal_run() -> JobResult:
    """One clean run of the job with the committed inputs and control cards."""
    reset_db()
    return run_job()
