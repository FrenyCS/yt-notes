#!/usr/bin/env bash
#
# transcribe.sh — URL de YouTube -> .srt + .txt listos para hacer apuntes.
#
# Usa los subtitulos publicados del video (manuales o automaticos). No hace ASR:
# ver la nota sobre --asr en CLAUDE.md.
#
# Escrito para bash 3.2, que es el que trae macOS: nada de mapfile, arreglos
# asociativos ni ${var,,}.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTDIR="${HERE}/salida"

LANGS="es,en"
LANGS_EXPLICIT=0
FORCE=0
LIST_ONLY=0
URL=""

usage() {
  cat <<'EOF'
Uso: transcribe.sh <url-de-youtube> [opciones]

Opciones:
  --lang LANGS   Idiomas de subtitulos, por orden de preferencia.
                 Por defecto se usa el idioma original del video, que es lo
                 que casi siempre se quiere: las pistas traducidas de YouTube
                 pierden matiz en la terminologia.
                 Ej: --lang "en" o --lang "es,es-419,en"
  --list         Solo lista los subtitulos disponibles y sale.
  --force        Vuelve a descargar aunque el .srt ya exista.
  -h, --help     Esto.

Salidas (en salida/):
  <slug>.<lang>.srt   Con timestamps, para saltar al minuto exacto.
  <slug>.<lang>.txt   Limpio, en parrafos, con anclas [mm:ss].
EOF
}

die() { echo "error: $*" >&2; exit 1; }

# --- argumentos ---------------------------------------------------------------

while [ $# -gt 0 ]; do
  case "$1" in
    --lang)   [ $# -ge 2 ] || die "--lang necesita un valor"; LANGS="$2"; LANGS_EXPLICIT=1; shift 2 ;;
    --lang=*) LANGS="${1#*=}"; LANGS_EXPLICIT=1; shift ;;
    --list)   LIST_ONLY=1; shift ;;
    --force)  FORCE=1; shift ;;
    --asr)
      die "--asr no esta implementado todavia (ver CLAUDE.md). Este script solo usa subtitulos publicados."
      ;;
    -h|--help) usage; exit 0 ;;
    -*)       die "opcion desconocida: $1" ;;
    *)
      [ -z "$URL" ] || die "se recibio mas de una URL: '$URL' y '$1'"
      URL="$1"; shift ;;
  esac
done

[ -n "$URL" ] || { usage; exit 1; }

# --- dependencias -------------------------------------------------------------

for bin in yt-dlp ffmpeg python3; do
  command -v "$bin" >/dev/null 2>&1 || die "falta '$bin' en el PATH."
done

# --- metadata -----------------------------------------------------------------

# Traduce los fallos tipicos de yt-dlp a algo legible.
explain_ytdlp_error() {
  local log="$1"
  if grep -qi "private video" "$log"; then
    echo "El video es privado."
  elif grep -qi "sign in to confirm your age\|age-restricted\|inappropriate for some users" "$log"; then
    echo "El video tiene restriccion de edad; yt-dlp necesita cookies de una sesion con login."
  elif grep -qi "not available in your country\|geo restricted\|geo-restricted" "$log"; then
    echo "El video esta bloqueado en tu region."
  elif grep -qi "video unavailable\|has been removed\|does not exist" "$log"; then
    echo "El video no existe o fue eliminado."
  elif grep -qi "members-only\|join this channel" "$log"; then
    echo "El video es solo para miembros del canal."
  elif grep -qi "429\|too many requests" "$log"; then
    echo "YouTube esta limitando las peticiones (429). Espera unos minutos y reintenta; pedir un solo idioma con --lang ayuda."
  elif grep -qi "unable to download\|unable to extract\|HTTP Error" "$log"; then
    echo "yt-dlp no pudo acceder al video (red, o YouTube cambio algo y toca 'brew upgrade yt-dlp')."
  else
    return 1
  fi
}

# Sale por stderr para no ensuciar la salida capturada.
ytdlp_failed() {
  local log="$1" what="$2"
  local reason
  if reason="$(explain_ytdlp_error "$log")"; then
    echo "error: $reason" >&2
  else
    echo "error: yt-dlp fallo al $what. Salida cruda:" >&2
    tail -n 15 "$log" >&2
  fi
  exit 1
}

