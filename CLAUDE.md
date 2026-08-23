# CLAUDE.md: yt-notes

Context for Claude Code. Read it before touching anything.

## What this is

A personal utility that turns a YouTube talk into a **concept note in `.md`**
that works as a memory bank: you read it months later, when neither the video
nor the original conversation is remembered, and you paste it as context when
working on a related subject.

The transcript is plumbing, not the product. **The product is `notes/*.md`.**

Used often and personally. It is not a product. Priority: it works without
friction and without heavy dependencies. It is not a SEPHUS or LOOR project.

## Language

**The repo is in English.** Docs, comments, user-facing messages, commit
messages, the skill, the template, and the notes themselves: all English.

**Spanish is supported as a video language, not as a repo language.** Some
Spanish stays in the code on purpose and must not be "cleaned up":

- `LANGS_FALLBACK="es,en"` in `transcribe.sh`.
- The `ñ`/`Ñ` mapping in `slugify.py`.
- The Spanish spellings in `CREDIT_RE` in `srt2txt.py`, which strip the
  transcription credit from Spanish-language videos.

A note about a Spanish talk is written in English, but **verbatim quotes stay
in the speaker's language**, with a short English gloss when the wording is not
obvious. A translated quote is no longer a quote, and the note has to stay
verifiable against the timestamp.

## How it is used

```
/notes <youtube-url>
```

The skill (`.claude/skills/notes/`) runs `transcribe.sh`, reads the transcript
and writes the note. **Claude writes the summary in session**, not a script and
not an API call: no API key, no separate billing, and you can ask questions and
correct things while it is being written.

## Target environment (the only one)

- macOS 26.x, Apple Silicon (arm64). **Intel and Linux do not need support.**
- `yt-dlp` and `ffmpeg` via Homebrew. `ffmpeg` is not optional: YouTube serves
  VTT and the conversion to SRT goes through it.
- `python3`. The Python scripts are **stdlib only**.
- Shell: **bash 3.2**, the one macOS ships. No `mapfile`, no associative
  arrays, no `${var,,}`.

**Watch out for BSD:** `sed`, `tr` and `ls` are the BSD versions. That is why
the slug is generated in `slugify.py` and not with `sed`/`tr`, and why file
selection uses arrays with `nullglob` instead of parsing `ls`.

## Layout

```
transcribe.sh              URL -> output/<slug>.<lang>.srt + .txt
srt2txt.py                 SRT -> paragraphs with [mm:ss] anchors. Stdlib.
slugify.py                 title -> ASCII slug. Stdlib.
prompts/note-template.md   The note template.
.claude/skills/notes/      The /notes skill.
notes/                     THE PRODUCT. Local, untracked.
output/                    Transcripts. Local, untracked.
```

Flow of `transcribe.sh`:

1. Reads metadata with `yt-dlp --print` (title, channel, duration, date, URL,
   language) and dumps the description to `<slug>.description` with
   `--print-to-file`. Without `--lang`, it asks for **the video's original
   language only**, not a list.
2. Title -> slug via `slugify.py`.
3. Checks what is already in `output/` and, without `--force`, reuses it: the
   `.srt` first, and failing that a half-processed `.vtt` that it converts with
   ffmpeg.
4. Downloads published subtitles (`--write-subs --write-auto-subs`) and
   converts them to SRT with `--convert-subs srt`. If the original language has
   no subtitles, only then does it retry with `es,en`.
5. Picks the `.srt` according to the order of preference from `--lang`.
6. `srt2txt.py` -> clean `.txt` with time anchors.

Outputs: `.srt` (raw) and `.txt` (paragraphs with `[mm:ss]`). **The anchors in
the `.txt` are where the note's timestamps come from.** They are the link back
to the source, not decoration.

## Rules

- `srt2txt.py` and `slugify.py` are **stdlib only**. Do not add dependencies.
- Do not introduce paid services or network calls outside yt-dlp.
- The `.txt` carries the language in its name on purpose: without it, running
  the same video in two languages overwrites the previous file with no warning.
- In a note, **never mix what the speaker says with your own interpretation**.
  Yours goes in the "Your own notes" section.
- Timestamps are not invented or approximated. They are copied from the
  anchors.
- **No link goes in unopened.** Supporting material is verified or it is left
  out. An invented link in a memory bank is worse than none: it gets read cold
  months later, when there is no way left to catch the error.
- `--print-to-file` **appends**, it does not overwrite. That is why the
  description goes through a fresh temp file on every run and is moved at the
  end.
- yt-dlp exits non-zero if **any** of the requested languages fails, even when
  the others downloaded fine. What decides is whether a usable `.srt` is on
  disk, not the exit code.
- **One language per run.** Every extra language is one more download and
  YouTube returns 429 easily. That is why the original is requested on its own
  and the fallback list (`es,en`) only comes in when the original has no
  subtitles. Since yt-dlp reports the regional variant (`es-US`) but the track
  is usually named `es`, both are requested: it is the same language and only
  one of the two exists.
- **yt-dlp deletes the `.vtt` when it converts it to SRT**, so a `.vtt` that
  survives in `output/` means the download finished but the conversion did not.
  It happens when a 429 cuts a run in half. Converting it with ffmpeg is local
  and free; downloading it again costs another 429.
- Prefer the **speaker's original language** for the note. YouTube's translated
  subtitles lose nuance exactly in the terminology. The script already does
  this on its own; do not override it with `--lang` without a reason.
- **YouTube's auto-translated tracks are named `<target>-<source>`**, so `es-en`
  is "Spanish from English": on a Spanish-language video, a round trip. That is
  why the `.srt` search matches exactly and `-orig`, and never `${lang}-*`.
  Regional variants (`es-419`) are requested explicitly.
- An `[ ... ] && echo ...` as the last statement of a script makes it exit 1
  whenever the test is false, because that is the status the AND-OR list leaves
  behind. Use an `if` when the line is at the end.

## Status

Tested end to end against real YouTube: a 14-minute TED talk (manual subtitles
in `es` and `en`), a 1-hour podcast in `es-US` with auto-generated subtitles,
and a 20-minute conference talk in `en-US`. Covers metadata, slug, single
language download, `.srt` cache, recovery of an unconverted `.vtt`, regional
variant fallback (`es-US` -> `es`), rolling-window dedup, time anchors and the
final note. `srt2txt.py` is also tested against a synthetic SRT with rolling
duplicates and `<c>` tags. yt-dlp errors (missing, private, restricted,
geo-blocked video) are translated into readable messages; the "does not exist"
one is verified against the real network.

## Open items (in order)

1. **ASR for videos without subtitles.** Today `--asr` exits with an explicit
   error. Most talks by people with real authority have published subtitles, so
   this only pays off when a real video needs it: it is ~1.6 GB of model and a
   heavy dependency (`mlx-whisper` via pipx) for a case that has not come up.
   **If it gets implemented: the `mlx_whisper` flags are NOT verified against
   the installed version; run `mlx_whisper --help` first.**

2. **Pick the language interactively.** If you ask for `--lang es` and only
   English exists, today it warns and uses whatever it finds. Better: list what
   is available and let the user decide before downloading.

3. **Split long transcripts.** A 1-hour class fits in context without trouble,
   but something 3h+ will need `--split N`, cutting on a sentence boundary.

4. **Notes that cite each other.** Once there are several notes on the same
   subject, link them with `[[wikilinks]]` so they read as one body and not as
   loose files.
