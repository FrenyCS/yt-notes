---
name: notes
description: Convierte un video de YouTube en un apunte .md de conceptos con timestamps, guardado en notas/. Usar cuando el usuario pasa una URL de YouTube y quiere apuntes, resumen, conceptos o "pasar esto a memoria".
---

# /notes — video de YouTube a apunte de conceptos

Objetivo: dejar un `.md` que sirva de banco de memoria meses despues, cuando ni
el video ni esta conversacion se recuerden. El apunte se lee en frio.

## Procedimiento

### 1. Sacar la transcripcion

```bash
./transcribe.sh "<url>"              # default: subtitulos es, luego en
./transcribe.sh "<url>" --lang en    # forzar el idioma original
```

Prefiere el **idioma original del hablante** cuando el video sea una charla de
alguien con autoridad en el tema. Los subtitulos traducidos de YouTube pierden
matiz justo en la terminologia, que es lo que se quiere capturar. Si la charla
es en ingles, corre `--lang en`.

El script imprime la ruta del `.txt`. Si falla porque no hay subtitulos,
muestra que hay disponible con `--list` y preguntale al usuario, **no** asumas
otro idioma.

### 2. Leer la transcripcion completa

Lee el `.txt` entero antes de escribir nada. Los parrafos vienen con anclas
`[mm:ss]` — de ahi salen los timestamps del apunte.

No resumas mientras lees. Primero entiende el argumento completo: muchas
charlas ponen la tesis real al final, no al principio.

### 3. Escribir `notas/<slug>.md`

Usa el mismo slug del `.txt`. Plantilla en `prompts/notas.md`.

## Que hace bueno a un apunte

- **Conceptos, no cronologia.** Nadie quiere "primero dijo X, luego Y".
  Organiza por idea, aunque el video las presente en otro orden.
- **Timestamps reales en cada concepto.** Son el hipervinculo de vuelta a la
  fuente. Copialos de las anclas del `.txt`, no los inventes ni los aproximes.
- **Distingue lo que dice el autor de lo que interpretas tu.** Si agregas algo
  que no esta en la charla, marcalo como nota propia. El apunte se va a leer
  como si fuera la fuente.
- **Cita textual donde la formulacion importa.** Una definicion o una frase
  bien armada se cita; el resto se parafrasea.
- **Densidad sobre longitud.** Si la charla tiene tres ideas, el apunte tiene
  tres ideas. No lo infles para que parezca completo.
- **Anota lo que NO cubrio** si es relevante: los limites de la charla evitan
  citarla despues como autoridad sobre algo que nunca toco.

## Al terminar

1. Agrega una linea a `notas/README.md`: `- [Titulo](slug.md) — gancho de una linea`
2. Dile al usuario la ruta y resume en 2-3 lineas que se capturo.

El `.txt` y el `.srt` se quedan en `salida/` (ignorados por git). El apunte en
`notas/` si se versiona: ese es el producto.
