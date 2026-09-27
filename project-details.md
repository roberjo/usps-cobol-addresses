# USPS AMS Edit Book Update — Hobby COBOL Mainframe Project

Sep 27, 2026 · @John Roberts

## Overview

This is a hobby project that builds a mainframe-style COBOL batch system on a MacBook Air, just for the fun of it and as a portfolio piece. The idea comes from a GovCIO job posting for COBOL support on the USPS Address Management System (AMS) Edit Book Update process. That posting described a real, unglamorous legacy batch system, which is exactly what makes it an interesting thing to recreate.

- **Inspiration:** a GovCIO posting for COBOL/DB2 work on the AMS Edit Book Update process, with ChangeMan and ServiceNow in the toolset.
- **Goal:** build a realistic mock of an Edit Book Update batch job that runs end to end locally, then break it, debug it, and test it the way a mainframe shop would.
- **Portfolio outcome:** a public repo with working COBOL programs, reference JCL, embedded SQL, a regression suite in CI, and write-ups that show how legacy batch systems work.
- **Coverage:** a Mac can reproduce about 70% of the mainframe experience (COBOL, batch patterns, SQL, debugging, change discipline). IBM's free Z Xplore program covers much of the rest with a real z/OS account.

The mock design below is hypothetical. It is shaped like a real address-update batch job, not copied from USPS internals, and it uses only generated test data.

## Status (Sep 27, 2026)

The core job is built and runs end to end. That covers the week 1–3 deliverables plus the restart drill, and the Week 4 process work is partly done.

| Area | State |
| --- | --- |
| Toolchain | Docker image (`docker/Dockerfile`): GnuCOBOL 3.2 and GixSQL 1.0.20b built from source, cobol-check 0.2.19, Python + uv. PostgreSQL 16 runs in a second container (`compose.yaml`). |
| Programs | `EBVALID`, `EBVRULES`, `EBSORT`, `EBUPDT`, `EBRPT` in `src/`, plus 9 copybooks. |
| Job | `jobs/ebupd01.sh` (runnable) and `jcl/EBUPD01.jcl` (reference). With the committed data the job ends MAXCC=0004: 210 transactions, 23 rejects (all 12 reason codes), 187 applied. |
| Tests | `make ci`: column-72 lint, 20 cobol-check unit tests, 24 pytest tests (golden files, a Python oracle model, VALIDATE mode, the REJMAX stop, a bad control card, abend + restart). All green. |
| CI | `.github/workflows/ci.yml` builds the image with GitHub Actions cache and runs `make ci`. |
| Docs | README, ICD for `EBTRANS`, operations runbook, DB2 notes, gotchas write-up, ticket templates. |
| Not started | Z Xplore port, mock INC/CHG from a real drill, `make promote`, stretch goals. |

Design changes made during the build are marked **(changed)** below. [`docs/gotchas.md`](docs/gotchas.md) explains the reasons.

## Background: the system being imitated

### What the real system does

- **AMS** is the USPS address database that defines which addresses sit on which carrier route, in what delivery order.
- **Edit books** are route address listings that carriers annotate with adds, deletes, and changes (new construction, vacancies, unit splits).
- **Edit Book Update** takes those annotated changes, validates them, and applies them to AMS. It then re-sequences the route and produces updated listings and reports.

### Likely technical stack

- IBM z/OS mainframe, Enterprise COBOL, JCL-driven batch jobs.
- DB2 for z/OS through embedded SQL (`EXEC SQL`), plus sequential and possibly VSAM files.
- DFSORT/ICETOOL for sort and merge steps; a job scheduler such as CA-7 or TWS.
- ChangeMan ZMF for source control and promotion; ServiceNow for incidents and change requests.

### The maintenance workflow worth simulating

Legacy batch work is mostly careful maintenance rather than greenfield code, and that workflow is part of the fun to recreate:

