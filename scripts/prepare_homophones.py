#!/usr/bin/env python3
"""Rebuild the offline, tone-sensitive Mandarin index from pinned Unihan data."""
from pathlib import Path
import hashlib
import json
import unicodedata

ROOT = Path(__file__).resolve().parents[1]
SOURCE_SHA256 = "575e69c9ad85a4737a889a4f94cbd987042a90a1a6cc16dd3f4ed995c715b17c"


def main():
    source = ROOT / "ThirdParty/Unicode/Unihan_Readings.txt"
    assert hashlib.sha256(source.read_bytes()).hexdigest() == SOURCE_SHA256
    table = json.loads((ROOT / "Resources/boshiamy.json").read_text())
    supported = {word for words in table["entries"].values() for word in words if len(word) == 1}
    readings = {}
    for line in source.read_text().splitlines():
        if not line.startswith("U+"):
            continue
        scalar, field, value = line.split("\t", 2)
        character = chr(int(scalar[2:], 16))
        if character not in supported or field not in {"kMandarin", "kHanyuPinyin"}:
            continue
        pronunciations = value.split() if field == "kMandarin" else [
            reading for item in value.split() for reading in item.split(":", 1)[1].split(",")
        ]
        readings.setdefault(character, set()).update(
            unicodedata.normalize("NFC", reading.lower()) for reading in pronunciations
        )
    groups = {}
    for character in sorted(readings):
        for reading in sorted(readings[character]):
            groups.setdefault(reading, []).append(character)
    result = {"version": 1, "readings": {c: sorted(v) for c, v in sorted(readings.items())},
              "groups": dict(sorted(groups.items()))}
    output = ROOT / "Resources/homophones.json"
    output.write_text(json.dumps(result, ensure_ascii=False, separators=(",", ":")) + "\n")
    print(f"{len(readings)} characters, {len(groups)} tone-sensitive reading groups; {output.stat().st_size} bytes")


if __name__ == "__main__":
    main()
