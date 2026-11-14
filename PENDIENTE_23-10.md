# PENDIENTE 23/10

Lo que queda de la sesión del 23/10/2026. Todo está en la rama
`audio-por-bloque`, **sin commit** (junto con lo del audio de antes).

---

## Qué se hizo hoy

### 1. Gestos del audio en el lector

| Gesto | Qué hace ahora |
|---|---|
| 1 toque | Traducción + suena esa palabra (igual que antes) |
| 2 toques | Lee **desde esa palabra**, de corrido, pasando de página sola |
| Mantener 2 s | Lee **solo ese párrafo**, de principio a fin |

Antes 2 toques y mantener estaban al revés. Archivos: `reader_screen.dart`,
`text_block_widget.dart` y `test/read_aloud_gestures_test.dart`.

### 2. Imágenes en blanco sin conexión: arreglado

**Causa:** las imágenes iban a la caché por defecto de `flutter_cache_manager`,
que guarda **como mucho 200 archivos** y borra lo que no se mire en 30 días. El
libro 1 tiene 226 imágenes (unas 360 entre todos los libros, más las portadas):
al terminar la descarga, la limpieza borraba las que sobraban. Encima vivía en
la carpeta temporal, que Android vacía cuando le falta espacio.

**Arreglo:**
- `lib/data/local/offline_cache.dart` (nuevo): caché `BookImages` sin límite,
  en la carpeta de soporte de la app (no en la temporal).
- El lector (`image_block_widget.dart`) lee de esa caché.
- El audio (`BlockAudio.cache`) también pasa a la carpeta de soporte; lo ya
  descargado se mueve solo, sin volver a bajarlo.
- Los libros ya descargados recuperan solos las imágenes que siguieran en la
  caché vieja. Las que se hubieran borrado salen como «Faltan N imágenes».
- Nueva dependencia `file` en `pubspec.yaml`.

### 3. Otros arreglos de la descarga (`book_download_service.dart`)
- Fragmentos pedidos por tramos de 1000 (antes un tramo de bloques largos podía
  quedarse sin parte de la traducción sin avisar).
- Tope de 60 s por petición y por archivo (antes una red caída dejaba la
  descarga colgada en el mismo % y no dejaba reintentar).
- 3 intentos por imagen o audio antes de darlo por fallido.
- «Actualizar descarga» solo baja las imágenes que faltan.
- La ficha avisa si faltan imágenes al terminar (antes decía «Descargado»
  igual).
- «Eliminar» borra también las imágenes y el audio del libro del móvil.

`flutter analyze` sin problemas y los 21 tests pasan. APK nuevo compilado en
`build/app/outputs/flutter-apk/app-release.apk`.

---

## Pendiente

1. [ ] **Probar en un móvil real** el APK del 23/10:
   - Abrir la ficha de un libro ya descargado con internet. Si dice
     «Faltan N imágenes», tocar «Completar descarga».
   - Modo avión → abrir el libro → ir a páginas con imágenes (el libro 1 tiene
     226): deben verse todas.
   - Comprobar que el audio ya descargado sigue sonando sin conexión (se movió
     de carpeta).
   - Eliminar la descarga de un libro y volver a descargarlo.
2. [ ] **Probar los gestos nuevos** en el móvil: 1 toque, 2 toques (leer de
   corrido) y mantener (solo el párrafo).
3. [ ] Decidir dos detalles de los gestos:
   - Mantener pulsado lee el párrafo **desde el principio**. ¿O mejor desde la
     palabra pulsada hasta el final del párrafo? (cambio de una línea en
     `_onBlockLongPress`, `reader_screen.dart`).
   - ¿Bajar los 2 s de la pulsación larga (p. ej. a 1 s)?
     (`TextBlockWidget.longPressDuration`).
4. [ ] **Web sin conexión**: allí las imágenes y el audio no se guardan (la
   caché vive en memoria), así que sin internet no se ven. Si hace falta,
   guardarlos en IndexedDB o con un service worker.
5. [ ] **Commit** de la rama `audio-por-bloque` (audio + gestos + descargas),
   sin la línea `Co-Authored-By: Claude`, como los anteriores.
6. [x] **Descarga en segundo plano + notificación al terminar.** HECHO el
   23/10, falta probarlo en el móvil (ver «Cómo probar el punto 6» abajo).
   - Android: la descarga (libro, «Completar descarga» y audio) corre en un
     servicio en primer plano (`flutter_foreground_task`, tipo `dataSync`)
     con su propio motor de Flutter. Sigue con el móvil bloqueado y con la app
     cerrada desde recientes.
   - Notificación fija con el progreso («Descargando… 45 %») y botón
     **Cancelar**. En la ficha también hay un botón «Cancelar».
   - Al terminar: aviso «Listo para leer sin conexión» (o «faltan N
     imágenes», o «no se pudo descargar»). Al tocarlo se abre la ficha del
     libro (`flutter_local_notifications`).
   - La cola se guarda en disco: si el sistema mata el servicio, se vuelve a
     levantar, y al abrir la app se retoma lo pendiente.
   - Varios libros a la vez: se encolan y bajan uno detrás de otro.
   - Web e iOS: como antes, con la app abierta (iOS mata las tareas en
     segundo plano a los ~30 s).
   - Archivos: `lib/data/background/` (nuevo), `download_manager.dart`,
     `book_download_service.dart`, `book_detail_screen.dart`,
     `home_screen.dart`, `main.dart`, `lib/core/supabase_config.dart` (nuevo),
     `AndroidManifest.xml`, `android/app/build.gradle.kts` (desugaring) e
     icono `res/drawable/ic_stat_download.xml`.
   - La base local pasa a modo WAL, porque ahora escriben dos isolates.
   - Ojo: `dart format` reformateó también partes ya existentes de
     `book_detail_screen.dart` y `main.dart` (solo espacios y saltos de línea).

### Cómo probar el punto 6

1. Instalar el APK nuevo. La primera descarga pide permiso de notificaciones:
   aceptarlo.
2. Descargar un libro grande (el 1) → salir de la app y **cerrarla desde
   recientes**. La notificación de progreso debe seguir avanzando.
3. Al terminar: aviso «Listo para leer sin conexión». Tocarlo → abre la app
   en la ficha del libro.
4. Bloquear el móvil a mitad de una descarga: debe seguir.
5. «Cancelar» en la notificación y en la ficha: debe parar y la ficha decir
   «Descarga cancelada».
6. Pedir dos libros seguidos: deben bajar uno detrás de otro.
7. Modo avión a mitad: tiene que acabar con el aviso «No se pudo descargar».
8. En algunos móviles (Xiaomi, Huawei, Samsung con ahorro agresivo) puede
   hacer falta quitar la optimización de batería de BlackReader si el sistema
   corta el servicio.

Lo que sigue pendiente del generador de audio está en
`../audiolibro/ESTADO_30-09.md` §9.