1. An incident or enhancement request arrives.
2. You search the libraries for the affected field, copybook, or table.
3. You trace data flow across programs and jobs, then write an impact analysis.
4. You make a small change, unit test it, and build a change package.
5. You file a change request, promote through test levels, and support the "production" run.

The project mimics this loop with git, markdown tickets, and a golden-file regression suite.

## Mainframe components and local equivalents

Every mainframe piece has a local stand-in that preserves the concept, even where the tool differs.

| Mainframe component | Local equivalent | How close |
| --- | --- | --- |
| Enterprise COBOL | GnuCOBOL 3.2 compiled with `-std=ibm` (fixed format; WORKING-STORAGE starts as binary zeros) | High for language and batch logic |
| DB2 for z/OS, embedded SQL | PostgreSQL 16 + GixSQL precompiler | Medium: see [`sql/db2-notes.md`](sql/db2-notes.md) for every difference found |
| JCL job and DD statements | `jobs/ebupd01.sh`; `DD_<NAME>` environment variables; COND logic in the script | High conceptually |
| DFSORT | COBOL `SORT` verb (`EBSORT`), same keys as the DFSORT card in the JCL | Medium |
| VSAM KSDS | GnuCOBOL indexed files (BDB backend is in the image) | Medium; not used yet |
| EBCDIC datasets, COMP-3 fields | Python `cp037` codec (field-aware, `tools/ebcdic.py`), GnuCOBOL native COMP-3 | High |
| Checkpoint/restart | `eb_checkpoint` row committed in the same unit of work as the updates | High |
| ChangeMan ZMF packages and promotion | Git branches `pkg/CHGnnnnnnn-*`, promotion `dev` → `test` → `prod` | Concept only |
| ServiceNow incidents and changes | Markdown templates in `tickets/` | Concept only |
| ISPF 3.14 SuperC library search | `ripgrep` across `src/`, `copybooks/`, `jcl/` | High |
| ISPF editor | VS Code + IBM Z Open Editor or Broadcom Code4z COBOL Language Support | Medium |
| Real z/OS, TSO, SDSF | IBM Z Xplore (free, hosted) | High: it is real z/OS |

## Local environment setup (changed)

The first plan was a native Homebrew install. GixSQL publishes x86_64 packages only and needs patches to build with GCC 14, so the toolchain now lives in a container that runs the same way on Apple Silicon and in GitHub Actions. Expect about 10 minutes for the first image build.

### 1. Prerequisites

Docker with Compose: Docker Desktop, or Colima with `docker-compose` (`brew install colima docker docker-compose`). The Makefile detects either `docker compose` or `docker-compose`.

### 2. Build and run

```bash
make image    # toolchain image: GnuCOBOL 3.2, GixSQL 1.0.20b, cobol-check, psql, Python + uv
make ci       # starts Postgres, then lint + build + unit + regression inside the toolchain
make shell    # interactive shell in the toolchain (IN_TOOLCHAIN=1)
```

On the Mac, every toolchain target (`build`, `run`, `restart`, `test`, `unit`, `lint`, `reset-db`, `gen`, `golden`, `ebcdic-demo`) runs through `docker-compose run toolchain make <target>`. Inside the container the same targets run directly. The database is `amsdev` (user `ams`, password `ams`), published on `localhost:5432`.

What the image contains, and why:

- **GnuCOBOL 3.2 from source**, configured `--without-xml2`. Debian's package links a libxml2 that prints a version warning on every program exit, which would pollute job logs and golden files.
- **GixSQL 1.0.20b from source**, configured with `-include cstdint` (for GCC 14) and built with `-j2` (higher parallelism runs a small Docker VM out of memory). Only the PostgreSQL driver is built.
- **cobol-check 0.2.19**, pinned to a commit because 0.2.x has no tagged release.
- Python dependencies installed with `uv sync --frozen` into `/opt/venv`, outside the bind-mounted workspace, so a macOS `.venv` never collides with the Linux one.

### 3. Editor

