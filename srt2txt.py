#!/usr/bin/env python3
"""SRT -> texto plano con anclas de tiempo.

Los subtitulos automaticos de YouTube llegan en "rolling window": cada cue
repite la cola del anterior mas una o dos palabras nuevas. Pegar los cues tal
cual produce un texto tres veces mas largo y basicamente ilegible. Aca se
resuelve buscando, para cada cue, el solape mas largo entre lo acumulado y lo
que entra, y agregando solo el resto.

La salida son parrafos con un ancla [mm:ss] al inicio, para poder volver al
minuto exacto del video desde los apuntes.

Solo stdlib.
"""

import argparse
import html
import re
import sys
from pathlib import Path

TIME_RE = re.compile(
    r"(\d+):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d+):(\d{2}):(\d{2})[,.](\d{3})"
)
TAG_RE = re.compile(r"<[^>]*>")
# Los .srt convertidos desde VTT a veces conservan la linea de posicion.
CUE_SETTING_RE = re.compile(r"\b(align|position|line|size):\S+")

SENTENCE_END = (".", "?", "!", "…", '."', '?"', '!"', ".)", "?)", "!)")


def parse_srt(text):
    """Devuelve [(segundos_inicio, texto)] a partir del contenido de un SRT."""
    text = text.replace("\r\n", "\n").replace("﻿", "")
    cues = []
    for block in re.split(r"\n\s*\n", text.strip()):
        lines = [ln for ln in block.split("\n") if ln.strip()]
        if not lines:
            continue

        timing_at = next((i for i, ln in enumerate(lines) if TIME_RE.search(ln)), None)
        if timing_at is None:
            continue

        m = TIME_RE.search(lines[timing_at])
        start = int(m.group(1)) * 3600 + int(m.group(2)) * 60 + int(m.group(3))

        body = " ".join(lines[timing_at + 1 :])
        body = TAG_RE.sub("", body)
        body = CUE_SETTING_RE.sub("", body)
        body = html.unescape(body)
        body = re.sub(r"\s+", " ", body).strip()

        if body:
            cues.append((start, body))
    return cues


def merge_cues(cues):
    """Pega los cues quitando el solape rodante.

    Devuelve (palabras, anclas) donde anclas es [(indice_palabra, segundos)].
    """
    words = []
    anchors = []

    for start, body in cues:
        incoming = body.split()
        if not incoming:
            continue

        # Solape mas largo entre la cola de lo acumulado y la cabeza de lo nuevo.
        overlap = 0
        for n in range(min(len(words), len(incoming)), 0, -1):
            tail = [w.lower() for w in words[-n:]]
            head = [w.lower() for w in incoming[:n]]
            if tail == head:
                overlap = n
                break

        addition = incoming[overlap:]
        if not addition:
            continue

        anchors.append((len(words), start))
        words.extend(addition)

    return words, anchors


def anchor_for(index, anchors):
    """Segundos del ancla vigente en una posicion dada."""
    seconds = 0
    for at, secs in anchors:
        if at > index:
            break
        seconds = secs
    return seconds


def build_paragraphs(words, anchors, target=110, slack=45):
    """Agrupa en parrafos de ~target palabras, cortando en frontera de frase."""
    paragraphs = []
    i = 0
    n = len(words)

    while i < n:
        end = min(i + target, n)

        if end < n:
            # Busca el final de frase mas cercano dentro del margen.
            limit = min(end + slack, n)
            cut = None
            for j in range(end, limit):
                if words[j].endswith(SENTENCE_END):
                    cut = j + 1
                    break
            if cut is None:
                for j in range(end - 1, max(i, end - slack) - 1, -1):
                    if words[j].endswith(SENTENCE_END):
                        cut = j + 1
                        break
            end = cut if cut else end

        paragraphs.append((anchor_for(i, anchors), " ".join(words[i:end])))
        i = end

    return paragraphs


def fmt_time(seconds):
    h, rem = divmod(int(seconds), 3600)
    m, s = divmod(rem, 60)
    return f"{h}:{m:02d}:{s:02d}" if h else f"{m:02d}:{s:02d}"


def main():
    ap = argparse.ArgumentParser(description="SRT -> texto plano con anclas de tiempo.")
    ap.add_argument("srt", help="archivo .srt de entrada")
    ap.add_argument("-o", "--output", help="archivo de salida (default: stdout)")
    ap.add_argument("--header", help="texto a poner al inicio del archivo")
    ap.add_argument(
        "--words",
        type=int,
        default=110,
        help="palabras por parrafo, aproximado (default: 110)",
    )
    ap.add_argument(
        "--no-timestamps",
        action="store_true",
        help="omite las anclas [mm:ss]",
    )
    args = ap.parse_args()

    src = Path(args.srt)
    if not src.is_file():
        sys.exit(f"srt2txt: no existe el archivo: {src}")

    cues = parse_srt(src.read_text(encoding="utf-8", errors="replace"))
    if not cues:
        sys.exit(f"srt2txt: no se encontro ningun cue valido en {src}")

    words, anchors = merge_cues(cues)
    if not words:
        sys.exit(f"srt2txt: los cues de {src} quedaron vacios tras limpiar")

    paragraphs = build_paragraphs(words, anchors, target=args.words)

    chunks = []
    if args.header:
        chunks.append(args.header.rstrip() + "\n")
    for seconds, body in paragraphs:
        chunks.append(body if args.no_timestamps else f"[{fmt_time(seconds)}] {body}")

    out = "\n\n".join(chunks) + "\n"

    if args.output:
        Path(args.output).write_text(out, encoding="utf-8")
        print(
            f"srt2txt: {len(words)} palabras, {len(paragraphs)} parrafos -> {args.output}",
            file=sys.stderr,
        )
    else:
        sys.stdout.write(out)


if __name__ == "__main__":
    main()
