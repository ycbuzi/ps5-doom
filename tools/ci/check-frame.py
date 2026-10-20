"""Checks that a host capture (frame%05d.raw: palette indices for the picture, then 256 uint32
colours) shows the test add-on's title: one colour per quadrant, read at the quadrant centres.

    check-frame.py <frame.raw> <info.json>
"""
import json
import sys

raw_path, info_path = sys.argv[1], sys.argv[2]
raw = open(raw_path, "rb").read()
info = json.load(open(info_path))
width, height = info["size"]
if len(raw) != width * height + 256 * 4:
    sys.exit(f"{raw_path}: {len(raw)} bytes, not a {width}x{height} capture")
expected = info["palette_index"]
centres = {"top-left": (width // 4, height // 4), "top-right": (3 * width // 4, height // 4),
           "bottom-left": (width // 4, 3 * height // 4), "bottom-right": (3 * width // 4, 3 * height // 4)}
bad = []
for name, (x, y) in centres.items():
    colour = info["quadrants"][name]
    got = raw[y * width + x]
    if got != expected[colour]:
        bad.append(f"{name} at ({x}, {y}): palette index {got}, expected {expected[colour]} ({colour})")
if bad:
    sys.exit(f"{raw_path}: not the add-on's title\n" + "\n".join(bad))
print(f"{raw_path}: the add-on's title, all four quadrants")
