# yt-notes

Convierte una charla de YouTube en un apunte `.md` de conceptos, con timestamps
de vuelta a la fuente.

La idea: cuando ves una charla buena —alguien con autoridad real en un tema,
explicando ideas y estrategia— quieres quedarte con eso. No con un resumen que
se lee bonito y se olvida, sino con algo que sirva de banco de memoria: se lee
en frío meses después y se puede pegar como contexto al trabajar en un tema
relacionado.

**La transcripción es plomería. El producto es `notas/*.md`.**

## Requisitos

macOS con Apple Silicon. Todo lo demás:

```bash
brew install yt-dlp ffmpeg
```

`ffmpeg` no es opcional: YouTube sirve los subtítulos en VTT y la conversión a
SRT pasa por él. Los scripts de Python usan solo stdlib, así que no hay nada
que instalar ahí.

## Uso

Dentro de una sesión de Claude Code, en este repo:

```
/notes https://www.youtube.com/watch?v=...
```

Eso baja los subtítulos, lee la transcripción completa y escribe
`notas/<slug>.md`. **El resumen lo hace Claude en la sesión**, no un script ni
una llamada a la API: no hay API key ni facturación aparte, y puedes corregir y
preguntar mientras se escribe.

### Solo la transcripción

Si quieres el texto y nada más:

```bash
./transcribe.sh "<url>"              # detecta el idioma original del video
./transcribe.sh "<url>" --lang es    # forzar idioma
./transcribe.sh "<url>" --list       # ver qué subtítulos hay
./transcribe.sh "<url>" --force      # re-descargar ignorando lo cacheado
```

Deja en `salida/`:

| Archivo | Qué es |
|---|---|
| `<slug>.<lang>.srt` | crudo, con timestamps |
| `<slug>.<lang>.txt` | limpio, en párrafos, con anclas `[mm:ss]` |

Re-correr la misma URL reutiliza lo que ya bajó.

## Cómo queda un apunte

La plantilla completa está en [`prompts/notas.md`](prompts/notas.md) — `notas/`
va vacío en un clon nuevo, porque los apuntes son locales. La estructura:

- **Fuente** — canal, duración, fecha, quién habla y por qué es autoridad
- **Tesis central** — la idea que sostiene la charla, en tres líneas
- **Conceptos** — cada uno con su `[mm:ss]`
- **Frameworks / claims / ejemplos** — lo accionable y lo verificable
- **Límites de la charla** — qué NO cubre, para no citarla de más después
- **Notas propias** — interpretación tuya, separada de lo que dijo el autor

Los timestamps son el punto. Son el enlace de vuelta al minuto exacto cuando
seis meses después quieres verificar algo o volver a ver ese pedazo.

La plantilla vive en [`prompts/notas.md`](prompts/notas.md) y se puede ajustar.

## Sobre el idioma

Vale la pena saber esto porque es la trampa menos obvia del proyecto.

Sin `--lang`, el script detecta el idioma original del video y lo prefiere. Es
casi siempre lo que quieres: los subtítulos traducidos de YouTube pierden matiz
justo en la terminología, que es lo que el apunte busca capturar.

YouTube nombra las pistas auto-traducidas `<destino>-<origen>`. O sea `es-en`
es "español **desde** inglés" — en un video que ya está en español, una
traducción de ida y vuelta. El script nunca las elige solo; si pasas `--lang`
explícito, no las pidas.

Con `--list` ves qué hay antes de decidir.

## Limitaciones

- **Solo videos con subtítulos publicados.** No hace transcripción por audio
  todavía; `--asr` sale con un error explícito. La mayoría de charlas de gente
  con autoridad tienen subtítulos, así que no ha hecho falta.
- Videos privados, de miembros, con restricción de edad o geobloqueados fallan
  con un mensaje que explica cuál de esos casos es.

## Estructura

```
transcribe.sh              URL -> .srt + .txt
srt2txt.py                 SRT -> párrafos con anclas [mm:ss]
slugify.py                 título -> slug de archivo
prompts/notas.md           plantilla del apunte
.claude/skills/notes/      la skill /notes
notas/                     EL PRODUCTO. Local, no versionado.
salida/                    transcripciones. Local, no versionado.
```

**Este repo es la herramienta, no los apuntes.** Nada del contenido se
versiona: las transcripciones son derivadas y se regeneran, y los apuntes son
personales, crecen sin parar y su valor es local. Si quieres respaldarlos o
llevarlos a otra máquina, sincroniza `notas/` por fuera de git.
