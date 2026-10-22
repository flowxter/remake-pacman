"""Genera icon.ico (Pac-Man) sin dependencias externas.

Dibuja un PNG RGBA de 256x256 a mano (zlib + CRC32 de la libreria estandar)
y lo envuelve en un contenedor ICO, que desde Vista admite PNG dentro.
"""
import math
import struct
import sys
import zlib

SIZES = [16, 32, 48, 64, 128, 256]


def pacman_pixels(size):
    """Circulo amarillo con una cuna recortada, con antialias por supersampleo."""
    cx = cy = size / 2.0
    r = size * 0.46
    mouth = math.radians(38.0)          # medio angulo de la boca
    rows = []
    ss = 3                               # muestras por eje
    for y in range(size):
        row = bytearray()
        for x in range(size):
            hits = 0
            for sy in range(ss):
                for sx in range(ss):
                    px = x + (sx + 0.5) / ss
                    py = y + (sy + 0.5) / ss
                    dx = px - cx
                    dy = py - cy
                    if dx * dx + dy * dy > r * r:
                        continue
                    ang = math.atan2(dy, dx)
                    if abs(ang) < mouth:  # dentro de la boca: transparente
                        continue
                    hits += 1
            a = int(255 * hits / (ss * ss))
            row += bytes((255, 204, 0, a))
        rows.append(bytes(row))
    return rows


def write_png(rows, size):
    raw = b"".join(b"\x00" + r for r in rows)

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9))
            + chunk(b"IEND", b""))


def write_ico(images, path):
    """images: lista de (tamano, bytes_png). Windows elige el mas adecuado."""
    header = struct.pack("<HHH", 0, 1, len(images))
    offset = 6 + 16 * len(images)
    entries = b""
    for size, png in images:
        w = 0 if size >= 256 else size   # 0 significa 256 en el formato ICO
        entries += struct.pack("<BBBBHHII", w, w, 0, 0, 1, 32, len(png), offset)
        offset += len(png)
    with open(path, "wb") as fh:
        fh.write(header + entries + b"".join(p for _, p in images))


if __name__ == "__main__":
    out = sys.argv[1]
    images = [(s, write_png(pacman_pixels(s), s)) for s in SIZES]
    write_ico(images, out)
    print(f"{out}: {len(images)} tamanos "
          f"({', '.join(str(s) for s, _ in images)})")
