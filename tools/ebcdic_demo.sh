#!/usr/bin/env bash
# Why a blind EBCDIC->ASCII conversion corrupts packed-decimal fields.
#
# 1. Write a host-format (EBCDIC) copy of the transaction file.
# 2. Convert it back two ways: field-aware (correct) and blind (the bug).
# 3. Show the delivery-sequence bytes of the first record for each.
set -euo pipefail
cd "$(dirname "$0")/.."
W=data/work/ebcdic
mkdir -p "$W"

python3 tools/gen_data.py --ebcdic -s "$W/seed.sql" -t "$W/ebtrans.ebc" > /dev/null
python3 tools/ebcdic.py to-ascii "$W/ebtrans.ebc" "$W/field-aware.dat"
python3 tools/ebcdic.py blind    "$W/ebtrans.ebc" "$W/blind.dat"

echo
echo "== first record, original ASCII file (what the job reads)"
xxd -s 0 -l 20 data/in/ebtrans.dat
echo "== same record in EBCDIC: text bytes change (A=x'C1'), packed bytes do not"
xxd -s 0 -l 20 "$W/ebtrans.ebc"
echo "== blind whole-record conversion: the packed field at offset 10 is mangled"
xxd -s 0 -l 20 "$W/blind.dat"
echo
if cmp -s data/in/ebtrans.dat "$W/field-aware.dat"; then
    echo "field-aware round trip: identical to the original"
else
    echo "field-aware round trip: DIFFERS (bug)"; exit 1
fi
echo "blind conversion: $(cmp -l data/in/ebtrans.dat "$W/blind.dat" | wc -l | tr -d ' ') bytes differ"
echo
python3 tools/ebcdic.py dump "$W/blind.dat" -n 2
