# yt-notes

Turn a YouTube talk into a concept note in Markdown, with timestamps back to
the source.

The idea: when you watch a good talk (someone with real authority on a subject,
explaining ideas and strategy) you want to keep what you learned. Not a summary
that reads well and is forgotten, but something that works as a memory bank:
you read it cold months later, and you can paste it as context when you work on
a related problem.

**The transcript is plumbing. The product is `notas/*.md`.**

## Requirements

macOS on Apple Silicon. Everything else:

```bash
brew install yt-dlp ffmpeg
```

`ffmpeg` is not optional: YouTube serves subtitles as VTT and the conversion to
SRT goes through it. The Python scripts use the standard library only, so there
is nothing to install there.

## Usage

Inside a Claude Code session, in this repo:

```
/notes https://www.youtube.com/watch?v=...
```

That downloads the subtitles, reads the full transcript and writes
`notas/<slug>.md`. **Claude writes the note in the session**, not a script and
not an API call: there is no API key and no separate billing, and you can ask
questions and correct things while it is being written.

### Defaults, and how to change them

The skill tells you what it is about to do before it starts. These are the
defaults:

| What | Default | How to change it |
|---|---|---|
| Subtitles | the video's original language, detected automatically | ask for another language, or `--list` to see what exists |
| Note language | the language you are talking in, even if the talk is in another | ask for the video's language, or any other |
| Supporting material | searched for, and every link verified | skip it if you are in a hurry |
| Scope | full note, following the template | shorter, or focused on one topic |
| Destination | `notas/<slug>.md`, local and untracked | another path |

You can say any of this when you invoke the skill ("in English", "just the part
about funnels") or while the note is being written.

### Transcript only

If you want the text and nothing else:

```bash
./transcribe.sh "<url>"              # detects the video's original language
./transcribe.sh "<url>" --lang es    # force a language
./transcribe.sh "<url>" --list       # see which subtitles exist
./transcribe.sh "<url>" --force      # re-download, ignoring the cache
```

It leaves this in `salida/`:

| File | What it is |
|---|---|
| `<slug>.<lang>.srt` | raw, with timestamps |
| `<slug>.<lang>.txt` | clean, in paragraphs, with `[mm:ss]` anchors |
| `<slug>.description` | the video description, where the links usually are |

Re-running the same URL reuses whatever was already downloaded, including a
`.vtt` that was downloaded but never converted, which is what a rate-limit
error in the middle of a run leaves behind.

## What a note looks like

The full template is in [`prompts/notas.md`](prompts/notas.md). `notas/` is
empty in a fresh clone, because notes are local. The structure:

- **Source**: channel, duration, date, who is speaking and why they have
  authority on this
- **Central thesis**: the idea holding the talk together, in three lines
- **Concepts**: each one with its `[mm:ss]`
- **Frameworks, claims, examples**: the actionable and the verifiable
- **Supporting material**: the author's repo, slides, blog or paper, verified
- **Limits of the talk**: what it does NOT cover, so you do not cite it later
  as authority on something it never touched
- **Your own notes**: your interpretation, kept separate from what the speaker
  actually said

The timestamps are the point. They are the link back to the exact minute when,
six months later, you want to verify something or rewatch that part.

**A talk is almost never the complete source.** It is usually the compressed
version of something that exists at greater length: the author's repo, the
slides, the post or the paper. So the flow goes looking for that material,
first in the video description, then in what is mentioned during the talk, and
on the web if needed. Every link is opened and verified before it goes in. A
wrong link in a memory bank is worse than no link: you read it cold months
later, when there is no way left to catch the error.

## About language

Worth knowing, because it is the least obvious trap in the project.

Without `--lang`, the script detects the video's original language and asks for
that one only. This is almost always what you want: YouTube's translated
subtitles lose nuance exactly in the terminology, which is what the note is
trying to capture.

Only one language is requested per run. Every extra language is another
download and another chance of a 429 from YouTube, so the fallback list
(`es,en`) is only used if the original language has no published subtitles.

YouTube names auto-translated tracks `<target>-<source>`. So `es-en` means
"Spanish **from** English": on a video that is already in Spanish, that is a
round trip through another language. The script never picks those on its own.
If you pass `--lang` explicitly, do not ask for them.

Use `--list` to see what exists before deciding.

## Limitations

- **Only videos with published subtitles.** There is no audio transcription
  yet; `--asr` exits with an explicit error. Most talks by people worth
  listening to have subtitles, so it has not been needed.
- **Auto-generated subtitles degrade numbers and proper names.** On long
  podcasts this is the norm rather than the exception, and figures come out
  mangled. The note marks them as unverified instead of presenting them as
  faithful, but it is a reason to go back to the source before reusing a
  number.
- Private, members-only, age-restricted or geo-blocked videos fail with a
  message explaining which of those cases it is.

## Layout

```
transcribe.sh              URL -> .srt + .txt
srt2txt.py                 SRT -> paragraphs with [mm:ss] anchors
slugify.py                 title -> file slug
prompts/notas.md           the note template
.claude/skills/notes/      the /notes skill
notas/                     THE PRODUCT. Local, untracked.
salida/                    transcripts. Local, untracked.
```

**This repo is the tool, not the notes.** None of the content is versioned:
transcripts are derived and can be regenerated, and notes are personal, grow
without end, and their value is local. If you want to back them up or move them
to another machine, sync `notas/` outside of git.

## License

MIT. See [LICENSE](LICENSE).
