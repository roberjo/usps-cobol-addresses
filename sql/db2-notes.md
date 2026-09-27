# DB2 for z/OS vs. PostgreSQL + GixSQL

The COBOL programs are written the way they would be for DB2: `EXEC SQL`
with host variables, `SQLCODE` checked after every statement, null indicators,
explicit `COMMIT`. These are the places where the local stand-in differs, and
what the host version would do.

## Schema (`db/schema.sql`)

| Item | Here (PostgreSQL 16) | DB2 for z/OS |
| --- | --- | --- |
| Text columns | `CHAR(n)`, blank-padded, trailing blanks ignored in comparisons | Same `CHAR(n)` semantics |
| `addr_id` | `BIGSERIAL` | `BIGINT GENERATED ALWAYS AS IDENTITY (CACHE 20)` |
| One active address per position | Partial unique index `... WHERE status_cd = 'A'` | No partial indexes. Enforce it in EBUPDT (it already checks before insert), or keep deleted rows in a history table so a plain unique index works. |
| Timestamps | `CURRENT_TIMESTAMP`, `TIMESTAMP` | Same, `TIMESTAMP(6)` |
| Checkpoint table | `eb_checkpoint` | Same design, often in its own table space with row-level locking |

## Embedded SQL

| Topic | Here | DB2 |
| --- | --- | --- |
| Connect | `CONNECT TO :dsn USER :user.pass` in `EBDBPD.cpy` | None in the program. The plan is bound and attached by `DSN RUN PROGRAM(...) PLAN(...)` under `IKJEFT01` (see the JCL). |
| Include members with SQL | `EXEC SQL INCLUDE member END-EXEC`, gixpp `-p -E .cpy` | Same statement. DCLGEN members come in this way. |
| Host variable declarations | Must sit inside `BEGIN/END DECLARE SECTION`. Without it, gixpp commented out the last WORKING-STORAGE item when it injected its statement buffers. | Optional for COBOL |
| Numeric host variables | **`COMP-3`.** GixSQL 1.0.20b sends binary (`COMP`, `COMP-5`) *input* host variables wrongly: SQLSTATE `08P01` "insufficient data left in message", or a wrong value. Binary *output* works. | `S9(9) COMP` is the usual choice for `INTEGER`; `COMP-3` is also accepted. |
| Null indicators | `S9(4) COMP`, as GixSQL requires. Only 0 and −1 are used, which are the same bytes in either byte order, so this is safe. | `S9(4) COMP` |
| `DECLARE CURSOR` | Must be in WORKING-STORAGE; in a paragraph the OPEN gets "no such cursor". | Either place |
| Cursor-init flags | gixpp generates `PIC X` flags without `VALUE`. Under `-std=ibm` storage starts as `x'00'`, so the Makefile adds `VALUE SPACE` after precompiling. | n/a |
| Transactions | GixSQL's default left each statement autocommitted, so COMMIT warned "no transaction in progress". The DSN sets `?autocommit=off`. | Unit of work runs from one COMMIT to the next; nothing is autocommitted in batch |
| Host variables in the select list | gixpp rejects `SELECT :hv + 1 ...` | Allowed |

## SQLCODE values

| Condition | GixSQL / Postgres | DB2 |
| --- | --- | --- |
| Row not found / end of cursor | `+100` | `+100` |
| Duplicate key | `-10007`, SQLSTATE `23505` | `-803`, SQLSTATE `23505` |
| Protocol error | `-10007`, SQLSTATE `08P01` | n/a |
| Cursor not open / not found | `-111`, SQLSTATE `24518` | `-501`, SQLSTATE `24501` |
| Connection failed | `-100` (GixSQL internal) | n/a (attach failure) |

Programs here only branch on 0 and 100. Anything else goes to `9900-SQL-ERROR`
(roll back, RC 12). That's the portable pattern. Test SQLSTATE, not negative
SQLCODE values, when a program has to tell errors apart.

## Behavior worth knowing on both

- **Identity/sequence values are not transactional.** Rolled-back inserts leave
  gaps, so a restarted run gets different `addr_id`s than a clean run. The
  restart regression test compares everything except those ids.
- **Resequencing inside a unique index.** `SET dlvy_seq = dlvy_seq + 1` can
  fail partway through with a duplicate key, depending on row order.
  PostgreSQL checks non-deferrable unique indexes row by row, and DB2 has the
  same exposure. EBUPDT shifts in two passes instead: negate, then flip back.
  Many real systems avoid the problem by numbering in steps of 10 or 100.
- **Commit frequency vs. locks.** A small `COMMIT=` means a small restart window
  and short lock durations, but more commit overhead. On DB2 the checkpoint
  interval is usually tuned against lock escalation thresholds.