- VS Code with **IBM Z Open Editor** for COBOL/JCL syntax, outline, and copybook resolution. Point its property groups at `copybooks/`.
- Optional: Broadcom **Code4z** as an alternative language server.
- `gdb` is in the image for crashes (GnuCOBOL compiles through C).

### 4. Repository layout

```text
usps-cobol-addresses/
├── src/            # COBOL: EBVALID, EBVRULES, EBSORT, EBUPDT, EBRPT
├── copybooks/      # EBTRANS, EBREJ, EBERR, EBAUDIT, EBBOOK, EBCTLWS/EBCTLRD, EBDBWS/EBDBPD
├── jcl/            # reference JCL written as it would be on z/OS (not executed)
├── jobs/           # ebupd01.sh: executable equivalent of the JCL
├── ctl/            # SYSIN control cards
├── db/             # schema.sql, seed.sql (generated, committed)
├── data/in/        # ebtrans.dat (generated, committed so golden files stay stable)
├── data/out/       # job outputs (git-ignored)
├── obj/, bin/      # precompiled source and executables (git-ignored)
├── tests/          # test_ebupd01.py, test_tools.py, model.py (oracle), golden/, unit/ (cobol-check)
├── tools/          # gen_data.py, ebcdic.py, dump_db.sh, ebcdic_demo.sh
├── sql/            # db2-notes.md
├── tickets/        # INC/CHG templates
├── docs/           # ICD-EBTRANS.md, operations.md, gotchas.md
├── docker/         # Dockerfile
├── compose.yaml
└── Makefile
```

### 5. Real mainframe access

Register for **IBM Z Xplore**. It gives a free z/OS account with COBOL, JCL, and data sets. Use it to confirm that code written locally compiles under Enterprise COBOL and runs under real JCL, which makes a great "it runs on a real mainframe too" moment for the portfolio. `EBVRULES` and `EBSORT` have no SQL, so they are the natural first ports.

## Mock system design

The mock is one batch job, `EBUPD01`, with four program steps and a cleanup step. A SYSIN control card deck feeds every program.

```text
 EBTRANS (80-byte edit transactions)      ctl/ebupd01.sysin (feeds every step)
        │
        ▼
 STEP010 EBVALID (+ CALL EBVRULES) ──► EBREJ (rejects) ──────────────┐
        │  (singleton SELECT on ams_route)                           │
        ▼                                                            │
   EBVALOUT                                                          │
        │                                                            │
        ▼                                                            │
 STEP020 EBSORT (ZIP5 A, route A, seq D, action D)                   │
        │                                                            │
        ▼                                                            │
 STEP030 EBUPDT ◄──► ams_address, eb_checkpoint ──► EBAUDIT ─────────┤
        │  (commit / checkpoint / restart)         ──► EBUREJ ───────┤
        ▼                                                            ▼
 STEP040 EBRPT ───────────────────────► EBRPT report + EBBOOK edit book extract
```

Only EBUPDT writes to the database, so it is the step where commit, restart, and rollback logic lives.

### Input 1: edit transaction record (copybook `EBTRANS.cpy`, 80 bytes)

```cobol
       01  EB-TRANS-REC.
           05  EBT-ACTION-CD        PIC X(1).
               88  EBT-ADD          VALUE 'A'.
               88  EBT-CHANGE       VALUE 'C'.
               88  EBT-DELETE       VALUE 'D'.
           05  EBT-ZIP5             PIC X(5).
           05  EBT-ROUTE-ID         PIC X(4).
           05  EBT-DLVY-SEQ         PIC S9(7) COMP-3.
           05  EBT-PRIMARY-NBR      PIC X(10).
           05  EBT-STREET-NAME      PIC X(28).
           05  EBT-UNIT             PIC X(8).
           05  EBT-ZIP4             PIC X(4).
           05  EBT-CARRIER-ID       PIC X(6).
           05  EBT-EDIT-DATE        PIC 9(8).
           05  EBT-EDIT-DATE-X      REDEFINES EBT-EDIT-DATE PIC X(8).
           05  FILLER               PIC X(2).
```

