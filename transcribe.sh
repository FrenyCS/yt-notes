#!/usr/bin/env bash
#
# transcribe.sh: YouTube URL -> .srt + .txt ready for note-taking.
#
# Uses the video's published subtitles (manual or auto-generated). It does no
# ASR: see the note about --asr in CLAUDE.md.
#
# Written for bash 3.2, the one macOS ships: no mapfile, no associative arrays,
# no ${var,,}.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTDIR="${HERE}/output"

# Fallback for when the original language has no published subtitles, or when
# yt-dlp reports no language at all. It is not requested alongside the original:
# every extra language is one more request to YouTube.
LANGS_FALLBACK="es,en"
LANGS="$LANGS_FALLBACK"
LANGS_EXPLICIT=0
FORCE=0
LIST_ONLY=0
URL=""

usage() {
  cat <<'EOF'
Usage: transcribe.sh <youtube-url> [options]

Options:
  --lang LANGS   Subtitle languages, in order of preference.
                 The default is the video's original language, which is almost
                 always what you want: YouTube's translated tracks lose nuance
                 exactly in the terminology.
                 E.g. --lang "en" or --lang "es,es-419,en"
  --list         List the available subtitles and exit.
  --force        Download again even if subtitles already exist in output/.
  -h, --help     This.

Outputs (in output/):
  <slug>.<lang>.srt   With timestamps, to jump to the exact minute.
  <slug>.<lang>.txt   Clean, in paragraphs, with [mm:ss] anchors.
EOF
}

die() { echo "error: $*" >&2; exit 1; }

# --- arguments ----------------------------------------------------------------

while [ $# -gt 0 ]; do
  case "$1" in
    --lang)   [ $# -ge 2 ] || die "--lang needs a value"; LANGS="$2"; LANGS_EXPLICIT=1; shift 2 ;;
    --lang=*) LANGS="${1#*=}"; LANGS_EXPLICIT=1; shift ;;
    --list)   LIST_ONLY=1; shift ;;
    --force)  FORCE=1; shift ;;
    --asr)
      die "--asr is not implemented yet (see CLAUDE.md). This script only uses published subtitles."
      ;;
    -h|--help) usage; exit 0 ;;
    -*)       die "unknown option: $1" ;;
    *)
      [ -z "$URL" ] || die "got more than one URL: '$URL' and '$1'"
      URL="$1"; shift ;;
  esac
done

[ -n "$URL" ] || { usage; exit 1; }

# --- dependencies -------------------------------------------------------------

for bin in yt-dlp ffmpeg python3; do
  command -v "$bin" >/dev/null 2>&1 || die "'$bin' is missing from PATH."
done

# --- metadata -----------------------------------------------------------------

# Turns the usual yt-dlp failures into something readable.
explain_ytdlp_error() {
  local log="$1"
  if grep -qi "private video" "$log"; then
    echo "The video is private."
  elif grep -qi "sign in to confirm your age\|age-restricted\|inappropriate for some users" "$log"; then
    echo "The video is age-restricted; yt-dlp needs cookies from a logged-in session."
  elif grep -qi "not available in your country\|geo restricted\|geo-restricted" "$log"; then
    echo "The video is blocked in your region."
  elif grep -qi "video unavailable\|has been removed\|does not exist" "$log"; then
    echo "The video does not exist or was removed."
  elif grep -qi "members-only\|join this channel" "$log"; then
    echo "The video is for channel members only."
  elif grep -qi "429\|too many requests" "$log"; then
    echo "YouTube is rate-limiting (429). Wait a few minutes and retry: whatever downloaded is reused without asking for it again."
  elif grep -qi "unable to download\|unable to extract\|HTTP Error" "$log"; then
    echo "yt-dlp could not reach the video (network, or YouTube changed something and it is time to 'brew upgrade yt-dlp')."
  else
    return 1
  fi
}