TMPLOG="$(mktemp -t yt-notes)"
trap 'rm -f "$TMPLOG"' EXIT

if [ "$LIST_ONLY" -eq 1 ]; then
  echo "Subtitulos disponibles:"
  yt-dlp --list-subs --skip-download "$URL" 2>"$TMPLOG" || ytdlp_failed "$TMPLOG" "listar subtitulos"
  exit 0
fi

echo "Consultando metadata..."

# La descripcion va a un archivo aparte porque es multilinea y romperia el
# parseo por linea de --print. Ojo: --print-to-file *agrega*, no sobrescribe,
# y el destino final depende del slug que sale de esta misma llamada; por eso
# pasa por un temporal vacio y se mueve despues.
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
          "$URL" 2>"$TMPLOG")" || ytdlp_failed "$TMPLOG" "leer la metadata"

TITLE="$(printf '%s\n' "$META"  | awk 'NR==1')"
CHANNEL="$(printf '%s\n' "$META" | awk 'NR==2')"
DURATION="$(printf '%s\n' "$META" | awk 'NR==3')"
UPLOADED="$(printf '%s\n' "$META" | awk 'NR==4')"
PAGE_URL="$(printf '%s\n' "$META" | awk 'NR==5')"
LANGUAGE="$(printf '%s\n' "$META" | awk 'NR==6')"

[ -n "$TITLE" ] || die "yt-dlp no devolvio titulo; la URL puede no ser un video."

# Si no se pidio idioma explicito, el original del video va primero. Para un
# apunte importa la terminologia exacta de quien habla, y los subtitulos
# traducidos de YouTube la pierden justo ahi.
if [ "$LANGS_EXPLICIT" -eq 0 ] && [ -n "$LANGUAGE" ] && [ "$LANGUAGE" != "NA" ]; then
  reordered="$LANGUAGE"
  saved_ifs="$IFS"; IFS=,
  for lang in $LANGS; do
    [ "$lang" = "$LANGUAGE" ] || reordered="${reordered},${lang}"
  done
  IFS="$saved_ifs"
  LANGS="$reordered"
  echo "  idioma original: $LANGUAGE"
fi

SLUG="$(python3 "${HERE}/slugify.py" "$TITLE")"
BASE="${OUTDIR}/${SLUG}"

echo "  $TITLE"
echo "  $CHANNEL · ${DURATION:-?} · ${UPLOADED:-?}"
echo "  slug: $SLUG"

mkdir -p "$OUTDIR"

# La descripcion es donde el autor suele dejar el repo, las slides y el blog:
# la fuente de material relacionado con mejor rendimiento y sin costo extra.
DESC="${BASE}.description"
if [ -s "$TMPDESC" ]; then
  mv "$TMPDESC" "$DESC"
else
  rm -f "$TMPDESC"
  DESC=""
fi

# --- subtitulos ---------------------------------------------------------------

