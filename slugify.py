#!/usr/bin/env python3
"""Title -> ASCII slug usable as a filename.

This is a Python helper and not a sed/tr pipeline because BSD sed and tr do not
handle multibyte character classes or accented uppercase the way the GNU ones
do. Here unicodedata settles it, and the result is the same on any machine.

Stdlib only.
"""

import re
import sys
import unicodedata

MAX_LEN = 60


def slugify(text, max_len=MAX_LEN):
    # NFKD splits the accent off the letter; the ASCII filter then drops it.
    text = unicodedata.normalize("NFKD", text)
    # NFKD leaves "n" + combining tilde, which the ASCII filter would reduce to
    # a bare "n" anyway, but being explicit keeps Spanish titles predictable.
    text = text.replace("ñ", "n").replace("Ñ", "N")
    text = text.encode("ascii", "ignore").decode("ascii")
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    text = text.strip("-")

    if len(text) > max_len:
        text = text[:max_len].rsplit("-", 1)[0] or text[:max_len]

    return text.strip("-") or "untitled"


if __name__ == "__main__":
    raw = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else sys.stdin.read()
    print(slugify(raw.strip()))