The delivery sequence is packed decimal (4 bytes) on purpose, so you get to play with COMP-3 handling and hex inspection. The full field-by-field contract is in [`docs/ICD-EBTRANS.md`](docs/ICD-EBTRANS.md).

### Input 2: AMS master tables (`db/schema.sql`) (changed)

- `ams_route (zip5, route_id, route_type)`, primary key (zip5, route_id).
- `ams_address (addr_id BIGSERIAL, zip5, zip4, route_id, dlvy_seq, primary_nbr, street_name, unit, status_cd, last_upd_ts)`.
  - Text columns are `CHAR(n)`, not `VARCHAR`. They blank-pad like DB2 `CHAR`, so COBOL `PIC X` host variables compare without trimming.
  - `unit` and `zip4` are nullable. Blank values go in through null indicators.
- `ux_active_seq`: a unique index on (zip5, route_id, dlvy_seq) `WHERE status_cd = 'A'`. It is Postgres-only; the DB2 note is in `sql/db2-notes.md`.
- **New:** `eb_checkpoint` holds one row per job: status `R`/`C`, records read, counters, last key. EBUPDT updates it in the same unit of work as the address changes.

### Input 3: SYSIN control cards (`ctl/ebupd01.sysin`)

```text
RUNDATE=20261005
MODE=UPDATE
COMMIT=50
REJMAX=25
RESTART=N
```

- `MODE=VALIDATE` runs every step and rolls the update back.
- `REJMAX` is the percentage of *validation* rejects that makes EBVALID end RC 8.
- `COMMIT=50` is small so the committed data (191 valid records) spans several checkpoints.
- `RESTART=Y` resumes EBUPDT from its checkpoint. `jobs/ebupd01.sh --restart` sets it.

### Processing rules by step

1. **EBVALID** reads each record and `CALL`s **EBVRULES**, a subprogram with no file or database access so it can be unit tested. EBVRULES checks:
   - the action code;
   - numeric ZIP5 and ZIP4;
   - LOW/HIGH-VALUES in text fields;
   - the required fields for each action;
   - that the edit date is a real date and not after RUNDATE;
   - that the packed sequence is valid and greater than zero.

   EBVALID then confirms the route with a singleton `SELECT` on `ams_route`. Good records go to `EBVALOUT` and bad ones to `EBREJ` with a reason code. **(changed)** If the reject rate is above REJMAX, EBVALID ends RC 8, and the later steps are skipped before anything touches the database.
2. **EBSORT (changed)** orders `EBVALOUT` by ZIP5 ascending, route ascending, **sequence descending, action descending** (with `EQUALS`). Working each route from the top down means a resequencing add only shifts positions that are already processed, so every sequence number keeps the meaning the carrier saw in the printed book. Descending action gives D, C, A at the same position, so a delete frees a position before an add reuses it. (The first draft sorted ascending, which let an early add shift the target of a later delete.)
3. **EBUPDT** runs a control break on ZIP5 + route and applies each action:
   - D: `SELECT` the active row at that sequence. If there is none (SQLCODE 100), reject 10. If the primary number differs, reject 12. Otherwise `UPDATE ... SET status_cd = 'D'`.
   - C: `SELECT` the before image (100 means reject 10), then `UPDATE` the address fields.
   - A: if the same address is already active on the route, reject 11. If the sequence is occupied, shift every active row at or above it up by 1 **in two passes (changed)**: negate, then flip back, so the unique index never sees a collision mid-statement. Then `INSERT`.
   - Every `COMMIT=` records: update `eb_checkpoint` and `COMMIT`.
   - Write before/after images to `EBAUDIT`. **(changed)** Update-time rejects go to their own file, `EBUREJ`, so a restart can trim it to the committed count.