# Goes to stderr so it does not pollute captured output.
ytdlp_failed() {
  local log="$1" what="$2"
  local reason
  if reason="$(explain_ytdlp_error "$log")"; then
    echo "error: $reason" >&2
  else
    echo "error: yt-dlp failed to $what. Raw output:" >&2
    tail -n 15 "$log" >&2
  fi
  exit 1
}

TMPLOG="$(mktemp -t yt-notes)"
trap 'rm -f "$TMPLOG"' EXIT

if [ "$LIST_ONLY" -eq 1 ]; then
  echo "Available subtitles:"
  yt-dlp --list-subs --skip-download "$URL" 2>"$TMPLOG" || ytdlp_failed "$TMPLOG" "list the subtitles"
  exit 0
fi

echo "Reading metadata..."

# The description goes to its own file because it is multiline and would break
# the line-by-line parsing of --print. Careful: --print-to-file *appends*, it
# does not overwrite, and the final destination depends on the slug that comes
# out of this same call; hence a fresh temp file that gets moved afterwards.
TMPDESC="$(mktemp -t yt-notes-desc)"
trap 'rm -f "$TMPLOG" "$TMPDESC"' EXIT

META="$(yt-dlp --no-warnings --skip-download \
          --print "%(title)s" \
          --print "%(channel)s" \
          --print "%(duration_string)s" \
          --print "%(upload_date>%Y-%m-%d)s" \
          --print "%(webpage_url)s" \
          --print "%(language)s" \
          --print-to-file "%(description)s" "$TMPDESC" \
          "$URL" 2>"$TMPLOG")" || ytdlp_failed "$TMPLOG" "read the metadata"

TITLE="$(printf '%s\n' "$META"  | awk 'NR==1')"
CHANNEL="$(printf '%s\n' "$META" | awk 'NR==2')"
DURATION="$(printf '%s\n' "$META" | awk 'NR==3')"
UPLOADED="$(printf '%s\n' "$META" | awk 'NR==4')"
PAGE_URL="$(printf '%s\n' "$META" | awk 'NR==5')"
LANGUAGE="$(printf '%s\n' "$META" | awk 'NR==6')"

[ -n "$TITLE" ] || die "yt-dlp returned no title; the URL may not be a video."

# With no explicit language, the video's original goes first. A note lives on
# the exact terminology of whoever is speaking, and YouTube's translated
# subtitles lose it precisely there.
if [ "$LANGS_EXPLICIT" -eq 0 ] && [ -n "$LANGUAGE" ] && [ "$LANGUAGE" != "NA" ]; then
  LANGS="$LANGUAGE"
  # yt-dlp reports the regional variant ("es-US") but the subtitle track is
  # usually named plainly ("es"), so both get requested. It is still a single
  # language: no video publishes both, so whichever exists is the one that
  # downloads.
  case "$LANGUAGE" in
    *-*) LANGS="${LANGUAGE},${LANGUAGE%%-*}" ;;
  esac
  echo "  original language: $LANGUAGE"
fi

SLUG="$(python3 "${HERE}/slugify.py" "$TITLE")"
BASE="${OUTDIR}/${SLUG}"

echo "  $TITLE"
echo "  $CHANNEL · ${DURATION:-?} · ${UPLOADED:-?}"
echo "  slug: $SLUG"

mkdir -p "$OUTDIR"

# The description is where the author usually leaves the repo, the slides and
# the blog: the highest-yield source of supporting material, at no extra cost.
DESC="${BASE}.description"
if [ -s "$TMPDESC" ]; then
  mv "$TMPDESC" "$DESC"
else
  rm -f "$TMPDESC"
  DESC=""
fi

# --- subtitles ----------------------------------------------------------------

