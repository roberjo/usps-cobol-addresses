# EBUPD01 operations runbook

## Running the job

| Where | Command |
| --- | --- |
| Mac (host) | `make run`, which runs inside the toolchain container |
| Toolchain shell (`make shell`) | `make reset-db && jobs/ebupd01.sh` |
| Other control cards | `SYSIN=path/to/cards make run` |
| Restart after an abend | `make restart`, or `jobs/ebupd01.sh --restart` |

Job outputs:

| DD | File | Contents |
| --- | --- | --- |
| `EBREJ` | `data/out/ebrej.dat` | Validation rejects, 82-byte records |
| `EBUREJ` | `data/out/eburej.dat` | Update rejects, 82-byte records |
| `EBAUDIT` | `data/out/ebaudit.dat` | Before/after image per applied action, 150-byte records |
| `EBRPT` | `data/out/ebrpt.txt` | Run report, 133 bytes with ASA carriage control |
| `EBBOOK` | `data/out/ebbook.dat` | Edit book lines for every changed route, 80-byte records |

Work files (`data/work/`) hold the validated file, the sorted file, and the
effective SYSIN.

## Control cards (`ctl/ebupd01.sysin`)

| Card | Default | Meaning |
| --- | --- | --- |
| `RUNDATE=YYYYMMDD` | required | Business date. Edit dates after it are rejected. |
| `MODE=UPDATE\|VALIDATE` | `UPDATE` | `VALIDATE` runs every step and rolls the update back. |
| `COMMIT=n` | 500 (card: 50) | Records per unit of work and checkpoint. |
| `REJMAX=n` | 10 (card: 25) | Maximum validation reject percentage before RC 8. |
| `RESTART=Y\|N` | `N` | Resume EBUPDT from its checkpoint. `--restart` sets it. |

Lines starting with `*` are comments. Any other card is an error (RC 12).

## Return codes

| Step | RC | Meaning | Action |
| --- | --- | --- | --- |
| STEP000 | 12 | An unfinished run has an open checkpoint | Restart; don't resubmit from the top |
| STEP010 EBVALID | 0 | All passed | – |
| | 4 | Some rejects, within `REJMAX` | Review section 1 of the report |
| | 8 | Reject rate above `REJMAX`. STEP020–030 skipped; nothing applied. | Get a corrected file from the producer |
| | 12 | Bad control card, open/read error, or SQL error | See the messages below |
| STEP020 EBSORT | 12 | Sort failed | Check the work file space and permissions |
| STEP030 EBUPDT | 0 / 4 | Applied; 4 = some update rejects (10–12) | Review the report |
| | 12 | SQL error (rolled back to the last commit), or an open checkpoint without `RESTART=Y` | Fix the cause, then restart |
| | 16 | Simulated abend (`EBUPDT_ABEND_AFTER`) | Restart |
| STEP040 EBRPT | 12 | File or SQL error | Rerun STEP040 alone |

The job ends with the highest step RC. Steps after an RC ≥ 8 are flushed,
except EBRPT, which runs unless RC ≥ 12.

## Messages

| ID | Program | Text / meaning |
| --- | --- | --- |
| EBCTL01E | all | SYSIN open failed |
| EBCTL02E | all | `RUNDATE` card missing |
| EBCTL03E | all | Invalid control card (the card is shown) |
| EBDB01E | SQL programs | `EBDB_DSN` not set |
| EBDB02E | SQL programs | Database connect failed |
| EBDB99E | SQL programs | Unexpected SQLCODE/SQLSTATE; work rolled back, RC 12 |
| EBV0001E / EBV0002E | EBVALID | Open / read error on the named file |
| EBV0008E | EBVALID | Reject rate exceeds `REJMAX`; update will not run |
| EBS0001E | EBSORT | SORT-RETURN not zero |
| EBU0001E | EBUPDT | Open failed |
| EBU0002I | EBUPDT | Restarting after record *n*, key zip/route/seq |
| EBU0003E | EBUPDT | Prior run did not finish; resubmit with `RESTART=Y` |
| EBU0004W | EBUPDT | `RESTART=Y` but no open checkpoint; starting from the top |
| EBU0005E / EBU0007E | EBUPDT | Audit write / sorted-file read error |
| EBU0006I | EBUPDT | `MODE=VALIDATE`: everything rolled back |
| EBU0999S | EBUPDT | Simulated abend (drill) |
| EBR0001E–EBR0004E | EBRPT | Open failures, or the route table is full (200) |

## Restart procedure

EBUPDT commits every `COMMIT=` records. The `eb_checkpoint` row (status `R`,
records read, counters, last key) is updated in the **same** unit of work as
the address changes. After an abend, the database and the checkpoint agree at
the last commit.

1. Leave the outputs alone. A plain resubmit is refused at STEP000 because it
   would delete the partial audit and reject files.
2. Look at the checkpoint:
   `psql -c "select * from eb_checkpoint"` (status `R`, `recs_read` = records
   already committed).
3. Run `jobs/ebupd01.sh --restart`. The script trims `EBAUDIT` and `EBUREJ` to
   the counts in the checkpoint, dropping anything written after the last
   commit, and starts at STEP030 with `RESTART=Y`. EBUPDT skips `recs_read`
   records and carries on. STEP040 then runs normally.
4. The final outputs match a clean run, except `addr_id` values for adds after
   the restart point. Rolled-back inserts had already used sequence values;
   DB2 identity columns behave the same way.

To practice, run `EBUPDT_ABEND_AFTER=120 make run`, then `make restart`. The
regression test `test_abend_then_restart_matches_clean_run` automates this.

## Abend drills

Practice finding a planted defect from the outputs alone (RC, report, reject
counts). Plant it on a branch; don't look at the diff.

| Drill | How to plant it | What you'll see |
| --- | --- | --- |
| S0C7 data exception | Remove the `IS NOT NUMERIC` test in `EBVRULES` 6000 | `-debug` runtime error on the packed field; job RC ≠ 0 |
| Subscript out of range | Set `WS-RT-MAX` above the `OCCURS` limit in EBRPT and feed more routes | `-fec=all` subscript check fails |
| Missing SQLCODE check | Drop the `WHEN 100` in EBRPT `5200-FETCH-BOOK` | Loops or stops early; `EBBOOK` count changes |
| Control-break bug | Remove the final `PERFORM 2900-ROUTE-BREAK` in EBUPDT 3000 | Last route's SYSOUT line disappears; golden job log fails |

Then write the INC and CHG tickets (see [`tickets/`](../tickets)).