4. **EBRPT** reads `EBREJ`, `EBUREJ`, and `EBAUDIT` (all `OPTIONAL`, since the update may have been skipped) and prints a 132-column report with ASA carriage control:
   - the reject listing;
   - a reason-code summary;
   - per-route totals with current active counts from the database;
   - a status line.

   It also runs cursor `BOOKCUR` for every route with an applied change to write the `EBBOOK` edit book extract.

### Outputs and return codes

| File or target | Contents | Format |
| --- | --- | --- |
| `ams_address` | Applied adds, changes, soft deletes | Database rows |
| `eb_checkpoint` | Restart point and counters | Database row |
| `EBREJ` | Validation rejects + 2-char reason code | 82-byte fixed records |
| `EBUREJ` | Update rejects + 2-char reason code | 82-byte fixed records |
| `EBAUDIT` | Before/after image per applied action, with rows shifted | 150-byte fixed records |
| `EBRPT` | Reject listing, reason summary, route summary | 133 bytes: ASA + 132 print positions |
| `EBBOOK` | Updated edit book listing for each changed route | 80-byte fixed records |

| RC | Meaning |
| --- | --- |
| 0 | All transactions applied |
| 4 | Some rejects, validation rejects at or below REJMAX |
| 8 | Validation reject rate above REJMAX. Sort and update are skipped, nothing is applied, and the report still prints. |
| 12 | File open failure, bad control card, unexpected SQLCODE (rolled back), or an unfinished prior run without restart |
| 16 | Simulated abend in EBUPDT (`EBUPDT_ABEND_AFTER=n`, restart drills) |

The full message and RC list is in [`docs/operations.md`](docs/operations.md).

## Mocking strategy

Each mock replaces a mainframe service with a local one while keeping the interface the COBOL programs see: DD names, fixed-width records, SQLCODEs, and return codes.

### Test data generation (`tools/gen_data.py`)

- Faker and `random` with a fixed seed. Reruns are byte-identical on macOS and Linux, so golden outputs stay stable, and `uv.lock` pins the Faker version.
- 3 ZIP codes (the unassigned `00011`–`00013`) × 8 routes (`C001`–`C006`, `R001`, `R002`) × 150–400 addresses: 6,630 rows in `db/seed.sql`, with contiguous delivery sequences, some apartment units, and ZIP+4 on about 90% of rows.
- 187 well-formed transactions on 5 "returned" routes (deletes, changes, mid-route adds, and a delete followed by a re-add at the same position), plus 23 planted bad records covering every reason code:
  - invalid action code, non-numeric ZIP5 or ZIP4, missing street/primary/carrier
  - invalid or future edit date, unknown route or ZIP
  - spaces in the packed sequence (the S0C7 bait), zero, and negative sequence
  - LOW-VALUES and HIGH-VALUES in text fields
  - delete or change at an empty sequence (SQLCODE 100), duplicate add, primary-number mismatch on a delete
- The mix is about 89% good and 11% bad, so the default `REJMAX=25` passes. The test suite also runs with `REJMAX=5` to exercise RC 8.
- COMP-3 fields are packed digit-per-nibble with the sign in the last nibble (`C` positive, `D` negative).

### EBCDIC mode (`tools/ebcdic.py`)

`gen_data.py --ebcdic` encodes text fields with `cp037` and leaves COMP-3 bytes untouched. `tools/ebcdic.py` converts field-aware (`to-ascii`, `to-ebcdic`), blind (`blind`, which reproduces the bug), and dumps records with the packed fields decoded. `make ebcdic-demo` shows the blind conversion turning `x'0000119C'` into the invalid `x'000011E6'`.

Inspect records with `xxd -c 80 data/in/ebtrans.dat` to read packed decimal in hex, the way you would in ISPF browse with HEX ON.

### JCL as job scripts

`jcl/EBUPD01.jcl` is written as it would run on z/OS: IEFBR14 cleanup, `IKJEFT01` + `DSN RUN PROGRAM(...) PLAN(...)` for the DB2 steps, a DFSORT step, `COND=(8,LE)`, and `DISP=MOD` outputs for restart. `jobs/ebupd01.sh` mirrors each step. GnuCOBOL resolves `SELECT ... ASSIGN TO EBTRANS` through the environment variable `DD_EBTRANS`, so each DD statement becomes an export:

