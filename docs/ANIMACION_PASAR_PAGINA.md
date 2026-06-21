# Animación de pasar página (page curl) — cómo funciona

> Documento de aprendizaje. Explica, paso a paso, la animación de "hoja
> doblándose" del lector de BlackReader y los conceptos de Flutter que usa.
> Todo el código vive en `lib/presentation/reader/reader_screen.dart`.

---

## 1. La idea en una frase

Cuando pasas de página **no movemos dos páginas a la vez**. El bloc del lector
tiene **una sola página en memoria**, así que el truco es:

1. Tomamos una **foto** (snapshot) de la página que estás dejando.
2. Cambiamos el contenido a la página nueva (queda **debajo**).
3. Dibujamos la foto de la página vieja **curvándose y pelándose** por encima,
   y conforme se curva se va **revelando** la página nueva.

Es exactamente como en la vida real: la hoja que se levanta es la vieja, y
debajo aparece la nueva.

```
  ___________            ___________
 |  pág 7    |          |  p|\      |
 |  texto    |   --->   |  á| \  p8 |
 |  ...      |          |  g|  \    |
 |___________|          |__7|___\___|
  (plana)               (curvándose; debajo asoma la pág 8)
```

---

## 2. Las piezas de Flutter que intervienen

| Pieza | Para qué la usamos |
|------|--------------------|
| `AnimationController` | El "reloj" 0→1 que dura la animación (520 ms). |
| `RepaintBoundary` + `toImageSync()` | Capturar la página actual como imagen GPU **sin parpadeo**. |
| `CustomPainter` + `drawVertices` | Dibujar esa imagen deformada sobre un cilindro (la curva). |
| `Stack` | Apilar: página viva (abajo) + curl (encima) + barra de traducción. |
| `GestureDetector` (`onHorizontalDragEnd`) | Detectar el swipe para disparar el cambio de página. |
| `BlocConsumer` (`listener`) | Detectar que la página cambió y arrancar la animación. |

---

## 3. El "reloj": AnimationController

```dart
late final AnimationController _pageAnim = AnimationController(
  vsync: this,                              // necesita SingleTickerProviderStateMixin
  duration: const Duration(milliseconds: 520),
  value: 1, // arranca "terminado" para que el primer frame no esté a medias
);
```

- `vsync: this` sincroniza la animación con el refresco de pantalla (evita gastar
  batería animando cuando la pantalla no se está pintando). Por eso la clase
  usa `with SingleTickerProviderStateMixin`.
- `value` va de **0.0 a 1.0**. Nosotros lo interpretamos como "progreso del
  giro": 0 = hoja plana sin levantar, 1 = hoja ya volteada del todo.
- `_pageAnim.forward(from: 0)` reinicia y reproduce la animación.

⚠️ Regla de oro: **todo `AnimationController` se libera en `dispose()`** o se
fuga memoria:

```dart
@override
void dispose() {
  _curlImage?.dispose(); // también liberamos la imagen GPU
  _pageAnim.dispose();
  super.dispose();
}
```

---

## 4. Capturar la página vieja SIN parpadeo: RepaintBoundary + toImageSync

Envolvemos el contenido vivo de la página en un `RepaintBoundary` con una
`GlobalKey`. Eso nos permite, en cualquier momento, "fotografiar" justo ese
trozo del árbol de widgets:

```dart
RepaintBoundary(
  key: _pageBoundaryKey,
  child: ColoredBox(                       // ← fondo OPACO (ver §7, bug importante)
    color: Theme.of(context).scaffoldBackgroundColor,
    child: GestureDetector( ... ScrollablePositionedList ... ),
  ),
),
```

Y la captura:

```dart
ui.Image? _capturePage() {
  final boundary = _pageBoundaryKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;
  if (boundary == null || !boundary.hasSize) return null;
  return boundary.toImageSync(pixelRatio: _curlDpr);
}
```

- `toImageSync` es **síncrono**: devuelve la imagen al instante (no hay `await`).
  Eso es clave: si fuera asíncrono habría un hueco de uno o dos frames y se vería
  un parpadeo. La versión síncrona usa la última capa ya pintada en GPU.
- `pixelRatio: _curlDpr` captura a la densidad real de la pantalla para que la
  foto no se vea borrosa. Guardamos ese ratio en `build`:
  `_curlDpr = MediaQuery.devicePixelRatioOf(context);`

### ¿Por qué la foto sale de la página VIEJA y no de la nueva?