# First subtitle with extension $1 that exists, following the order of
# preference given by --lang.
# It uses an array with nullglob: a glob with no match yields an empty array
# instead of keeping the literal pattern.
# Second argument: "strict" only accepts the requested languages; "loose"
# accepts any subtitle of the video as a last resort.
#
# The distinction matters: checking the cache has to be strict, otherwise a
# .srt left by an earlier run in another language silently makes --lang stop
# having any effect. After downloading it pays to be flexible, because YouTube
# returns variants like "en-orig" that do not match the request literally.
find_sub() {
  local ext="$1" mode="$2" lang candidate
  local old_nullglob
  old_nullglob="$(shopt -p nullglob || true)"
  shopt -s nullglob

  local found=""
  local IFS=,
  for lang in $LANGS; do
    # Exact match and "-orig", nothing else. A "${lang}-*" glob would be a
    # trap: YouTube names auto-translated tracks "<target>-<source>", so "es-*"
    # also matches es-en ("Spanish from English"), which on a Spanish video is
    # a round trip through another language. Regional variants (es-419, pt-BR)
    # are requested explicitly with --lang.
    for candidate in "${BASE}.${lang}.${ext}" "${BASE}.${lang}-orig.${ext}"; do
      [ -f "$candidate" ] || continue
      found="$candidate"
      break
    done
    [ -n "$found" ] && break
  done

  if [ -z "$found" ] && [ "$mode" = "loose" ]; then
    local any=("${BASE}".*."${ext}")
    [ ${#any[@]} -gt 0 ] && found="${any[0]}"
  fi

  eval "$old_nullglob"
  [ -n "$found" ] && printf '%s\n' "$found"
}

# ffmpeg does locally what --convert-subs does, without touching the network.
vtt_to_srt() {
  local vtt="$1" srt="${1%.vtt}.srt"
  ffmpeg -v error -y -i "$vtt" "$srt" </dev/null >/dev/null 2>&1 || return 1
  [ -s "$srt" ] || return 1
  printf '%s\n' "$srt"
}

# Whatever .srt is on disk, converting a .vtt if needed. Silent on purpose: the
# caller knows whether the file came from an earlier run or from just now.
resolve_srt() {
  local mode="$1" srt vtt
  srt="$(find_sub srt "$mode" || true)"
  if [ -z "$srt" ]; then
    vtt="$(find_sub vtt "$mode" || true)"
    [ -n "$vtt" ] && srt="$(vtt_to_srt "$vtt" || true)"
  fi
  [ -n "$srt" ] && printf '%s\n' "$srt"
}

# One download pass for whatever languages $LANGS holds. Leaves the result in
# $SRT (empty if nothing came out) and yt-dlp's status in $DOWNLOAD_FAILED.
download_subs() {
  echo "Downloading subtitles ($LANGS)..."
  DOWNLOAD_FAILED=0
  yt-dlp --no-warnings --skip-download \
         --write-subs --write-auto-subs \
         --sub-langs "$LANGS" \
         --sub-format "vtt/srt/best" \
         --convert-subs srt \
         -o "${BASE}.%(ext)s" \
         "$URL" >"$TMPLOG" 2>&1 || DOWNLOAD_FAILED=1

  SRT="$(resolve_srt strict || true)"
}

# Before requesting anything, see what earlier runs left behind. Besides the
# .srt, it is worth looking for a surviving .vtt: yt-dlp deletes it on
# conversion, so one still on disk means the download finished but the
# conversion did not. This really happens when a 429 cuts a run in half, and
# without this the next run downloads half a megabyte for nothing and earns
# another 429.
SRT=""
if [ "$FORCE" -eq 0 ]; then
  SRT="$(find_sub srt strict || true)"
  if [ -n "$SRT" ]; then
    echo "$(basename "$SRT") already exists: reusing it (use --force to download it again)."
  else
    CACHED_VTT="$(find_sub vtt strict || true)"
    if [ -n "$CACHED_VTT" ]; then
      SRT="$(vtt_to_srt "$CACHED_VTT" || true)"
      if [ -n "$SRT" ]; then
        echo "$(basename "$CACHED_VTT") was left half-processed: converting without downloading again."
      else
        echo "warning: $(basename "$CACHED_VTT") is on disk but ffmpeg could not convert it; downloading again." >&2
      fi
    fi
  fi
fi

if [ -z "$SRT" ]; then
  download_subs

  # A single language was requested, the video's original. Only if that one has
  # no published subtitles is one more request spent on the fallback list:
  # asking for all of them up front is what triggers the 429s.
  if [ -z "$SRT" ] && [ "$LANGS_EXPLICIT" -eq 0 ] && [ "$LANGS" != "$LANGS_FALLBACK" ]; then
    echo "warning: the video has no subtitles in '$LANGS'; trying $LANGS_FALLBACK." >&2
    LANGS="$LANGS_FALLBACK"
    download_subs
  fi

  if [ -z "$SRT" ]; then
    SRT="$(resolve_srt loose || true)"
    [ -n "$SRT" ] && echo "warning: there were no subtitles in '$LANGS'; using $(basename "$SRT") instead." >&2
  fi

  # yt-dlp exits non-zero if *any* of the requested languages fails, even when
  # the others downloaded fine. What matters is whether a usable .srt is on
  # disk, not the exit code.
  if [ "$DOWNLOAD_FAILED" -eq 1 ]; then
    if [ -z "$SRT" ]; then
      ytdlp_failed "$TMPLOG" "download the subtitles"
    fi
    echo "warning: yt-dlp failed on one of the requested languages, but $(basename "$SRT") came through." >&2
    reason="$(explain_ytdlp_error "$TMPLOG" || true)"
    [ -n "$reason" ] && echo "       $reason" >&2
  fi
fi

if [ -z "$SRT" ]; then
  echo "error: the video has no subtitles in any of these languages: $LANGS" >&2
  echo >&2
  echo "See what is available with:" >&2
  echo "  $0 \"$URL\" --list" >&2
  exit 1
fi

# --- plain text ---------------------------------------------------------------

# The .txt carries the language in its name: without it, running the same video
# in two languages overwrites the previous file with no warning.
SRT_NAME="$(basename "$SRT")"
SRT_LANG="${SRT_NAME#${SLUG}.}"
SRT_LANG="${SRT_LANG%.srt}"
TXT="${BASE}.${SRT_LANG}.txt"

HEADER="# ${TITLE}
Channel: ${CHANNEL}
Duration: ${DURATION:-?}
Published: ${UPLOADED:-?}
Subtitles: ${SRT_LANG}
URL: ${PAGE_URL:-$URL}
"

python3 "${HERE}/srt2txt.py" "$SRT" --output "$TXT" --header "$HEADER"

echo
echo "Done:"
echo "  srt: $SRT"
echo "  txt: $TXT"
if [ -n "$DESC" ]; then
  echo "  desc: $DESC"
  # A description with no links is normal, and neither of the two ways this can
  # go wrong may take the script down with it:
  #   - grep exits 1 when it matches nothing, and pipefail hands that to the
  #     command substitution, so the assignment needs its own fallback. (Using
  #     `grep -c` instead does not help: it prints 0 *and* exits 1, so an
  #     `|| echo 0` inside the substitution would yield "0\n0".)
  #   - an `[ ... ] && echo` as the last statement of the script would make it
  #     exit 1 whenever the test is false, because that is the status the AND-OR
  #     list leaves behind. Hence the `if`.
  # -o counts occurrences rather than the lines containing them, which is what
  # the number is meant to report.
  links="$(grep -oE 'https?://[^[:space:]]+' "$DESC" 2>/dev/null | wc -l | tr -d ' ')" || links=0
  if [ "$links" -gt 0 ]; then
    [ "$links" -eq 1 ] && noun="link" || noun="links"
    echo "        ($links $noun: check for a repo, slides or a blog)"
  fi
fi