```bash
# STEP010 -- validate transactions
export DD_EBTRANS=$IN/ebtrans.dat
export DD_EBVALOUT=$WORK/ebvalout.dat
export DD_EBREJ=$OUT/ebrej.dat
step STEP010 EBVALID 8      # run unless an earlier step ended RC >= 8
```

The script exits with the highest step RC, like a job's max CC. STEP040 uses limit 12, so the report prints even after a validation RC 8.

### SORT

`EBSORT` uses the COBOL `SORT` verb with `WITH DUPLICATES IN ORDER`. The JCL shows the equivalent DFSORT card: `SORT FIELDS=(2,5,CH,A,7,4,CH,A,11,4,PD,D,1,1,CH,D),EQUALS`. A Python reader for DFSORT control statements is still an optional extra.

### DB2 behavior

- Embedded SQL is written as for DB2: host variables inside `BEGIN/END DECLARE SECTION`, null indicators, `SQLCODE` checks after every statement, `EXEC SQL INCLUDE` for members that contain SQL.
- Only SQLCODE 0 and 100 are branched on. Anything else rolls back and ends RC 12.
- **(changed)** Numeric host variables are `COMP-3`, because GixSQL mishandles binary input host variables. See `sql/db2-notes.md` for this and every other Postgres/GixSQL vs. DB2 difference found.

### ChangeMan simulation

- A package is a branch named for its change ticket: `pkg/CHG0001234-fix-zip4-edit`.
- Promotion levels are protected branches or tags: `dev` → `test` → `prod`.
- Planned: a `make promote LEVEL=test` target that runs the full regression and refuses to promote on any golden-file diff.
- Every package includes a component list (which programs and copybooks changed) and a backout note. See `tickets/CHG-TEMPLATE.md`.

### ServiceNow simulation

`tickets/INC-TEMPLATE.md` covers incidents (symptom, job, step, RC, research notes, root cause) and `tickets/CHG-TEMPLATE.md` covers change requests (description, components, test evidence, implementation and backout plans). They add period-accurate process flavor, and they read well in the repo as a record of how each bug was found and fixed.

## Build, debug, and test

The fastest local debugging loop is runtime checks plus paragraph tracing, with `gdb` in reserve. Golden-file diffs are the safety net for every change.

### Build

```bash
# plain COBOL
cobc -x -std=ibm -g -debug -fec=all -Wall -I copybooks -o bin/EBSORT src/EBSORT.cbl

# embedded SQL: precompile, patch cursor-init flags, compile
gixpp -e -S -p -E .cpy -I copybooks -I /opt/gixsql/share/gixsql/copy -i src/EBUPDT.cbl -o obj/EBUPDT.cbl
sed -i -E 's/^(GIXSQL 01  GIXSQL-CI-F-[A-Z0-9-]+) PIC X\./\1 PIC X VALUE SPACE./' obj/EBUPDT.cbl
cobc -x -std=ibm -g -debug -fec=all -Wall -I copybooks -o bin/EBUPDT obj/EBUPDT.cbl -L/opt/gixsql/lib -lgixsql

# EBVALID links EBVRULES statically
cobc -x ... -fstatic-call -o bin/EBVALID obj/EBVALID.cbl src/EBVRULES.cbl -L/opt/gixsql/lib -lgixsql
```

`make build` does all of this. `-p -E .cpy` makes gixpp expand `EXEC SQL INCLUDE` members, and the `sed` gives gixpp's generated cursor flags a `VALUE` clause. Without it, `-std=ibm` storage initialization skips every `OPEN CURSOR` (gotcha #2).

### What each flag buys you

