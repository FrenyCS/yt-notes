#!/usr/bin/env python3
"""SRT -> plain text with time anchors.

YouTube's auto-generated subtitles arrive as a rolling window: every cue
repeats the tail of the previous one plus a word or two. Joining the cues as
they come produces text three times too long and basically unreadable. This is
solved by finding, for each cue, the longest overlap between what has been
accumulated and what is coming in, and appending only the remainder.

The output is paragraphs with an [mm:ss] anchor at the start, so a note can
link back to the exact minute of the video.

Stdlib only.
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
# .srt files converted from VTT sometimes keep the positioning line.
CUE_SETTING_RE = re.compile(r"\b(align|position|line|size):\S+")

SENTENCE_END = (".", "?", "!", "…", '."', '?"', '!"', ".)", "?)", "!)")

# TED and some channels put the transcription credit in the first cue
# ("Translator: So-and-so / Reviewer: Someone"). It is noise in a note. The
# Spanish spellings stay in the pattern on purpose: they match the source
# video's language, which can be Spanish.
CREDIT_RE = re.compile(
    r"^(?:(?:traductora?|translator|revisora?|reviewer|traducci[oó]n|"
    r"revisi[oó]n|subt[ií]tulos|transcri(?:ptor|ber|pci[oó]n))\s*:\s*"
    r"[^:]+?\s*)+$",
    re.IGNORECASE,
)
# Only dropped at the start: further in, a similar ":" can be real content.
CREDIT_MAX_CUES = 3


def parse_srt(text):
    """Return [(start_seconds, text)] from the contents of an SRT."""
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

        if not body:
            continue
        if len(cues) < CREDIT_MAX_CUES and CREDIT_RE.match(body):
            continue

        cues.append((start, body))
    return cues


def merge_cues(cues):
    """Join the cues, removing the rolling overlap.

    Returns (words, anchors) where anchors is [(word_index, seconds)].
    """
    words = []
    anchors = []

    for start, body in cues:
        incoming = body.split()
        if not incoming:
            continue

        # Longest overlap between the accumulated tail and the incoming head.
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
    """Seconds of the anchor in effect at a given position."""
    seconds = 0
    for at, secs in anchors:
        if at > index:
            break
        seconds = secs
    return seconds


def build_paragraphs(words, anchors, target=110, slack=45):
    """Group into paragraphs of ~target words, cutting on a sentence boundary."""
    paragraphs = []
    i = 0
    n = len(words)

    while i < n:
        end = min(i + target, n)

        if end < n:
            # Look for the nearest sentence end within the slack.
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
    ap = argparse.ArgumentParser(description="SRT -> plain text with time anchors.")
    ap.add_argument("srt", help="input .srt file")
    ap.add_argument("-o", "--output", help="output file (default: stdout)")
    ap.add_argument("--header", help="text to put at the start of the file")
    ap.add_argument(
        "--words",
        type=int,
        default=110,
        help="words per paragraph, approximate (default: 110)",
    )
    ap.add_argument(
        "--no-timestamps",
        action="store_true",
        help="omit the [mm:ss] anchors",
    )
    args = ap.parse_args()

    src = Path(args.srt)
    if not src.is_file():
        sys.exit(f"srt2txt: no such file: {src}")

    cues = parse_srt(src.read_text(encoding="utf-8", errors="replace"))
    if not cues:
        sys.exit(f"srt2txt: found no valid cue in {src}")

    words, anchors = merge_cues(cues)
    if not words:
        sys.exit(f"srt2txt: the cues in {src} were empty after cleaning")

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
            f"srt2txt: {len(words)} words, {len(paragraphs)} paragraphs -> {args.output}",
            file=sys.stderr,
        )
    else:
        sys.stdout.write(out)


if __name__ == "__main__":
    main()
