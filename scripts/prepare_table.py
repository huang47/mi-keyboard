"""Convert the pinned Fcitx5 data offline; no network or input downloads."""
from pathlib import Path
import hashlib
import json
import struct

root = Path(__file__).resolve().parents[1]
source = root / "ThirdParty/Fcitx5/boshiamy.txt"
metadata = json.loads((source.parent / "SOURCE.json").read_text())
raw = source.read_bytes()
assert hashlib.sha256(raw).hexdigest() == metadata["sha256"], "Pinned table checksum mismatch"
entries = {}
started = False
allowed = set("abcdefghijklmnopqrstuvwxyz,.'[]")
for number, line in enumerate(raw.decode("utf-8").splitlines(), 1):
    if line == "[数据]":
        started = True
        continue
    if not started or not line.strip():
        continue
    code, word = line.split(maxsplit=1)
    assert set(code) <= allowed and len(code) <= 16, f"Unsupported code at {number}"
    values = entries.setdefault(code, [])
    if word not in values:
        values.append(word)
assert len(entries) > 20000, "Incomplete table"
out = root / "Resources/boshiamy.json"
out.parent.mkdir(exist_ok=True)
name = "Fcitx5 嘸蝦米字表"
out.write_text(json.dumps({"version": 1, "name": name, "entries": entries}, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n")
# BSMY1: entry count (u32), UTF-8 name length (u32), name, then sorted entries.
# Each entry stores code length (u8), code, candidate count (u16), and length-prefixed UTF-8 candidates (u32).
packed = bytearray(b"BSMY1")
name_bytes = name.encode("utf-8")
packed += struct.pack("<II", len(entries), len(name_bytes)) + name_bytes
for code in sorted(entries):
    code_bytes = code.encode("utf-8")
    words = entries[code]
    assert 1 <= len(code_bytes) <= 16 and 1 <= len(words) <= 1000
    packed += struct.pack("<B", len(code_bytes)) + code_bytes + struct.pack("<H", len(words))
    for word in words:
        word_bytes = word.encode("utf-8")
        packed += struct.pack("<I", len(word_bytes)) + word_bytes
out.with_suffix(".bin").write_bytes(packed)
print(f"Prepared {len(entries)} codes, {sum(map(len, entries.values()))} pairs, {len(set(w for ws in entries.values() for w in ws))} unique outputs")