| Flag | Effect | Mainframe parallel |
| --- | --- | --- |
| `-std=ibm` | IBM dialect rules and reserved words; storage starts as binary zeros | Enterprise COBOL compile |
| `-debug` / `-fec=all` | Runtime checks for subscripts, bad numeric data, and more | S0C7 / S0C4 abends |
| `-g` | Debug symbols for gdb | Debug Tool / IBM z/OS Debugger |
| `-ftraceall` | Compiles in statement-level tracing | READY TRACE |

`-debug` has already paid for itself. It stopped EBRPT on a numeric move of a rejected record's non-numeric edit date, which is exactly what would have been an S0C7 on the host (gotcha #9).

### Tracing

Compile with `-ftraceall`, then run with `COB_SET_TRACE=Y` and `COB_TRACE_FILE=trace.log`. The log shows every paragraph entered, which is usually enough to find a logic error in a control-break program. For SQL, set `GIXSQL_LOG_LEVEL=trace` and `GIXSQL_LOG_FILE=...`.

### Stepping with gdb

`gdb bin/EBUPDT`, then set breakpoints on the generated C functions. GnuCOBOL compiles through C, so stepping maps to C, not COBOL source lines. Treat `gdb` as the tool for crashes, and use `DISPLAY` statements plus tracing for logic bugs.

### Abend drills

Plant each defect deliberately, then find it from the output alone. The how-to for each is in `docs/operations.md`:

- A space in a COMP-3 field (data exception, the S0C7 equivalent).
- A table subscript one past its OCCURS limit.
- A missing `SQLCODE` check after a `FETCH`, so the cursor loops on the last row.
- A control-break bug that drops the final route's totals.

The restart drill is automated. `EBUPDT_ABEND_AFTER=120 make run` stops EBUPDT without committing, then `make restart` resumes from record 100 (the last commit).

### Unit tests with cobol-check

cobol-check (Open Mainframe Project) runs test suites against individual paragraphs. `tests/unit/EBVRULES/EBVRULES.cut` has 20 cases, one or more per validation rule, using `BEFORE-EACH` to build a valid record. Two adaptations were needed:
- `tests/unit/run_cut.sh` folds EBVRULES' LINKAGE SECTION into WORKING-STORAGE, so the subprogram can run as cobol-check's main program.
- `make unit` reads the results file, because cobol-check exits 0 even when a test fails.

Resequencing is covered by the regression suite and the Python oracle rather than unit tests, since it lives in SQL.

### Golden-file regression

1. Each test resets the database from `db/schema.sql` and `db/seed.sql`.
2. `jobs/ebupd01.sh` runs against the committed transaction file.
3. `tests/test_ebupd01.py` compares every output file, the job log, and a dump of `ams_address` for the changed routes against `tests/golden/`, byte for byte. It checks the job's max RC (4).
4. `tests/model.py`, an independent Python implementation of the rules, predicts the final active rows and reject counts. That checks the golden files are *right*, not just unchanged.
5. Any diff fails the build. Update golden files with `make golden`, only in a commit that explains why the output changed.

CI (GitHub Actions) builds the same Docker image, cached between runs, and runs `make ci`, so the laptop and CI give the same result.

## Four-week build plan

At a relaxed 6–8 hours a week, the full mock job runs end to end with regression tests by the end of week 3. Week 4 is for polish and the portfolio write-up. There's no deadline; stretch it out as long as it stays fun.

| Week | Focus | Deliverables | Status |
| --- | --- | --- | --- |
| 1 | Toolchain and COBOL fundamentals | Toolchain image, Postgres, GixSQL; repo skeleton and README; Z Xplore account | Done, except the Z Xplore account |
| 2 | Data and validation | `EBTRANS.cpy`, `gen_data.py` with EBCDIC mode, EBVALID/EBVRULES, SORT step, cobol-check suite, job steps 010–020 | Done |
| 3 | Database update | EBUPDT with commit/restart, resequencing, SQLCODE handling; EBRPT with cursor; golden-file regression; CI | Done |
| 4 | Process and polish | Abend drills solved from outputs alone; a mock INC and CHG; ICD for `EBTRANS`; one program on Z Xplore; write-up | ICD, runbook, and gotchas write-up done. Drills, tickets, and Z Xplore to do. |

