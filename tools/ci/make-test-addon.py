"""Makes a one-lump test add-on: a TITLEPIC in four flat colours (red, green, blue, white, one per
quadrant), using the nearest colours in the given IWAD's palette. Writes the palette indices to a JSON
file for check-frame.py.

    make-test-addon.py <iwad> <out.wad> <info.json>
"""
import json
import struct
import sys

iwad_path, out_path, info_path = sys.argv[1], sys.argv[2], sys.argv[3]
data = open(iwad_path, "rb").read()
ident, count, table = struct.unpack_from("<4sii", data, 0)
assert ident == b"IWAD", ident
lumps = {}
for i in range(count):
    pos, size, raw = struct.unpack_from("<ii8s", data, table + 16 * i)
    lumps.setdefault(raw.rstrip(b"\0").decode("ascii", "replace").upper(), (pos, size))

pos, size = lumps["PLAYPAL"]
palette = [tuple(data[pos + 3 * i:pos + 3 * i + 3]) for i in range(256)]
width, height = 320, 200


def nearest(rgb):
    return min(range(256), key=lambda i: sum((a - b) ** 2 for a, b in zip(palette[i], rgb)))


targets = {"red": (255, 0, 0), "green": (0, 255, 0), "blue": (0, 0, 255), "white": (255, 255, 255)}
index = {k: nearest(v) for k, v in targets.items()}
quadrant = {(0, 0): "red", (1, 0): "green", (0, 1): "blue", (1, 1): "white"}


def pixel(x, y):
    return index[quadrant[(x >= width // 2, y >= height // 2)]]


columns = []
for x in range(width):
    column = bytes([0, height, 0]) + bytes(pixel(x, y) for y in range(height)) + bytes([0, 0xFF])
    columns.append(column)
header = struct.pack("<HHhh", width, height, 0, 0)
offset = len(header) + 4 * width
offsets, body = [], b""
for column in columns:
    offsets.append(offset + len(body))
    body += column
picture = header + b"".join(struct.pack("<I", o) for o in offsets) + body

directory_offset = 12 + len(picture)
pwad = struct.pack("<4sii", b"PWAD", 1, directory_offset) + picture + struct.pack("<ii8s", 12, len(picture), b"TITLEPIC")
open(out_path, "wb").write(pwad)

info = {"palette_index": index, "palette_rgb": {k: palette[v] for k, v in index.items()},
        "quadrants": {"top-left": "red", "top-right": "green", "bottom-left": "blue", "bottom-right": "white"},
        "bytes": len(pwad), "size": [width, height]}
json.dump(info, open(info_path, "w"), indent=1)
print(json.dumps(info))
