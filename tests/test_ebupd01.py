"""End-to-end regression for job EBUPD01.

Golden files: any byte of difference in a job output fails the test. When an
output is *meant* to change, regenerate with `make golden` and commit the new
files with a message explaining why.
"""
from __future__ import annotations

import os
import pytest

import model
from conftest import (GOLDEN, OUT, active_rows, dump_db, psql, reset_db, run_job,
                      sysin)

OUTPUTS = ["ebrej.dat", "eburej.dat", "ebaudit.dat", "ebrpt.txt", "ebbook.dat"]
UPDATE = os.environ.get("UPDATE_GOLDEN") == "1"


def check_golden(name: str, actual: bytes) -> None:
    path = GOLDEN / name
    if UPDATE:
        GOLDEN.mkdir(parents=True, exist_ok=True)
        path.write_bytes(actual)
        return
    assert path.exists(), f"missing golden file {path}; run `make golden`"
    expected = path.read_bytes()
    if actual != expected:
        # Show the first differing line for text outputs, the offset otherwise.
        if name.endswith((".txt", ".log")):
            for n, (a, b) in enumerate(zip(actual.splitlines(), expected.splitlines()), 1):
                assert a == b, f"{name} line {n} differs:\n got: {a!r}\n exp: {b!r}"
        pos = next((i for i, (a, b) in enumerate(zip(actual, expected)) if a != b),
                   min(len(actual), len(expected)))
        pytest.fail(f"{name} differs from golden at byte {pos} "
                    f"(len {len(actual)} vs {len(expected)})")


# --------------------------------------------------------------- normal run
def test_job_max_cc_is_4(normal_run):
    assert normal_run.rc == 4, normal_run.log
    assert "EBUPD01  ENDED MAXCC=0004" in normal_run.log


@pytest.mark.parametrize("name", OUTPUTS)
def test_golden_outputs(normal_run, name):
    check_golden(name, (OUT / name).read_bytes())


def test_golden_job_log(normal_run):
    check_golden("ebupd01.log", normal_run.log.encode())


def test_golden_database(normal_run):
    check_golden("ams_address.txt", dump_db().encode())


def test_database_matches_model(normal_run):
    rows, _ = model.expected()
    want = {(r["zip5"], r["route"], str(r["seq"]), r["primary"], r["street"],
             r["unit"] or "", r["zip4"] or "") for r in rows if r["status"] == "A"}
    got = active_rows()
    assert got == want, f"missing {sorted(want - got)[:5]} extra {sorted(got - want)[:5]}"


def test_reject_reasons_match_model(normal_run):
    _, rejects = model.expected()
    counts: dict[str, int] = {}
    for name, step in (("ebrej.dat", "EBVALID"), ("eburej.dat", "EBUPDT")):
        data = (OUT / name).read_bytes()
        assert len(data) % 82 == 0
        for i in range(0, len(data), 82):
            rc = data[i + 80:i + 82].decode()
            counts[rc] = counts.get(rc, 0) + 1
    assert counts == rejects
    assert set(counts) == {f"{n:02d}" for n in range(1, 13)}, "every reason code exercised"


def test_sequences_stay_unique_and_positive(normal_run):
    out = psql("SELECT count(*) FROM ams_address WHERE status_cd = 'A' AND dlvy_seq <= 0")
    assert out.strip() == "0"
    assert psql("SELECT status_cd FROM eb_checkpoint").strip() == "C"


# ------------------------------------------------------------ other modes
def test_validate_mode_rolls_back():
    reset_db()
    before = active_rows()
    res = run_job(sysin_path=sysin(MODE="VALIDATE"))
    assert res.rc == 4, res.log
    assert "ALL CHANGES ROLLED BACK" in res.log
    assert active_rows() == before
    assert "MODE=VALIDATE - ALL CHANGES ROLLED BACK" in (OUT / "ebrpt.txt").read_text()


def test_rejmax_exceeded_stops_before_update():
    reset_db()
    before = active_rows()
    res = run_job(sysin_path=sysin(REJMAX="5"))
    assert res.rc == 8, res.log
    assert "STEP020  EBSORT FLUSHED" in res.log
    assert "STEP030  EBUPDT FLUSHED" in res.log
    assert "STEP040  EBRPT ENDED RC=0000" in res.log, "report still runs after RC 8"
    assert active_rows() == before
    assert "EBUPDT DID NOT RUN" in (OUT / "ebrpt.txt").read_text()


def test_bad_control_card_is_rc12():
    reset_db()
    res = run_job(sysin_path=sysin(COMMIT="ABC"))
    assert res.rc == 12, res.log
    assert "EBCTL03E INVALID CONTROL CARD: COMMIT=ABC" in res.log


# ---------------------------------------------------------- restart drill
def test_abend_then_restart_matches_clean_run():
    reset_db()
    crashed = run_job(EBUPDT_ABEND_AFTER="120")
    assert crashed.rc == 16, crashed.log
    assert "STEP040  EBRPT FLUSHED" in crashed.log
    # COMMIT=50: records 1-100 are committed, 101-120 were rolled back.
    assert psql("SELECT status_cd, recs_read FROM eb_checkpoint").strip() == "R|100"

    partial = (OUT / "ebaudit.dat").read_bytes()

    # Resubmitting from the top must refuse, leaving the partial outputs alone.
    blocked = run_job()
    assert blocked.rc == 12, blocked.log
    assert "OPEN CHECKPOINT" in blocked.log
    assert (OUT / "ebaudit.dat").read_bytes() == partial

    restarted = run_job("--restart")
    assert restarted.rc == 4, restarted.log
    assert "RESTARTING AFTER RECORD        100" in restarted.log

    # Identity values are not transactional: the rolled-back inserts used up
    # addr_ids, so later adds get higher ids than in a clean run (DB2 identity
    # columns leave the same gaps). Everything else must match exactly.
    for name in ("ebrej.dat", "eburej.dat", "ebrpt.txt"):
        check_golden(name, (OUT / name).read_bytes())
    assert without_ids((OUT / "ebaudit.dat").read_bytes(), 150, 17) == \
        without_ids((GOLDEN / "ebaudit.dat").read_bytes(), 150, 17)
    assert without_ids((OUT / "ebbook.dat").read_bytes(), 80, 66) == \
        without_ids((GOLDEN / "ebbook.dat").read_bytes(), 80, 66)
    strip = lambda text: sorted(line.split("|", 1)[1] for line in text.splitlines())
    assert strip(dump_db()) == strip((GOLDEN / "ams_address.txt").read_text())


def without_ids(data: bytes, lrecl: int, offset: int) -> list[bytes]:
    """Records with the 10-byte addr_id field at offset blanked out."""
    return [data[i:i + offset] + data[i + offset + 10:i + lrecl]
            for i in range(0, len(data), lrecl)]