### Week 4 incident drill

1. Have someone (or a script) plant a bug on a branch without telling you where.
2. Start from symptoms only: the job RC, the report, and the reject counts.
3. Use `rg` across `src/`, `copybooks/`, and `jcl/` to trace the affected field, the way a mainframe developer would scan libraries.
4. Write the INC ticket with root cause, then the CHG ticket, then promote the fix through `dev` → `test` → `prod`.

### ICD for `EBTRANS`

Done: [`docs/ICD-EBTRANS.md`](docs/ICD-EBTRANS.md) covers purpose, systems, frequency and volume, the field layout with offsets and valid values, encoding and record format, processing semantics, and reason codes.

## Showcasing the project

- **README:** what AMS Edit Book Update is, a diagram of `EBUPD01`, how to run it in three commands, sample output, and the mainframe-to-local mapping table. Done.
- **Sample output:** the README shows real lines of the 132-column report and an `xxd` dump of a packed record, and `tests/golden/` has the full outputs.
- **CI badge:** the README links the workflow badge. It goes live once the repo is on GitHub.
- **Write-ups:** `docs/gotchas.md` is the seed for short posts on COMP-3 and EBCDIC, commit/restart design, and GixSQL quirks. Still to come: running the same program on Z Xplore.
- **Honest framing:** described as a hobby recreation of a mainframe-style batch system, inspired by a public job posting, built with generated data.

## Limitations, risks, and next steps

The mock captures a lot of real mainframe flavor, but it's still a simulation. Say so plainly in the README.

### What the mock cannot reproduce

- z/OS operations: SDSF job output, abend dumps, dataset allocation, space abends, and GDGs.
- DB2 for z/OS specifics: BIND, packages and plans, EXPLAIN, locking behavior, and utilities.
- ChangeMan ZMF screens, approvals, and audit trail.
- Decades of undocumented business rules in the real AMS code.

### Risks

- **GixSQL quirks.** This is resolved for now: binary host variables, cursor-init flags, and autocommit all have workarounds, each in `sql/db2-notes.md`. Any upgrade from GixSQL 1.0.20b needs a rerun of `make ci` and a check that those workarounds are still needed.
- **Dialect drift.** Code that compiles under GnuCOBOL may fail under Enterprise COBOL. Fallback: port one program per week to Z Xplore, starting with EBVRULES and EBSORT (no SQL).
- **Scope creep.** VSAM, GDG simulation, and a CICS-style front end are all tempting. The four-step job is finished; add extras as separate stretch goals.
- **Toolchain drift.** The image pins GnuCOBOL, GixSQL, cobol-check (by commit), and uv. The Debian base (`trixie-slim`) and apt packages are not pinned, so a CI failure after a quiet period may come from the base image.

### Stretch ideas

- A VSAM-style indexed file for route lookups instead of the database.
- A generation data group (GDG) simulation for rolling daily outputs.
- A small 3270-style screen (for example, with a TUI library) to browse the edit book.
- `tools/sort.py`, a reader for DFSORT control statements, to drive STEP020 from the same card as the JCL.

### Next steps

- [x] Build the toolchain and confirm `cobc --version` (GnuCOBOL 3.2.0 in the image).
- [x] Create the repo layout, README, `EBTRANS.cpy`, and `gen_data.py`.
- [x] Programs, job script, reference JCL, regression suite, CI workflow.
- [ ] Publish the repo to GitHub and confirm the first CI run is green.
- [ ] Register for IBM Z Xplore and port EBVRULES.
- [ ] Run the four abend drills and write INC/CHG tickets for each.
- [ ] Add `make promote LEVEL=...`.
- [ ] Turn `docs/gotchas.md` into short blog posts.
