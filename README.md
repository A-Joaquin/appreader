# BlackReader 📖

Lector de libros con **traducción asistida palabra por palabra**, pensado para
aprender inglés leyendo. Toca una palabra en el texto y BlackReader te muestra la
oración traducida y resalta la palabra exacta correspondiente en el otro idioma.

Funciona **offline-first**: descargas un libro una vez y lo lees sin conexión.
Corre con el **mismo código** en **móvil (Android/iOS) y web**.

---

## ✨ Características

- **Traducción interactiva**: tocas una palabra → barra superior con la oración
  traducida y resaltado de la palabra equivalente (mapeo por offsets, `word_map`).
- **Lectura offline**: al descargar un libro se guarda en una base local (Drift /
  SQLite) y se pre-cachean las imágenes; luego se lee sin internet.
- **Sincronización en la nube**: cuentas de usuario, progreso de lectura y
  descargas se guardan en Supabase.
- **Experiencia de lectura cuidada**: temas claro / sepia / oscuro, paso de página
  con animación, portadas de libros personalizables.
- **Panel de administración**: gestión básica de usuarios y contenido.
- **Multiplataforma**: Android, iOS y Web desde una sola base de código.

---

## 🛠️ Stack

| Capa | Tecnología |
|------|-----------|
| UI / App | Flutter (BLoC, go_router) |
| Backend / Auth / Datos | Supabase (PostgreSQL + Auth) |
| Persistencia local | Drift sobre SQLite (móvil) / WebAssembly + IndexedDB (web) |
| Imágenes | cached_network_image + flutter_cache_manager |

### Modelo de datos (Supabase)

```
books  →  content_blocks  →  block_fragments (incluye word_map)
```

Un libro se compone de bloques de contenido (texto o imagen), y cada bloque de
texto se divide en fragmentos con su traducción y el `word_map` que conecta cada
palabra original con su equivalente traducido.

---

## 📂 Estructura del proyecto

```
lib/
├── core/            # router, temas, settings de lectura
├── data/
│   ├── local/       # base de datos Drift + conexión por plataforma
│   ├── models/      # modelos de dominio
│   └── repositories/# acceso a datos (local + Supabase)
└── presentation/    # pantallas: splash, login, home, detalle, lector, admin
```

La conexión a la base de datos se elige en tiempo de compilación según la
plataforma (`lib/data/local/connection/`): SQLite nativo en móvil, SQLite sobre
WebAssembly en web. El resto de la app no cambia entre plataformas.

---

## 🚀 Cómo correrlo

Requisitos: [Flutter SDK](https://docs.flutter.dev/get-started/install) (canal
estable) y un proyecto de Supabase.

```bash
# Instalar dependencias
flutter pub get

# Generar el código de Drift (si modificas las tablas)
dart run build_runner build --delete-conflicting-outputs

# Correr en un dispositivo/emulador móvil
flutter run

# Correr en el navegador
flutter run -d chrome
```

### Configuración de Supabase

La URL y la *anon key* del proyecto se configuran en `lib/main.dart`. La *anon
key* es pública por diseño; la seguridad real se apoya en las **políticas RLS**
de Supabase.

---

## 🌐 Despliegue web

Flutter web genera un sitio estático, así que se puede publicar gratis en
cualquier hosting estático (Netlify, Vercel, Cloudflare Pages, Firebase Hosting):

```bash
flutter build web --release   # genera build/web/
```

Sube la carpeta `build/web/` al hosting. Recuerda registrar el dominio público
en **Supabase → Authentication → URL Configuration** para que el login funcione
fuera de `localhost`.

> Nota: la persistencia offline en web vive en el navegador (IndexedDB) y no se
> comparte con la app móvil. El progreso de lectura sí se sincroniza vía Supabase.

---

## 📄 Licencia

Proyecto privado. Todos los derechos reservados.
