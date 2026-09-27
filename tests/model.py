"""Independent Python model of EBUPD01's business rules.

The regression suite runs the COBOL job and compares its database result with
what this model predicts from the same inputs. Golden files catch *any* change
in output; this model checks that the output is actually *right*.
"""
from __future__ import annotations

import datetime as dt
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


@dataclass(frozen=True)
class Trans:
    raw: bytes
    action: str
    zip5: str
    route: str
    seq: int | None          # None = invalid packed decimal
    primary: str
    street: str
    unit: str
    zip4: str
    carrier: str
    date: str


def unpack(raw: bytes) -> int | None:
    h = raw.hex().upper()
    if not h[:-1].isdigit() or h[-1] not in "ABCDEF":
        return None
    return -int(h[:-1]) if h[-1] in "BD" else int(h[:-1])


def read_trans(path: Path) -> list[Trans]:
    data = path.read_bytes()
    out = []
    for i in range(0, len(data), 80):
        r = data[i:i + 80]
        t = lambda a, b: r[a:b].decode("latin-1")
        out.append(Trans(r, t(0, 1), t(1, 6), t(6, 10), unpack(r[10:14]), t(14, 24),
                         t(24, 52), t(52, 60), t(60, 64), t(64, 70), t(70, 78)))
    return out


def read_seed(path: Path):
    """Return (routes set, rows list[dict]) from the COPY blocks in seed.sql."""
    routes, rows, block = set(), [], None
    for line in path.read_text().splitlines():
        if line.startswith("COPY ams_route"):
            block = "route"
        elif line.startswith("COPY ams_address"):
            block = "addr"
        elif line == "\\.":
            block = None
        elif block == "route":
            z, r, _ = line.split("\t")
            routes.add((z, r))
        elif block == "addr":
            z, z4, r, seq, p, s, u, st = line.split("\t")
            rows.append(dict(addr_id=len(rows) + 1, zip5=z, route=r, seq=int(seq),
                             primary=p, street=s, unit=None if u == "\\N" else u,
                             zip4=None if z4 == "\\N" else z4, status=st))
    return routes, rows


def validate(t: Trans, rundate: str, routes: set) -> str:
    """Mirror of EBVRULES + the EBVALID route lookup. Returns '00' or a reason."""
    if t.action not in "ACD" or len(t.action) != 1:
        return "01"
    if not t.zip5.isdigit():
        return "02"
    if t.zip4.strip() and not t.zip4.isdigit():
        return "03"
    if any(c in "\x00\xff" for c in t.route + t.primary + t.street + t.unit + t.carrier):
        return "09"
    if not t.route.strip() or not t.primary.strip() or not t.carrier.strip():
        return "04"
    if t.action in "AC" and not t.street.strip():
        return "04"
    if not t.date.isdigit():
        return "05"
    try:
        dt.datetime.strptime(t.date, "%Y%m%d")
    except ValueError:
        return "05"
    if t.date > rundate:
        return "06"
    if t.seq is None or t.seq <= 0:
        return "08"
    if (t.zip5, t.route) not in routes:
        return "07"
    return "00"


def norm(v: str) -> str | None:
    v = v.rstrip()
    return v or None


def apply(trans: list[Trans], rows: list[dict]) -> dict[str, int]:
    """Apply sorted valid transactions to rows in place; return reject counts."""
    # EBSORT: ZIP5/route ascending, sequence then action descending, stable.
    order = sorted(trans, key=lambda t: (-t.seq, -ord(t.action)))
    order = sorted(order, key=lambda t: (t.zip5, t.route))
    rejects: dict[str, int] = {}
    next_id = max(r["addr_id"] for r in rows) + 1

    def active(z, r):
        return [x for x in rows if x["zip5"] == z and x["route"] == r and x["status"] == "A"]

    for t in order:
        route_rows = active(t.zip5, t.route)
        at = [x for x in route_rows if x["seq"] == t.seq]
        reason = "00"
        if t.action == "D":
            if not at:
                reason = "10"
            elif at[0]["primary"] != t.primary.rstrip():
                reason = "12"
            else:
                at[0]["status"] = "D"
        elif t.action == "C":
            if not at:
                reason = "10"
            else:
                at[0].update(primary=t.primary.rstrip(), street=t.street.rstrip(),
                             unit=norm(t.unit), zip4=norm(t.zip4))
        else:
            dup = [x for x in route_rows if x["primary"] == t.primary.rstrip()
                   and x["street"] == t.street.rstrip() and x["unit"] == norm(t.unit)]
            if dup:
                reason = "11"
            else:
                if at:
                    for x in route_rows:
                        if x["seq"] >= t.seq:
                            x["seq"] += 1
                rows.append(dict(addr_id=next_id, zip5=t.zip5, route=t.route, seq=t.seq,
                                 primary=t.primary.rstrip(), street=t.street.rstrip(),
                                 unit=norm(t.unit), zip4=norm(t.zip4), status="A"))
                next_id += 1
        if reason != "00":
            rejects[reason] = rejects.get(reason, 0) + 1
    return rejects


def expected(rundate: str = "20261005"):
    """Run the model over the committed inputs. Returns (rows, reject_counts)."""
    routes, rows = read_seed(ROOT / "db" / "seed.sql")
    trans = read_trans(ROOT / "data" / "in" / "ebtrans.dat")
    rejects: dict[str, int] = {}
    valid = []
    for t in trans:
        r = validate(t, rundate, routes)
        if r == "00":
            valid.append(t)
        else:
            rejects[r] = rejects.get(r, 0) + 1
    for k, v in apply(valid, rows).items():
        rejects[k] = rejects.get(k, 0) + v
    return rows, rejects
