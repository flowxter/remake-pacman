"""Baja solo la plantilla de exportacion de Windows del .tpz de Godot.

El .tpz oficial son 1.2 GB con las plantillas de todas las plataformas, pero
es un ZIP: leyendo su indice con peticiones HTTP por rangos se puede extraer
un unico miembro sin descargar el resto.
"""
import io
import sys
import zipfile
import urllib.request

URL = ("https://github.com/godotengine/godot/releases/download/"
       "4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz")
WANTED = ["windows_release_x86_64.exe", "windows_debug_x86_64.exe"]


class HttpFile(io.RawIOBase):
    """Objeto tipo fichero que sirve cada lectura con un Range sobre HTTP."""

    def __init__(self, url):
        self.url = url
        self.pos = 0
        self.downloaded = 0
        req = urllib.request.Request(url, method="HEAD")
        with urllib.request.urlopen(req, timeout=60) as r:
            self.size = int(r.headers["Content-Length"])
            if r.headers.get("Accept-Ranges") != "bytes":
                raise RuntimeError("el servidor no admite rangos")

    def seekable(self):
        return True

    def readable(self):
        return True

    def seek(self, offset, whence=0):
        if whence == 0:
            self.pos = offset
        elif whence == 1:
            self.pos += offset
        else:
            self.pos = self.size + offset
        return self.pos

    def tell(self):
        return self.pos

    def read(self, n=-1):
        if n is None or n < 0:
            n = self.size - self.pos
        if n == 0 or self.pos >= self.size:
            return b""
        end = min(self.pos + n, self.size) - 1
        req = urllib.request.Request(
            self.url, headers={"Range": f"bytes={self.pos}-{end}"})
        with urllib.request.urlopen(req, timeout=120) as r:
            data = r.read()
        self.pos += len(data)
        self.downloaded += len(data)
        return data

    def readinto(self, b):
        data = self.read(len(b))
        b[:len(data)] = data
        return len(data)


def main(out_dir):
    hf = HttpFile(URL)
    print(f"tpz remoto: {hf.size / 1024 / 1024:.0f} MB")
    with zipfile.ZipFile(hf) as zf:
        names = {n.rsplit("/", 1)[-1]: n for n in zf.namelist()}
        for want in WANTED:
            if want not in names:
                print(f"NO ESTA en el zip: {want}")
                continue
            member = names[want]
            info = zf.getinfo(member)
            print(f"extrayendo {member} "
                  f"({info.compress_size / 1024 / 1024:.0f} MB comprimido)")
            with zf.open(member) as src:
                data = src.read()
            dest = out_dir.rstrip("\\/") + "/" + want
            with open(dest, "wb") as fh:
                fh.write(data)
            print(f"  -> {dest}  ({len(data) / 1024 / 1024:.0f} MB)")
    print(f"descargado en total: {hf.downloaded / 1024 / 1024:.0f} MB "
          f"de {hf.size / 1024 / 1024:.0f} MB")


if __name__ == "__main__":
    main(sys.argv[1])
