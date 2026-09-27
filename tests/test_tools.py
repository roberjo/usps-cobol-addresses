"""Unit tests for the Python tooling (no database or COBOL needed)."""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import ebcdic  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]


@pytest.mark.parametrize("value,packed", [(0, "0000000C"), (119, "0000119C"),
                                          (9999999, "9999999C"), (-4, "0000004D")])
def test_pack_comp3(value, packed):
    assert ebcdic.pack_comp3(value, 4).hex().upper() == packed
    assert ebcdic.unpack_comp3(bytes.fromhex(packed)) == value


def test_unpack_rejects_bad_packed_data():
    assert ebcdic.unpack_comp3(b"    ") is None          # spaces: the S0C7 case
    assert ebcdic.unpack_comp3(bytes.fromhex("000011E6")) is None


def test_pack_overflow():
    with pytest.raises(ValueError):
        ebcdic.pack_comp3(10_000_000, 4)


def test_layout_is_80_bytes():
    assert ebcdic.RECLEN == 80


def test_field_aware_round_trip():
    data = (ROOT / "data" / "in" / "ebtrans.dat").read_bytes()
    host = b"".join(ebcdic.encode_record(r) for r in ebcdic.records(data))
    back = b"".join(ebcdic.decode_record(r) for r in ebcdic.records(host))
    assert back == data
    assert host[0] == 0xC1                                  # 'A' in cp037


def test_blind_conversion_corrupts_packed_fields():
    data = (ROOT / "data" / "in" / "ebtrans.dat").read_bytes()
    host = b"".join(ebcdic.encode_record(r) for r in ebcdic.records(data))
    blind = host.decode("cp037").encode("latin-1")
    bad = [ebcdic.unpack_comp3(r[10:14]) for r in ebcdic.records(blind)]
    assert bad.count(None) > len(bad) // 2