Por el **orden de los frames**. Cuando el bloc emite el estado nuevo, el
`listener` se ejecuta **antes** de que se pinte el frame nuevo. En ese instante
el `RepaintBoundary` todavía tiene pintada la página anterior, así que
`toImageSync` nos da la vieja. Inmediatamente después, el `builder` pinta la
nueva debajo. 

---

## 5. Disparar la animación cuando cambia la página

No disparamos la animación en el swipe directamente, sino cuando el **estado**
del bloc confirma que la página cambió. Así funciona con cualquier fuente:
swipe, botones "Anterior/Siguiente", el diálogo "Ir a la página" y el drawer.

```dart
listener: (context, state) {
  if (!state.isLoading && state.error == null) {
    if (state.currentPage != _renderedPage) {
      final previous = _renderedPage;
      _renderedPage = state.currentPage;
      _startCurl(previous, state.currentPage);
    }
  }
},
```

```dart
void _startCurl(int previousPage, int newPage) {
  _navDirection = newPage > previousPage ? 1 : -1;   // ¿avanza o retrocede?
  final snapshot = _capturePage();
  _curlImage?.dispose();
  _curlImage = snapshot;
  _curlForward = _navDirection > 0;
  if (snapshot == null) {
    _pageAnim.value = 1; // sin foto → sin efecto, mostramos la nueva directo
  } else {
    _pageAnim.forward(from: 0);
  }
}
```

La **dirección** se deduce comparando el número de página nuevo con el anterior
(`_renderedPage`). No hace falta que cada botón sepa "para qué lado" anima.

Cuando la animación termina, soltamos la foto para que vuelva a verse la página
viva (y liberamos la imagen GPU):

```dart
_pageAnim.addStatusListener((status) {
  if (status == AnimationStatus.completed && _curlImage != null) {
    setState(() { _curlImage?.dispose(); _curlImage = null; });
  }
});
```

---

## 6. Dibujar la curva: CustomPainter con drawVertices

Aquí está la magia. Una rotación 3D normal (`Transform` con `Matrix4`) hace que
la página se vea como una **tarjeta rígida girando** ("cuadrada"). Para que se
vea como **papel que se dobla** hay que **deformar la imagen**: la envolvemos
sobre un **cilindro** imaginario.

La técnica es una **malla** (`drawVertices`): partimos la página en muchas
columnas verticales y movemos cada columna a su posición sobre el cilindro. La
textura (la foto de la página) se "estira" entre esos puntos automáticamente.

```dart
for (var i = 0; i <= _cols; i++) {
  final x = i / _cols * w;                         // posición original (0..ancho)
  var theta = (forward ? (x - curlPos) : (curlPos - x)) / r;
  double sx, brightness;
  if (theta <= 0) {
    sx = x; brightness = 1;                         // parte plana, aún sin doblar
  } else {
    final off = r * math.sin(theta);
    sx = forward ? curlPos + off : curlPos - off;   // se proyecta sobre el cilindro
    final shade = (math.cos(theta) + 1) / 2;        // iluminación tipo Lambert
    brightness = 0.45 + 0.55 * shade;               // cresta clara, dorso oscuro
  }
  positions.add(Offset(sx, 0));    positions.add(Offset(sx, h));   // 2 filas (arriba/abajo)
  uvs.add(Offset(x * dpr, 0));     uvs.add(Offset(x * dpr, h*dpr)); // de dónde sacar la textura
  colors.add(color);               colors.add(color);              // sombreado por vértice
}
```

Conceptos:

- **`curlPos`** es la "línea de contacto" donde la hoja se despega del papel.
  Barre toda la página conforme avanza el tiempo `t`:
  `curlPos = forward ? w - t*travel : t*travel`.
- **`theta`** (ángulo sobre el cilindro): 0 = plano, crece a medida que la
  columna está más adentro del rollo. `sx = curlPos + r*sin(theta)` la coloca en
  pantalla → las columnas se **comprimen** (eso es la curva en perspectiva).
- **`uvs`** (coordenadas de textura) dicen de qué píxel de la foto sale cada
  vértice. Como la posición `sx` se comprime pero la `uv` no, la textura se
  curva. Van en píxeles de imagen, por eso multiplicamos por `dpr`.
- **`colors` + `BlendMode.modulate`**: el color del vértice se **multiplica** por
  la textura. Blanco = sin cambio; gris = oscurece. Con `cos(theta)` simulamos la
  luz: la cresta de la curva recibe luz y el dorso se oscurece. Eso da el
  volumen 3D del papel.

