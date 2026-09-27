# CHG0000000 — <what changes>

| Field | Value |
| --- | --- |
| Requested | YYYY-MM-DD |
| Related INC | INC0000000 |
| Package branch | `pkg/CHG0000000-<slug>` |
| Risk | Low / Medium / High |
| Implementation window | |

## Description
What changes and why.

## Components
| Type | Member | Change |
| --- | --- | --- |
| Program | `src/EBVRULES.cbl` | |
| Copybook | | |
| JCL / job | | |
| Control cards | | |
| Golden files | `tests/golden/...` | Expected change and why |

## Test evidence
- `make ci` output (lint, cobol-check, pytest)
- New or changed unit test cases
- Golden-file diff reviewed: yes / no change

## Implementation plan
1. Merge the package branch to `test`, run `make ci`.
2. Promote to `prod`.
3. Monitor the next EBUPD01 run: RC, reject counts.

## Backout plan
Revert the package commit(s) and rerun `make ci`. If the job already ran with
the change, describe the data repair needed.
