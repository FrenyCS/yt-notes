---
name: notes
description: Turns a YouTube video into a concept note in .md with timestamps, saved in notes/. Use when the user passes a YouTube URL and wants notes, a summary, concepts, or to "put this into memory".
---

# /notes: YouTube video to concept note

Goal: leave behind a `.md` that works as a memory bank months later, when
neither the video nor this conversation is remembered. The note gets read cold.

## Procedure

### 0. Say what you are about to run with

Before downloading anything, tell the user in two or three lines what defaults
you are going to work with. **This is not a question:** carry straight on in the
same turn. The point is that they know there are knobs, not to stop them every
time.

| What | Default | How to change it |
|---|---|---|
| Subtitles | the video's original language, detected automatically | ask for another language, or `--list` to see what exists |
| Note language | the video's original language | ask for another one |
| Supporting material | searched for, every link verified | skip it if you are in a hurry |
| Scope | full note, following the template | shorter, or focused on one topic |
| Destination | `notes/<slug>.md`, local and untracked | another path |

If the user already said what they want when invoking the skill ("in Spanish",
"just the part about funnels"), respect it and **do not repeat the menu**:
confirm it in one line and get going.

### 1. Get the transcript

```bash
./transcribe.sh "<url>"                 # detects the original language on its own
./transcribe.sh "<url>" --lang es       # force one
./transcribe.sh "<url>" --list          # see what is available
```

Without `--lang`, the script reads the video's original language and puts it
first. **That is almost always what you want:** YouTube's translated subtitles
lose nuance exactly in the terminology, which is what the note is trying to
capture. If an English talk comes out as Spanish text, something went wrong.

The script prints the path to the `.txt`. If it fails because there are no
subtitles, show what is available with `--list` and ask the user: do **not**
assume another language or fall back to a translated track on your own.

Watch out for auto-translated tracks: YouTube names them `<target>-<source>`,
so `es-en` is "Spanish from English". On a Spanish-language video that is a
round trip and the text comes out degraded. The script already avoids picking
those on its own; if you pass an explicit `--lang`, do not ask for them.

### 2. Read the whole transcript

Read the entire `.txt` before writing anything. The paragraphs come with
`[mm:ss]` anchors: that is where the note's timestamps come from.

Do not summarize while reading. First understand the complete argument: many
talks put the real thesis at the end, not at the start.

**Detect whether the subtitles are auto-generated.** The tells are broken
figures ("7 m,0000000esó", "$,000 a month") and mangled proper names ("Pure
Research" for Pew Research). On videos with manual subtitles this does not
happen, but on long podcasts it is the norm. When the text looks like that,
mark the figures and names in the note as unverified instead of copying them as
if they were faithful: the note gets read cold and there will be no way to tell
afterwards.

### 3. Find the supporting material

**A talk is almost never the complete source.** It is the compressed version of
something that usually exists at greater length: the author's repo, the slides,
the post or the paper with the whole theory. Finding it multiplies the note's
value, because it leaves somewhere to return to when the subject comes back.

Look in this order, cheapest first:

1. **The `.description`** that `transcribe.sh` leaves next to the `.txt`. It is
   where the author puts their links and it is the highest-yield source.

   Separate the **author's** material from the **channel's** filler. The
   channel's social accounts, the usage policy, the sponsors, the merch and the
   "subscribe" links are not supporting material. The blog, the repo, the book
   or the site of the person speaking are.

2. **The transcript.** Speakers name their repo, their book, their blog or the
   paper they are drawing on. Searching for `github`, `http`, "my book", "the
   paper", "I wrote about this" usually turns something up. Proper names of
   tools and frameworks are leads too.

3. **Web search**, only if 1 and 2 were not enough. Combine the speaker's name
   with the topic or the title: `<author> github`, `<author> slides <topic>`,
   `<author> blog <concept>`.

**Verify every link before putting it in.** Open it and confirm it exists and
really does correspond to this talk and this author. An invented or wrong link
in a memory bank is worse than no link: it gets read cold months from now, when
there is no way left to catch the error.

If the search turns up nothing, **say so in the note** instead of leaving it
out. "No repo or slides found" is useful information: it stops the search from
being repeated.

### 4. Write `notes/<slug>.md`

Use the same slug as the `.txt`. Template in `prompts/note-template.md`.

**The note is written in the video's original language**, unless the user asks
otherwise. A Spanish talk gets a Spanish note. The reason is fidelity: the note
is built out of the speaker's own words and has to stay verifiable against the
timestamps, and translating on the way in loses the terminology.

Verbatim quotes stay in the speaker's language in every case, including when the
user did ask for another language. A translated quote is no longer a quote. In
that case add a short gloss after the quote when the wording is not obvious.

## What makes a note good

- **Concepts, not chronology.** Nobody wants "first he said X, then Y".
  Organize by idea, even if the video presents them in another order.
- **Real timestamps on every concept.** They are the hyperlink back to the
  source. Copy them from the anchors in the `.txt`, do not invent or
  approximate them.
- **Separate what the speaker says from what you interpret.** If you add
  something that is not in the talk, mark it as your own note. The note will be
  read as if it were the source.
- **Verbatim quotes where the wording matters.** A definition or a well-built
  sentence gets quoted; the rest gets paraphrased.
- **Density over length.** If the talk has three ideas, the note has three
  ideas. Do not inflate it to look complete.
- **Write down what it did NOT cover** if it is relevant: the limits of the
  talk stop you from later citing it as authority on something it never
  touched.

## When you are done

1. Add a line to `notes/README.md`: `- [Title](slug.md): one-line hook`. The
   hook starts with the content, not with "Author:", which would leave two
   colons on the same line.
2. Tell the user the path and sum up in 2-3 lines what got captured.
3. Also say what came out below useful: auto-generated subtitles that wrecked
   the figures, supporting material that never turned up, attributions that did
   not hold up when verified. That is what the user needs in order to decide
   whether to go back to the source.

None of this gets versioned: the repo is the tool, not the notes. The `.txt`
and the `.srt` stay in `output/` and the note in `notes/`, both local. Do not
add them to git or suggest committing them.
