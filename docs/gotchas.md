# Gotchas found while building EBUPD01

Notes on what broke, how it showed up, and the fix. Most of these are classic
mainframe lessons that turn up just as readily on a laptop.

## 1. The report step killed its own shell

**Symptom.** STEP030 or STEP040 started, then the whole container shell
disappeared: no RC, no "ENDED" line. Under `ulimit -v`, the same run ended
RC 12 with SQLSTATE `08P01` ("insufficient data left in message").

**Cause.** The numeric host variables were `PIC S9(9) COMP`. GixSQL 1.0.20b
sends binary input host variables to PostgreSQL wrongly, so the server got
malformed parameters. The silent exit without a memory limit is most likely
the client allocating a garbage length and being OOM-killed in the 2 GB Docker
VM. That part wasn't confirmed; it went away with the fix.

**Fix.** All numeric host variables are `COMP-3`, which DB2 also accepts. A
small probe program compared `COMP`, `COMP-5`, and `COMP-3`, and only packed
worked. See `sql/db2-notes.md`.

## 2. OPEN CURSOR silently did nothing

**Symptom.** The first FETCH returned SQLCODE −111, "no such cursor".

**Cause.** `-std=ibm` makes WORKING-STORAGE start as binary zeros, as on z/OS
where it isn't initialized. The code gixpp generates keeps a per-cursor flag
`PIC X` with no `VALUE` and only opens the cursor when the flag is a space.
Under IBM rules it was `x'00'`, so the OPEN was skipped.

**Fix.** The Makefile patches `VALUE SPACE` onto those generated flags after
precompiling. Our own code keeps IBM behavior, so every switch and counter has
an explicit `VALUE` or is `INITIALIZE`d, as it should on the host anyway.

## 3. Every statement was its own unit of work

**Symptom.** Each `COMMIT` printed `WARNING: there is no transaction in progress`.

**Cause.** The GixSQL connection was effectively autocommitting, so the
commit/restart design would have been meaningless: a crash would leave
half-applied work behind with no checkpoint to match.

**Fix.** Add `?autocommit=off` to the data source. The restart drill test
proves the rollback now happens: records 101–120 disappear after the simulated
abend.

## 4. Resequencing needs to look backwards

The first design sorted each route in *ascending* sequence. An add at position
10 shifts positions 10+ up by one, so a later delete "at position 50" would hit
the address that used to be at 49. Processing each route from the highest
sequence down (sort key `seq D`) means a shift only moves positions that are
already done. Every sequence number in the file keeps its printed-book meaning.
Descending action order then gives D, C, A at the same position, so a delete
frees a slot before an add reuses it.

## 5. `UPDATE ... SET seq = seq + 1` can trip the unique index

With a unique index on (route, seq), a single-statement shift can collide
mid-statement, depending on the physical order rows are visited. EBUPDT
negates the block (`-(seq+1)`) and then flips it back, so no two rows ever
share a value.

## 6. Restart doesn't reproduce identity values

After an abend and restart, everything matched a clean run *except* `addr_id`
on later inserts. Sequence and identity values are handed out outside the
transaction, and the rolled-back inserts had already used some. DB2 does the
same. The test ignores the id field on restart; any design that needs
gap-free keys has to generate them itself.

## 7. Partial outputs vs. a careless resubmit

If an operator resubmits from the top after an abend, the IEFBR14-style cleanup
deletes the audit records that belong to the committed work. STEP000 now
refuses to run while `eb_checkpoint` shows an unfinished run. The restart path
trims the audit and reject files back to the counts saved in the checkpoint,
the local version of restarting with `DISP=MOD` datasets.

## 8. Column 73 is a comment

In fixed-format COBOL, columns 73–80 were card sequence numbers, and the
compiler ignores them. A line that drifts one character too long loses its last
character *silently*. `make lint` fails the build on any line past column 72.
It caught two report literals and one comment during development.

## 9. `-debug` found a real S0C7 in the report program

EBRPT moved the edit date (`PIC 9(8)`) of a *rejected* record into the print
line. For the record with date `2026SEPT`, that is a numeric move of
non-numeric data: an S0C7 on z/OS, and a libcob runtime error with `-debug`.
Reject listings must treat every field of a rejected record as untrusted. The
fix prints the date through an alphanumeric `REDEFINES`
(`EBT-EDIT-DATE-X`), and the packed sequence is shown as `*BADPK*` when it
fails `IS NUMERIC`.

## 10. EBCDIC conversion must be field-aware

`make ebcdic-demo` converts the transaction file to code page 037 and back. A
field-aware conversion round-trips exactly. A blind whole-record conversion
turns the packed `x'0000119C'` (+119) into `x'000011E6'`, which is not packed
decimal at all, and changes 279 bytes across the file.