Y se pinta así:

```dart
final paint = Paint()
  ..shader = ui.ImageShader(image, TileMode.clamp, TileMode.clamp,
                            Matrix4.identity().storage);
canvas.drawVertices(vertices, BlendMode.modulate, paint);
```

Además dibujamos una **sombra suave** que la hoja levantada proyecta sobre la
página revelada (un `LinearGradient` justo delante de la cresta), que es lo que
termina de venderlo como algo físico.

Para **retroceder** no volteamos el lienzo (eso espejaría el texto): hacemos el
mismo cálculo pero pelando desde el borde izquierdo (`forward == false`).

---

## 7. El bug que tuvimos (y la lección más importante)

**Síntoma:** al pasar página se veían las letras de **las dos páginas
superpuestas**.

**Causa:** la foto (`toImageSync`) salía con **fondo transparente**, porque el
`ScrollablePositionedList` no tiene fondo propio (el color lo ponía el
`Scaffold`, que está fuera del `RepaintBoundary`). Al dibujar una imagen con
transparencias encima de la página nueva, esta se veía a través de los huecos.

**Arreglo:** envolver el contenido en un `ColoredBox` **opaco** con el color de
fondo del tema **dentro** del `RepaintBoundary`. Así la foto es 100% opaca, tapa
del todo a la página nueva, y esta solo aparece donde la hoja ya se curvó.

> 🧠 Lección general: cuando captures un widget a imagen para animarlo encima de
> otro, asegúrate de que el snapshot tenga **fondo opaco**, o se transparentará.

---

## 8. Cómo está apilado todo (el Stack del lector)

```dart
Stack(
  children: [
    RepaintBoundary(           // 1. página VIVA (la nueva, debajo)
      key: _pageBoundaryKey,
      child: ColoredBox( ... ScrollablePositionedList ... ),
    ),
    if (_curlImage != null)    // 2. la foto de la vieja, curvándose (encima)
      Positioned.fill(
        child: IgnorePointer(  // no roba toques mientras anima
          child: CustomPaint(painter: _PageCurlPainter(...)),
        ),
      ),
    Positioned(top: 0, ...     // 3. la barra de traducción (siempre arriba)
      child: TranslationBar(...)),
  ],
)
```

El orden importa: en un `Stack`, **lo último se pinta encima**. La barra de
traducción va al final para quedar sobre todo; el curl va en medio (sobre la
página viva pero bajo la barra).

---

## 9. El swipe (gesto que dispara el cambio)

```dart
GestureDetector(
  onHorizontalDragEnd: (details) =>
      _onHorizontalSwipe(context, state, details.primaryVelocity ?? 0),
  child: ScrollablePositionedList(...),  // el scroll vertical sigue siendo suyo
)
```

- `primaryVelocity < 0` → el dedo fue a la **izquierda** → página siguiente.
- `primaryVelocity > 0` → a la **derecha** → página anterior.
- El scroll **vertical** lo maneja la lista; el gesto **horizontal** lo maneja el
  `GestureDetector`. Como son ejes distintos, **no pelean** entre sí.

---

## 10. Resumen del flujo completo

```
swipe / botón
      │
      ▼
NavigateToPage  ──►  bloc cambia currentPage
      │
      ▼
BlocConsumer.listener detecta el cambio
      │
      ├─ _capturePage()  (foto de la página vieja, aún pintada)
      ├─ _curlImage = foto ; _curlForward = dirección
      └─ _pageAnim.forward(from: 0)
                 │
                 ▼  (cada frame, 0→1)
      _PageCurlPainter dibuja la foto curvándose sobre la página nueva
                 │
                 ▼  (status == completed)
      setState → _curlImage = null  (vuelve a verse la página viva)
```

---

## Para experimentar y aprender

Cosas fáciles de tocar en `reader_screen.dart` para ver el efecto cambiar:

- `duration` del `_pageAnim` (520 ms): súbelo a 1500 ms para ver la curva en cámara lenta.
- En `_PageCurlPainter`: `final r = w * 0.13;` → el **radio** del cilindro. Más
  grande = papel más grueso/curva más abierta; más chico = hoja fina y enrollada.
- `_cols = 48` → resolución de la malla. Bájalo a 6 y verás la curva "facetada"
  (entiendes que son columnas) y subiéndolo se ve más suave.
- El `0.45 + 0.55 * shade` del brillo → exagera el contraste para ver el sombreado.
```
