"""Minimal Xcursor reader/writer.

The Xcursor container is simple enough to write directly, which means the neu
cursor theme builds with nothing installed beyond rsvg-convert -- no xcursorgen,
no clickgen, no sudo. Verified by round-tripping every real cursor file in
/usr/share/icons/Adwaita byte-for-byte (see `selftest`).

Layout, all little-endian u32:
    header   magic "Xcur", header size (16), version (0x10000), ntoc
    toc[n]   type, subtype, byte position
    chunk    header size (36), type, subtype, chunk version, width, height,
             xhot, yhot, delay(ms), then width*height ARGB pixels
"""

from __future__ import annotations

import struct

MAGIC = b"Xcur"
TYPE_IMAGE = 0xFFFD0002
TYPE_COMMENT = 0xFFFE0001
IMAGE_HEADER = 36


class Image:
    __slots__ = ("nominal", "width", "height", "xhot", "yhot", "delay", "pixels")

    def __init__(self, nominal, width, height, xhot, yhot, delay, pixels):
        self.nominal = nominal
        self.width = width
        self.height = height
        self.xhot = xhot
        self.yhot = yhot
        self.delay = delay
        self.pixels = pixels  # bytes, width*height*4, ARGB little-endian


def parse(data: bytes) -> list[Image]:
    magic, hdr, _ver, ntoc = struct.unpack_from("<4sIII", data, 0)
    if magic != MAGIC:
        raise ValueError("not an Xcursor file")
    out = []
    for i in range(ntoc):
        ctype, _sub, pos = struct.unpack_from("<III", data, hdr + i * 12)
        if ctype != TYPE_IMAGE:
            continue
        (_ch, _ct, nominal, _cv, w, h, xh, yh,
         delay) = struct.unpack_from("<9I", data, pos)
        px = data[pos + IMAGE_HEADER: pos + IMAGE_HEADER + w * h * 4]
        out.append(Image(nominal, w, h, xh, yh, delay, px))
    return out


def build(images: list[Image]) -> bytes:
    ntoc = len(images)
    header = struct.pack("<4sIII", MAGIC, 16, 0x00010000, ntoc)
    toc_size = ntoc * 12
    pos = 16 + toc_size

    toc, chunks = b"", b""
    for im in images:
        toc += struct.pack("<III", TYPE_IMAGE, im.nominal, pos)
        chunk = struct.pack("<9I", IMAGE_HEADER, TYPE_IMAGE, im.nominal, 1,
                            im.width, im.height, im.xhot, im.yhot, im.delay)
        chunk += im.pixels
        chunks += chunk
        pos += len(chunk)
    return header + toc + chunks


def rgba_to_argb(rgba: bytes) -> bytes:
    """rsvg-convert gives straight RGBA; Xcursor wants premultiplied ARGB."""
    out = bytearray(len(rgba))
    for i in range(0, len(rgba), 4):
        r, g, b, a = rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]
        out[i + 0] = b * a // 255
        out[i + 1] = g * a // 255
        out[i + 2] = r * a // 255
        out[i + 3] = a
    return bytes(out)


def selftest(theme_dir: str = "/usr/share/icons/Adwaita/cursors") -> int:
    """Round-trip every real cursor in a theme. Returns the number checked."""
    import pathlib
    ok = bad = 0
    for f in sorted(pathlib.Path(theme_dir).iterdir()):
        if f.is_symlink() or not f.is_file():
            continue
        data = f.read_bytes()
        try:
            if build(parse(data)) == data:
                ok += 1
            else:
                bad += 1
                print(f"  MISMATCH {f.name}")
        except Exception as e:
            bad += 1
            print(f"  ERROR {f.name}: {e}")
    print(f"round-trip: {ok} identical, {bad} mismatched")
    return bad


if __name__ == "__main__":
    import sys
    sys.exit(1 if selftest() else 0)
