# Plantilla de apunte

Estructura de `notas/<slug>.md`. Omite las secciones que no apliquen (una
seccion vacia es peor que ninguna), pero **Fuente**, **Tesis central** y
**Conceptos** van siempre.

```markdown
# <Titulo del video>

**Fuente:** [<Canal>: <Titulo>](<url>) · <duracion> · publicado <YYYY-MM-DD>
**Quien habla:** <nombre y por que es autoridad en esto, una linea>
**Apuntado:** <YYYY-MM-DD> · subtitulos: <lang>
**Temas:** <tag>, <tag>, <tag>

## Tesis central

Dos o tres lineas. La idea que sostiene toda la charla. Si no se puede escribir
en tres lineas, probablemente no se entendio.

## Conceptos

### <Nombre del concepto> `[mm:ss]`

Que es, en dos o tres lineas. Despues por que importa o que problema resuelve.
Si el autor le puso nombre propio, usa el nombre del autor.

> Cita textual cuando la formulacion exacta valga mas que la parafrasis.

### <Otro concepto> `[mm:ss]`

...

## Frameworks y estrategias

Los procedimientos accionables: pasos, criterios de decision, reglas. Con
timestamp. Si no hay ninguno, borra la seccion.

## Claims notables

Afirmaciones fuertes, cifras, predicciones. Con timestamp, para poder verificar
despues contra la fuente.

- "<claim>" `[mm:ss]`

## Ejemplos y casos

Los casos concretos que uso para argumentar. Se olvidan antes que los conceptos
y son lo que los hace recordables.

## Material de respaldo

Donde esta la version completa de esto. Una charla es la version comprimida;
aca va lo que la respalda. Cada enlace **verificado**, con una linea de que es
y por que volver a el.

- [<que es>](<url>): <por que volver a el, p. ej. "la teoria completa",
  "el codigo", "las slides con los diagramas">

Si no se encontro nada, decirlo explicitamente para no repetir la busqueda:
`Buscado repo, slides y blog del autor: no se encontro nada.`

## Limites de la charla

Que NO cubre, que asume, sobre que contextos aplica. Evita citarla despues como
autoridad sobre algo que nunca toco.

## Notas propias

Marcado explicito como interpretacion tuya, no del autor. Donde conecta con
trabajo actual, con que choca, que probar.
```

## Reglas

- Los timestamps salen de las anclas `[mm:ss]` del `.txt`. No se inventan ni se
  aproximan: son el enlace de vuelta a la fuente y si estan mal, el apunte deja
  de ser verificable.
- Nunca mezclar lo que dice el autor con lo que interpreta quien apunta. Todo lo
  propio va en **Notas propias** o marcado en linea.
- Organizar por concepto, no por orden cronologico del video.
- **Sin raya (`—`).** Segun el caso: coma, dos puntos, punto y seguido, o
  parentesis para los incisos. Aplica a todo el apunte, incluida la linea de
  **Fuente** y las de material de respaldo.
- Sin relleno. Tres ideas buenas valen mas que diez secciones a medias.
- **Ningun enlace sin abrir.** En material de respaldo va solo lo verificado.
  Un enlace inventado en un banco de memoria es peor que ninguno: se lee en
  frio meses despues, cuando ya no hay como detectar el error.
