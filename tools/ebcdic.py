#!/usr/bin/env python3
"""Field-aware EBCDIC <-> ASCII conversion for EBTRANS records, and COMP-3 helpers.

Mainframe files arrive in EBCDIC (code page 037). Text fields must be translated,
but packed-decimal (COMP-3) bytes are binary and must be copied untouched. A blind
whole-record translation (what a naive FTP ASCII transfer does) corrupts them.

Usage:
  python tools/ebcdic.py to-ascii  IN OUT     # field-aware, safe
  python tools/ebcdic.py to-ebcdic IN OUT     # field-aware, safe
  python tools/ebcdic.py blind     IN OUT     # whole-record cp037 decode (the bug)
  python tools/ebcdic.py dump IN [--ebcdic] [-n 5]   # show fields + packed hex
"""
from __future__ import annotations

import argparse
from pathlib import Path

# (field, length, kind) in record order -- mirrors copybooks/EBTRANS.cpy
EBTRANS_LAYOUT: list[tuple[str, int, str]] = [
    ("EBT-ACTION-CD", 1, "text"),
    ("EBT-ZIP5", 5, "text"),
    ("EBT-ROUTE-ID", 4, "text"),
    ("EBT-DLVY-SEQ", 4, "comp3"),   # PIC S9(7) COMP-3
    ("EBT-PRIMARY-NBR", 10, "text"),
    ("EBT-STREET-NAME", 28, "text"),
    ("EBT-UNIT", 8, "text"),
    ("EBT-ZIP4", 4, "text"),
    ("EBT-CARRIER-ID", 6, "text"),
    ("EBT-EDIT-DATE", 8, "text"),
    ("FILLER", 2, "text"),
]
RECLEN = sum(n for _, n, _ in EBTRANS_LAYOUT)


def pack_comp3(value: int, length: int) -> bytes:
    """Pack an int as COMP-3: one digit per nibble, sign nibble last (C=+, D=-)."""
    digits = 2 * length - 1
    s = f"{abs(value):0{digits}d}"
    if len(s) > digits:
        raise ValueError(f"{value} does not fit in {length} packed bytes")
    return bytes.fromhex(s + ("D" if value < 0 else "C"))


def unpack_comp3(raw: bytes) -> int | None:
    """Return the value, or None when the bytes are not valid packed decimal (S0C7)."""
    h = raw.hex().upper()
    digits, sign = h[:-1], h[-1]
    if not digits.isdigit() or sign not in "ABCDEF":
        return None
    return -int(digits) if sign in "BD" else int(digits)


def _convert(rec: bytes, layout, src: str, dst: str) -> bytes:
    out, pos = bytearray(), 0
    for _, n, kind in layout:
        chunk = rec[pos:pos + n]
        out += chunk if kind == "comp3" else chunk.decode(src).encode(dst)
        pos += n
    return bytes(out)


def encode_record(rec: bytes, layout=EBTRANS_LAYOUT) -> bytes:
    return _convert(rec, layout, "latin-1", "cp037")


def decode_record(rec: bytes, layout=EBTRANS_LAYOUT) -> bytes:
    return _convert(rec, layout, "cp037", "latin-1")


def records(data: bytes, reclen: int = RECLEN):
    if len(data) % reclen:
        raise SystemExit(f"file length {len(data)} is not a multiple of LRECL {reclen}")
    for i in range(0, len(data), reclen):
        yield data[i:i + reclen]


def dump(path: Path, ebcdic: bool, n: int) -> None:
    for i, rec in enumerate(records(path.read_bytes())):
        if i >= n:
            break
        pos, parts = 0, []
        for name, length, kind in EBTRANS_LAYOUT:
            chunk = rec[pos:pos + length]
            pos += length
            if kind == "comp3":
                val = unpack_comp3(chunk)
                parts.append(f"{name}=x'{chunk.hex().upper()}'({'INVALID' if val is None else val})")
            elif name != "FILLER":
                text = chunk.decode("cp037" if ebcdic else "latin-1")
                parts.append(f"{name}={text!r}")
        print(f"#{i + 1}: " + " ".join(parts))


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    for cmd in ("to-ascii", "to-ebcdic", "blind"):
        p = sub.add_parser(cmd)
        p.add_argument("src", type=Path)
        p.add_argument("dst", type=Path)
    p = sub.add_parser("dump")
    p.add_argument("src", type=Path)
    p.add_argument("--ebcdic", action="store_true")
    p.add_argument("-n", type=int, default=5)
    a = ap.parse_args()

    if a.cmd == "dump":
        dump(a.src, a.ebcdic, a.n)
        return
    data = a.src.read_bytes()
    if a.cmd == "blind":
        out = data.decode("cp037").encode("latin-1")
    else:
        fn = decode_record if a.cmd == "to-ascii" else encode_record
        out = b"".join(fn(r) for r in records(data))
    a.dst.parent.mkdir(parents=True, exist_ok=True)
    a.dst.write_bytes(out)
    print(f"{a.cmd}: {len(data) // RECLEN} records -> {a.dst}")


if __name__ == "__main__":
    main()
