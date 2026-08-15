#!/usr/bin/env python3
"""Titulo -> slug ASCII apto para nombre de archivo.

Existe como helper de Python y no como pipeline de sed/tr porque el sed y el tr
de BSD no manejan igual que los de GNU ni las clases de caracteres multibyte ni
las mayusculas acentuadas. Aca se resuelve con unicodedata y queda igual en
cualquier maquina.

Solo stdlib.
"""

import re
import sys
import unicodedata

MAX_LEN = 60


def slugify(text, max_len=MAX_LEN):
    # NFKD separa la tilde de la letra; el filtro ASCII la descarta.
    text = unicodedata.normalize("NFKD", text)
    text = text.replace("ñ", "n").replace("Ñ", "N")
    text = text.encode("ascii", "ignore").decode("ascii")
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    text = text.strip("-")

    if len(text) > max_len:
        text = text[:max_len].rsplit("-", 1)[0] or text[:max_len]

    return text.strip("-") or "sin-titulo"


if __name__ == "__main__":
    raw = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else sys.stdin.read()
    print(slugify(raw.strip()))
