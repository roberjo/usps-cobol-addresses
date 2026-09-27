# Interface Control Document: `EBTRANS` edit book transactions

| | |
| --- | --- |
| Interface | `EBTRANS`: carrier edit book annotations |
| Producing system | Edit book capture (mock: `tools/gen_data.py`) |
| Consuming system | Job `EBUPD01`, step `STEP010` (`EBVALID`) |
| Frequency | Daily, one file per cycle |
| Typical volume | Hundreds to low thousands of records per cycle (mock: 210) |
| Copybook | [`copybooks/EBTRANS.cpy`](../copybooks/EBTRANS.cpy) |
| Status | Draft for the hobby mock. Not a real USPS interface. |

## 1. Purpose

Each record is one change a carrier marked on a printed route listing (an
*edit book*): a new delivery point, a vacated or demolished one, or a
correction to an existing one. `EBUPD01` validates the records, applies them to
the `ams_address` master in delivery order, and prints updated books.

## 2. Dataset characteristics

| Property | Value |
| --- | --- |
| Host dataset name | `AMS.EB.EBTRANS.DAILY(0)`, a GDG with one generation per cycle |
| Record format | `RECFM=FB`, `LRECL=80` |
| Encoding on the host | EBCDIC, code page 037 |
| Encoding in the mock | ASCII/Latin-1 text; packed fields are binary in both |
| Line terminators | None. The file is a byte stream of 80-byte records. |
| Order | None required. `EBSORT` orders the records. |

When the file is moved between host and workstation, convert text fields only
(`tools/ebcdic.py to-ascii`). A whole-record translation, such as an FTP
ASCII-mode transfer, corrupts the packed `EBT-DLVY-SEQ` field. See
`make ebcdic-demo`.

## 3. Record layout

Offsets are 1-based, as in DFSORT control statements.

| # | Field | Offset | Length | COBOL picture | Type | Valid values / rule | Reason if invalid |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `EBT-ACTION-CD` | 1 | 1 | `X(1)` | text | `A` add, `C` change, `D` delete | 01 |
| 2 | `EBT-ZIP5` | 2 | 5 | `X(5)` | text | 5 digits | 02 |
| 3 | `EBT-ROUTE-ID` | 7 | 4 | `X(4)` | text | Must exist on `ams_route` for this ZIP5; `Cnnn` city, `Rnnn` rural | 04 blank, 07 unknown |
| 4 | `EBT-DLVY-SEQ` | 11 | 4 | `S9(7) COMP-3` | packed | Valid packed decimal, > 0. The position in the book *as printed*. | 08 |
| 5 | `EBT-PRIMARY-NBR` | 15 | 10 | `X(10)` | text | Required for every action. For `D`, must match the address at that sequence. | 04, 12 |
| 6 | `EBT-STREET-NAME` | 25 | 28 | `X(28)` | text | Required for `A` and `C` | 04 |
| 7 | `EBT-UNIT` | 53 | 8 | `X(8)` | text | Optional. Blank is stored as NULL. | – |
| 8 | `EBT-ZIP4` | 61 | 4 | `X(4)` | text | Blank, or 4 digits. Blank is stored as NULL. | 03 |
| 9 | `EBT-CARRIER-ID` | 65 | 6 | `X(6)` | text | Required | 04 |
| 10 | `EBT-EDIT-DATE` | 71 | 8 | `9(8)` | zoned | `YYYYMMDD`, a real calendar date, not after `RUNDATE` | 05, 06 |
| 11 | `FILLER` | 79 | 2 | `X(2)` | – | Spaces | – |

Text fields 3, 5, 6, 7, and 9 must not contain `LOW-VALUES` (`x'00'`) or
`HIGH-VALUES` (`x'FF'`). That is reason 09.

### Packed decimal example

`EBT-DLVY-SEQ` = +119 is stored as the four bytes `x'0000119C'`: seven digits,
one per nibble, then the sign nibble (`C` positive, `D` negative, `F`
unsigned). Spaces (`x'40404040'` in EBCDIC, `x'20202020'` in ASCII) are not
valid packed data. On z/OS, arithmetic on them raises an S0C7 data exception.
`EBVRULES` tests `IS NUMERIC` first and rejects the record with reason 08.

## 4. Processing semantics

- Records are applied per route from the highest sequence down (`EBSORT` keys:
  ZIP5 ascending, route ascending, sequence descending, action descending).
  Every sequence number therefore still refers to the book the carrier saw,
  even after an add shifts later addresses up.
- **D**: soft delete (`status_cd = 'D'`). The address keeps its row for
  history, and its position is freed.
- **C**: replaces primary number, street, unit, and ZIP+4 at that position.
- **A**: inserts at that position. If the position is occupied, every active
  address at or above it moves up by one.
- An add that duplicates an active address on the route (same primary number,
  street, and unit) is rejected with reason 11.

## 5. Error handling

| Reason | Meaning | Set by |
| --- | --- | --- |
| 01 | Invalid action code | EBVALID |
| 02 | ZIP5 not numeric | EBVALID |
| 03 | ZIP4 not numeric | EBVALID |
| 04 | Required field missing | EBVALID |
| 05 | Edit date invalid | EBVALID |
| 06 | Edit date after run date | EBVALID |
| 07 | Route not on `ams_route` | EBVALID |
| 08 | Delivery sequence invalid (bad packed data, zero, negative) | EBVALID |
| 09 | LOW/HIGH-VALUES in a text field | EBVALID |
| 10 | No active address at that sequence (C/D) | EBUPDT |
| 11 | Duplicate active address (A) | EBUPDT |
| 12 | Primary number does not match the address at that sequence (D) | EBUPDT |

Rejected records are written unchanged, followed by the 2-byte reason code, to
`EBREJ` (from EBVALID) or `EBUREJ` (from EBUPDT). Both are 82-byte fixed
records ([`copybooks/EBREJ.cpy`](../copybooks/EBREJ.cpy)). If more than
`REJMAX` percent of the file fails validation, the job ends RC 8 and nothing is
applied. The producing system is expected to correct and resend.

## 6. Contacts

Hobby project: open an issue in this repository.
