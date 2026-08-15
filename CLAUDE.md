# CLAUDE.md — yt-notes

Contexto para Claude Code. Leelo antes de tocar nada.

## Que es

Utilitario personal para convertir una charla de YouTube en un **apunte `.md` de
conceptos** que sirva de banco de memoria: se lee meses despues, cuando ni el
video ni la conversacion original se recuerdan, y se usa como contexto al
trabajar en un tema relacionado.

La transcripcion es plomeria, no el producto. **El producto es `notas/*.md`.**

Uso frecuente y personal, no es un producto. Prioridad: que funcione sin
friccion y sin dependencias pesadas. No es un proyecto de SEPHUS ni de LOOR.

## Como se usa

```
/notes <url-de-youtube>
```

La skill (`.claude/skills/notes/`) corre `transcribe.sh`, lee la transcripcion y
escribe el apunte. **El resumen lo hace Claude en sesion**, no un script ni una
llamada a la API: no hay API key ni facturacion aparte, y se puede preguntar y
corregir mientras se escribe.

## Entorno objetivo (unico)

- macOS 26.x, Apple Silicon (arm64). **No hay que soportar Intel ni Linux.**
- `yt-dlp` y `ffmpeg` via Homebrew. `ffmpeg` no es opcional: YouTube sirve VTT y
  la conversion a SRT pasa por el.
- `python3`. Los scripts de Python son **solo stdlib**.
- Shell: **bash 3.2**, el que trae macOS. Nada de `mapfile`, arreglos
  asociativos ni `${var,,}`.

**Ojo con BSD:** `sed`, `tr` y `ls` son las versiones BSD. Por eso el slug se
genera en `slugify.py` y no con `sed`/`tr`, y la seleccion de archivos usa
arreglos con `nullglob` en vez de parsear `ls`.

## Estructura

```
transcribe.sh              URL -> salida/<slug>.<lang>.srt + .txt
srt2txt.py                 SRT -> parrafos con anclas [mm:ss]. Stdlib.
slugify.py                 Titulo -> slug ASCII. Stdlib.
prompts/notas.md           Plantilla del apunte.
.claude/skills/notes/      La skill /notes.
notas/                     EL PRODUCTO. Versionado.
salida/                    Transcripciones. Ignorado por git.
```

Flujo de `transcribe.sh`:

1. Lee metadata con `yt-dlp --print` (titulo, canal, duracion, fecha, URL,
   idioma). Sin `--lang`, el idioma original del video pasa al frente de la
   lista de preferencia.
2. Titulo -> slug via `slugify.py`.
3. Si el `.srt` ya existe y no hay `--force`, lo reutiliza.
4. Baja subtitulos publicados (`--write-subs --write-auto-subs`) y los convierte
   a SRT con `--convert-subs srt`.
5. Elige el `.srt` segun el orden de preferencia de `--lang`.
6. `srt2txt.py` -> `.txt` limpio con anclas de tiempo.

Salidas: `.srt` (crudo) y `.txt` (parrafos con `[mm:ss]`). **Las anclas del
`.txt` son de donde salen los timestamps del apunte** — son el enlace de vuelta
a la fuente, no decoracion.

## Reglas

- `srt2txt.py` y `slugify.py` usan **solo stdlib**. No agregar dependencias.
- No introducir servicios pagos ni llamadas de red fuera de yt-dlp.
- El `.txt` lleva el idioma en el nombre a proposito: sin eso, correr el mismo
  video en dos idiomas pisa el archivo anterior sin avisar.
- En los apuntes, **nunca mezclar lo que dice el autor con la interpretacion
  propia**. Lo propio va en la seccion "Notas propias".
- Los timestamps no se inventan ni se aproximan. Se copian de las anclas.
- Preferir el **idioma original del hablante** para el apunte. Los subtitulos
  traducidos de YouTube pierden matiz justo en la terminologia. El script ya lo
  hace solo; no lo pises con `--lang` sin razon.
- **Las pistas auto-traducidas de YouTube se llaman `<destino>-<origen>`**, así
  que `es-en` es "espanol desde ingles": en un video en espanol, una traduccion
  de ida y vuelta. Por eso la busqueda de `.srt` matchea exacto y `-orig`, y
  nunca `${lang}-*`. Las variantes regionales (`es-419`) se piden explicitas.

## Estado

Probado end-to-end contra YouTube real (charla TED de 14 min, subtitulos
manuales en `es` y `en`): metadata, slug, descarga, cache, preferencia de
idioma, dedup de ventana rodante, anclas de tiempo y apunte final. `srt2txt.py`
tambien probado contra un SRT sintetico con duplicados rodantes y etiquetas
`<c>`. Errores de yt-dlp (video inexistente, privado, restringido, geobloqueado)
traducidos a mensajes legibles; el de "no existe" verificado contra la red real.

## Pendientes (en orden)

1. **ASR para videos sin subtitulos.** Hoy `--asr` sale con un error explicito.
   La mayoria de charlas de gente con autoridad tienen subtitulos publicados,
   así que esto vale la pena solo cuando aparezca un video real que lo necesite
   — son ~1.6 GB de modelo y una dependencia pesada (`mlx-whisper` via pipx)
   para un caso que todavia no se ha dado. **Si se implementa: los flags de
   `mlx_whisper` NO estan verificados contra la version instalada; correr
   `mlx_whisper --help` primero.**

2. **Elegir idioma interactivamente.** Si se pide `--lang es` y solo hay
   ingles, hoy avisa y usa lo que encuentre. Mejor: listar lo disponible y
   dejar decidir antes de bajar.

3. **Partir transcripciones largas.** Una clase de 1h entra en contexto sin
   problema, pero si aparece algo de 3h+ va a hacer falta `--split N` cortando
   en frontera de frase.

4. **Notas que se citen entre si.** Cuando haya varios apuntes del mismo tema,
   enlazarlos con `[[wikilinks]]` para que se lean como un cuerpo y no como
   archivos sueltos.
