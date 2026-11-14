-- BlackReader · audio por bloque (voz en inglés + tiempos de cada palabra)
--
-- Cada bloque de texto puede tener un audio .m4a con su `original_content`
-- leído en voz alta, y los tiempos de cada palabra dentro de ese audio. Así la
-- app puede reproducir SOLO la palabra que se tocó, sacada del audio completo.
--
-- Los audios los genera y los sube `audiolibro subir` (Z:\clonador de voz\audiolibro,
-- con la service key, que se salta la RLS). La app solo lee.
--
-- ⚠️ CORRER PASO A PASO, uno cada vez (selecciona el bloque y Run).
-- Cada paso es idempotente: se puede repetir sin romper nada.

-- ═══════════════════════════════════════════════════════════════════════════
-- PASO 1 — columnas en content_blocks
-- ═══════════════════════════════════════════════════════════════════════════
alter table public.content_blocks
  -- Ruta dentro del bucket `block-audio`, p. ej. 'book_1/block_5098.m4a'.
  -- null = el bloque todavía no tiene audio.
  add column if not exists audio_path  text,
  -- Duración del audio en milisegundos.
  add column if not exists audio_ms    int4,
  -- Una fila por palabra: [char_inicio, char_fin, ms_inicio, ms_fin].
  -- Los offsets son relativos a `original_content` del BLOQUE (no del
  -- fragmento), igual que char_start / char_end de block_fragments.
  -- Arrays en vez de objetos: ~4x menos bytes en la descarga del libro.
  add column if not exists audio_words jsonb,
  -- true = el control de calidad lo marcó como dudoso (código, símbolos, ritmo
  -- raro…). Se sube igual para revisarlo; si no gusta, `audiolibro quitar`.
  add column if not exists audio_dudoso boolean not null default false,
  -- Por qué es dudoso (vacío si no lo es).
  add column if not exists audio_motivo text;

-- ═══════════════════════════════════════════════════════════════════════════
-- PASO 2 — bucket de Storage
-- ═══════════════════════════════════════════════════════════════════════════
-- Público para lectura: el texto de los libros ya es legible con la anon key,
-- y así la app descarga con una URL simple, sin firmar cada archivo.
-- Sin políticas de escritura: solo la service key puede subir o borrar.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('block-audio', 'block-audio', true, 5242880, array['audio/mp4'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;
