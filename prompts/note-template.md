# Note template

Structure of `notes/<slug>.md`. Skip the sections that do not apply (an empty
section is worse than no section), but **Source**, **Central thesis** and
**Concepts** always go in.

```markdown
# <Video title>

**Source:** [<Channel>: <Title>](<url>) · <duration> · published <YYYY-MM-DD>
**Speaker:** <name, and why they have authority on this, one line>
**Noted:** <YYYY-MM-DD> · subtitles: <lang>
**Topics:** <tag>, <tag>, <tag>

## Central thesis

Two or three lines. The idea holding the whole talk together. If it cannot be
written in three lines, it probably was not understood.

## Concepts

### <Concept name> `[mm:ss]`

What it is, in two or three lines. Then why it matters or what problem it
solves. If the speaker gave it a name, use the speaker's name for it.

> Verbatim quote when the exact wording is worth more than the paraphrase.

### <Another concept> `[mm:ss]`

...

## Frameworks and strategies

The actionable procedures: steps, decision criteria, rules. With a timestamp.
If there are none, delete the section.

## Notable claims

Strong assertions, figures, predictions. With a timestamp, so they can be
checked against the source later.

- "<claim>" `[mm:ss]`

## Examples and cases

The concrete cases used to argue the point. They are forgotten before the
concepts are, and they are what make the concepts memorable.

## Supporting material

Where the full version of this lives. A talk is the compressed version; this is
what backs it. Every link **verified**, with one line on what it is and why you
would go back to it.

- [<what it is>](<url>): <why go back to it, e.g. "the full theory", "the
  code", "the slides with the diagrams">

If nothing turned up, say so explicitly so the search is not repeated:
`Searched for the author's repo, slides and blog: nothing found.`

## Limits of the talk

What it does NOT cover, what it assumes, which contexts it applies to. Keeps
you from later citing it as authority on something it never touched.

## Your own notes

Marked explicitly as your interpretation, not the speaker's. Where it connects
to current work, what it clashes with, what to try.
```

## Rules

- The note is written in **English**, whatever the language of the video.
- **Verbatim quotes stay in the speaker's language.** A translated quote is no
  longer a quote, and the note has to stay verifiable against the timestamp.
  Add a short English gloss right after when the wording is not obvious.
- Timestamps come from the `[mm:ss]` anchors in the `.txt`. They are not
  invented or approximated: they are the link back to the source, and if they
  are wrong the note stops being verifiable.
- Never mix what the speaker says with what the note-taker interprets.
  Everything of your own goes in **Your own notes** or is marked inline.
- Organize by concept, not by the video's chronological order.
- **No em dash (`—`).** Depending on the case: comma, colon, full stop, or
  parentheses for asides. Applies to the whole note, including the **Source**
  line and the supporting material lines.
- No filler. Three good ideas beat ten half-finished sections.
- **No link goes in unopened.** Only verified links go in supporting material.
  An invented link in a memory bank is worse than none: it gets read cold
  months later, when there is no way left to catch the error.