# Primer .srt que exista siguiendo el orden de preferencia de --lang.
# Se usa un arreglo con nullglob: un glob sin match da un arreglo vacio en vez
# de quedarse con el patron literal.
# Primer argumento: "strict" solo acepta los idiomas pedidos; "loose" acepta
# cualquier .srt del video como ultimo recurso.
#
# La distincion importa: al revisar el cache hay que ser estricto, porque si no
# un .srt de una corrida anterior en otro idioma hace que --lang deje de tener
# efecto sin avisar. Despues de bajar si conviene ser flexible, porque YouTube
# devuelve variantes como "en-orig" que no coinciden literal con lo pedido.
find_srt() {
  local mode="$1" lang candidate
  local old_nullglob
  old_nullglob="$(shopt -p nullglob || true)"
  shopt -s nullglob

  local found=""
  local IFS=,
  for lang in $LANGS; do
    # Exacto y "-orig" nada mas. Un glob "${lang}-*" seria una trampa: YouTube
    # nombra las pistas auto-traducidas "<destino>-<origen>", así que "es-*"
    # tambien matchea es-en ("espanol desde ingles"), que en un video en
    # espanol es una traduccion de ida y vuelta. Las variantes regionales
    # (es-419, pt-BR) se piden explicitas con --lang.
    for candidate in "${BASE}.${lang}".srt "${BASE}.${lang}"-orig.srt; do
      [ -f "$candidate" ] || continue
      found="$candidate"
      break
    done
    [ -n "$found" ] && break
  done

  if [ -z "$found" ] && [ "$mode" = "loose" ]; then
    local any=("${BASE}".*.srt)
    [ ${#any[@]} -gt 0 ] && found="${any[0]}"
  fi

  eval "$old_nullglob"
  [ -n "$found" ] && printf '%s\n' "$found"
}

SRT="$(find_srt strict || true)"

if [ -n "$SRT" ] && [ "$FORCE" -eq 0 ]; then
  echo "Ya existe $(basename "$SRT") — reutilizando (usa --force para bajarlo de nuevo)."
else
  echo "Bajando subtitulos ($LANGS)..."
  DOWNLOAD_FAILED=0
  yt-dlp --no-warnings --skip-download \
         --write-subs --write-auto-subs \
         --sub-langs "$LANGS" \
         --sub-format "vtt/srt/best" \
         --convert-subs srt \
         -o "${BASE}.%(ext)s" \
         "$URL" >"$TMPLOG" 2>&1 || DOWNLOAD_FAILED=1

  SRT="$(find_srt strict || true)"
  if [ -z "$SRT" ]; then
    SRT="$(find_srt loose || true)"
    [ -n "$SRT" ] && echo "aviso: no habia subtitulos en '$LANGS'; usando $(basename "$SRT") en su lugar." >&2
  fi

  # yt-dlp sale con codigo distinto de cero si falla *cualquiera* de los
  # idiomas pedidos, aunque los demas hayan bajado bien. Pedir dos idiomas
  # duplica las peticiones y YouTube responde 429 con facilidad. Lo que
  # importa es si quedo un .srt usable, no el codigo de salida.
  if [ "$DOWNLOAD_FAILED" -eq 1 ]; then
    if [ -z "$SRT" ]; then
      ytdlp_failed "$TMPLOG" "bajar los subtitulos"
    fi
    echo "aviso: yt-dlp fallo en alguno de los idiomas pedidos, pero se obtuvo $(basename "$SRT")." >&2
    reason="$(explain_ytdlp_error "$TMPLOG" || true)"
    [ -n "$reason" ] && echo "       $reason" >&2
  fi
fi

if [ -z "$SRT" ]; then
  echo "error: el video no tiene subtitulos en ninguno de estos idiomas: $LANGS" >&2
  echo >&2
  echo "Mira que hay disponible con:" >&2
  echo "  $0 \"$URL\" --list" >&2
  exit 1
fi

# --- texto plano --------------------------------------------------------------

# El .txt lleva el idioma en el nombre: si no, correr el mismo video en dos
# idiomas pisa el archivo anterior sin avisar.
SRT_NAME="$(basename "$SRT")"
SRT_LANG="${SRT_NAME#${SLUG}.}"
SRT_LANG="${SRT_LANG%.srt}"
TXT="${BASE}.${SRT_LANG}.txt"

HEADER="# ${TITLE}
Canal: ${CHANNEL}
Duracion: ${DURATION:-?}
Publicado: ${UPLOADED:-?}
Subtitulos: ${SRT_LANG}
URL: ${PAGE_URL:-$URL}
"

python3 "${HERE}/srt2txt.py" "$SRT" --output "$TXT" --header "$HEADER"

echo
echo "Listo:"
echo "  srt: $SRT"
echo "  txt: $TXT"
if [ -n "$DESC" ]; then
  echo "  desc: $DESC"
  links="$(grep -coE 'https?://[^[:space:]]+' "$DESC" 2>/dev/null || echo 0)"
  [ "$links" -gt 0 ] && echo "        ($links enlaces — revisa si hay repo, slides o blog)"
fi
