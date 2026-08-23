---
name: notes
description: Convierte un video de YouTube en un apunte .md de conceptos con timestamps, guardado en notas/. Usar cuando el usuario pasa una URL de YouTube y quiere apuntes, resumen, conceptos o "pasar esto a memoria".
---

# /notes: video de YouTube a apunte de conceptos

Objetivo: dejar un `.md` que sirva de banco de memoria meses despues, cuando ni
el video ni esta conversacion se recuerden. El apunte se lee en frio.

## Procedimiento

### 0. Decir con que se va a correr

Antes de bajar nada, dile al usuario en dos o tres lineas con que valores por
defecto vas a trabajar. **No es una pregunta:** sigue de largo en el mismo
turno. La idea es que sepa que hay perillas, no frenarlo cada vez.

| Que | Por defecto | Como cambiarlo |
|---|---|---|
| Subtitulos | idioma original del video, detectado solo | pedir otro idioma, o `--list` para ver que hay |
| Idioma del apunte | el de la conversacion, aunque la charla este en otro | pedir el del video, o cualquier otro |
| Material de respaldo | se busca y se verifica cada enlace | saltarlo si hay prisa |
| Alcance | apunte completo segun la plantilla | mas corto, o centrado en un tema |
| Destino | `notas/<slug>.md`, local y sin versionar | otra ruta |

Si el usuario ya dijo lo que quiere al invocar la skill ("en ingles", "solo lo
que diga de embudos"), respetalo y **no repitas el menu**: confirmalo en una
linea y arranca.

### 1. Sacar la transcripcion

```bash
./transcribe.sh "<url>"                 # detecta el idioma original solo
./transcribe.sh "<url>" --lang es       # forzar uno
./transcribe.sh "<url>" --list          # ver que hay disponible
```

Sin `--lang`, el script lee el idioma original del video y lo pone primero.
**Eso es lo que casi siempre se quiere:** los subtitulos traducidos de YouTube
pierden matiz justo en la terminologia, que es lo que el apunte busca capturar.
Si una charla en ingles sale con texto en espanol, algo se hizo mal.

El script imprime la ruta del `.txt`. Si falla porque no hay subtitulos, muestra
lo disponible con `--list` y preguntale al usuario: **no** asumas otro idioma ni
caigas en una pista traducida por tu cuenta.

Ojo con las pistas auto-traducidas: YouTube las nombra `<destino>-<origen>`, así
que `es-en` es "espanol desde ingles". En un video en espanol eso es una
traduccion de ida y vuelta y el texto sale degradado. El script ya evita
elegirlas solo; si pasas `--lang` explicito, no las pidas.

### 2. Leer la transcripcion completa

Lee el `.txt` entero antes de escribir nada. Los parrafos vienen con anclas
`[mm:ss]`: de ahi salen los timestamps del apunte.

No resumas mientras lees. Primero entiende el argumento completo: muchas
charlas ponen la tesis real al final, no al principio.

**Detecta si los subtitulos son automaticos.** El indicio son las cifras rotas
("7 m,0000000esó", "$,000 al mes") y los nombres propios deformados ("Pure
Research" por Pew Research). En los videos con subtitulos manuales esto no
pasa, pero en podcasts largos es la norma. Cuando el texto venga asi, marca en
el apunte las cifras y los nombres como no verificados en vez de copiarlos como
si fueran fieles: el apunte se lee en frio y no habra forma de saberlo despues.

### 3. Buscar el material de respaldo

**Una charla casi nunca es la fuente completa.** Es la version comprimida de
algo que suele existir en forma mas extensa: el repo del autor, las slides, el
post o el paper donde esta la teoria entera. Encontrarlo multiplica el valor
del apunte, porque deja un lugar al que volver cuando el tema reaparezca.

Busca en este orden, de mas barato a mas caro:

1. **El `.description`** que deja `transcribe.sh` junto al `.txt`. Es donde el
   autor pone sus enlaces y es la fuente con mejor rendimiento.

   Separa lo del **autor** del relleno del **canal**. Las redes del canal, la
   politica de uso, los patrocinadores, el merch y los "suscribete" no son
   material de respaldo. El blog, el repo, el libro o el sitio de quien habla
   si lo son.

2. **La transcripcion.** Los ponentes nombran su repo, su libro, su blog o el
   paper en el que se basan. Buscar `github`, `http`, "mi libro", "el paper",
   "escribi sobre esto" suele dar. Los nombres propios de herramientas y
   frameworks tambien son pistas.

3. **Busqueda web**, solo si 1 y 2 no alcanzaron. Combina el nombre de quien
   habla con el tema o el titulo: `<autor> github`, `<autor> slides <tema>`,
   `<autor> blog <concepto>`.

**Verifica cada enlace antes de ponerlo.** Abrelo y confirma que existe y que
de verdad corresponde a esta charla y a este autor. Un enlace inventado o
equivocado en un banco de memoria es peor que no tener enlace: se va a leer en
frio dentro de meses, cuando ya no haya forma de detectar el error.

Si la busqueda no da nada, **dilo en el apunte** en vez de omitirlo. "No se
encontro repo ni slides" es informacion util: evita repetir la busqueda.

### 4. Escribir `notas/<slug>.md`

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

1. Agrega una linea a `notas/README.md`: `- [Titulo](slug.md): gancho de una linea`.
   El gancho arranca con el contenido, no con "Autor:", que dejaria dos puntos
   dobles en la misma linea.
2. Dile al usuario la ruta y resume en 2-3 lineas que se capturo.
3. Di tambien lo que quedo por debajo de lo util: subtitulos automaticos que
   destrozaron cifras, material de respaldo que no aparecio, atribuciones que
   no cuadraron al verificarlas. Eso es lo que el usuario necesita para decidir
   si vuelve a la fuente.

Nada de esto se versiona: el repo es la herramienta, no los apuntes. El `.txt` y
el `.srt` quedan en `salida/` y el apunte en `notas/`, ambos locales. No los
agregues a git ni sugieras commitearlos.
