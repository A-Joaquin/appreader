# PENDIENTE 22/09

Lo que queda de la sesión del 21/09/2026, actualizado el 22/09. Ordenado por lo
que bloquea a lo que puede esperar.

---

## 1. Correr la migración de reportes (BLOQUEANTE)

Sin esto la función de reportar **no guarda el mensaje ni se puede marcar nada
como resuelto**.

- Archivo: `supabase/migrations/0002_word_reports.sql`
- Cómo: pegar el archivo entero en Supabase → SQL Editor → Run (igual que la 0001).
- **No crea la tabla**: `word_reports` ya existía con datos. Le añade `message`,
  `status`, `resolved_at` y `resolved_by`, los valores de `word_report_type` que
  faltaban (`bad_translation`, `bad_format`, `other` — `missing_translation` ya
  estaba y se conserva) y le pone RLS con políticas. Es idempotente.

Ojo con la RLS: hasta correrla, `word_reports` **se puede leer con la anon key**
sin estar logueado (probado: devuelve las filas con su `user_id`).

Mientras no se corra, la app no se rompe: el insert falla y el reporte se queda
en la cola local (`SharedPreferences`), y se sube solo en cuanto exista la
columna.

## 2. Probar el flujo de reportes de punta a punta

No se ha podido probar contra la base de datos real porque faltan las columnas.
Lo que SÍ está comprobado sin base de datos (`test/word_report_test.dart`): la
ida y vuelta por la cola local no pierde campos, el payload del insert usa
exactamente las columnas de `word_reports`, y las filas antiguas (sin `message`
ni `status`) se siguen leyendo bien en el panel.

Queda por verificar a mano, en este orden:

1. En el lector, tocar una palabra → icono de **bandera** en la barra de traducción.
2. Elegir tipo de problema (+ mensaje opcional; obligatorio en "Otro problema") → Enviar.
3. Entrar en `/admin` → pestaña **Reportes** → que aparezca con libro, página,
   la palabra y su traducción, y el texto reportado en los dos idiomas. Ahí
   deberían salir también los 2 reportes del 30/06 que ya estaban en la tabla.
4. Marcar **resuelto** y que desaparezca del filtro "Solo pendientes".
5. Probar en **modo avión**: debe decir "Se enviará cuando haya conexión" y
   subirse después al volver la red o al reiniciar sesión.

## 3. Probar el arranque sin internet en un móvil real

El arreglo del splash colgado está hecho y compila, pero **nunca se probó en un
dispositivo** (sigue sin haber ninguno en `flutter devices`: solo Windows, Chrome
y Edge).

- Instalar `build/app/outputs/flutter-apk/app-release.apk`.
- Activar **modo avión** y abrir la app: debe pasar del splash a la biblioteca
  con los libros descargados, sin quedarse en la animación.

## 4. ~~Pipeline: títulos que pierden el salto de línea~~ — RESUELTO EN EL FRONT

**El `\n` no se lo había comido nadie.** Sigue en `original_content` del bloque,
en el hueco entre el `char_end` de un fragmento y el `char_start` del siguiente:
el fragmentador corta por oraciones y ese trozo queda fuera de los dos. Lo que
lo perdía era el lector, que volvía a pegar los fragmentos con un espacio fijo.

Comprobado sobre el corpus entero (8 libros, 6.790 bloques, 13.112 fragmentos):
los `char_start` / `char_end` casan **exacto en el 100 %** de los fragmentos, y
los huecos entre fragmentos son **siempre** espacios o saltos, nunca texto. Así
que el lector ya no pega fragmentos: pinta el trozo real del bloque y mapea cada
palabra a su fragmento por offsets (el `word_map` sigue alineado igual).

Con el texto real delante, la decisión de qué `\n` es un salto de verdad se toma
con tres reglas (`text_block_widget.dart`), y ninguna rompe si lo que sigue
empieza en minúscula:

1. **Bloque estructurado por líneas**: si ≥ 0,65 de sus líneas cierran frase, el
   PDF no estaba justificando un párrafo sino poniendo una entrada por línea
   (diálogo, ejercicio, reseñas) → se respetan todos sus saltos. La distribución
   medida es bimodal (prosa 0,0–0,5; diálogos 0,7–1,0), así que el umbral cae en
   el valle.
2. **Marcador de lista** detrás (`•`, `2.`, `- `).
3. **Línea corta**: se cortó por debajo del 0,75 del ancho de columna del bloque.

Resultado en el corpus: **1.100 saltos añadidos y 58 quitados** — y esos 58 eran
falsos, de los que hoy parten una frase a la mitad ("worked at | Twitter"),
porque el ancho de columna se medía sobre los fragmentos pegados con espacio y
salía inflado (152 en vez de 87).

Fijado en `test/text_block_widget_test.dart` con bloques copiados de la base real:
título (bloque 48), prosa justificada (bloque 5), diálogo (bloque 2006) y que el
tap siga devolviendo el offset relativo al fragmento.

**No hace falta tocar el pipeline.**

## 5. ~~Commit del trabajo de la sesión~~ — HECHO

Queda commiteado en cuatro: arranque offline, splash animado, reportes y formato
del lector. Los commits van **sin** la línea `Co-Authored-By: Claude`.

---

## Notas sueltas

- El servidor local de la web (`http://127.0.0.1:8080`) se cae al cerrar la
  sesión. Para levantarlo otra vez:
  `cd build/web && python -m http.server 8080 --bind 127.0.0.1`
- Para revisar cambios visuales del lector con un test temporal: la fuente del
  cuerpo es **Georgia**, hay que cargarla con `FontLoader` o el texto sale en
  cuadrados. (Los tests de `text_block_widget` no la necesitan: miran los spans,
  no los píxeles.)
- Los scripts con los que se midió el corpus no están en el repo (eran de
  usar y tirar, contra la anon key de `tools/check_wordmap_quality.py`).
