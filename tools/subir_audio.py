#!/usr/bin/env python3
"""
Sube los audios por bloque a Supabase Storage y guarda sus tiempos en content_blocks.

Lee una carpeta con los pares que produce el alineador:
    block_<id>.m4a   el audio del bloque (AAC mono)
    block_<id>.json  {"block_id", "duracion_ms", "palabras": [[cs, ce, t0, t1, conf], ...]}

y para cada bloque:
    1. sube el .m4a a  block-audio/book_<book>/block_<id>.m4a  (sobrescribe si ya estaba)
    2. rellena audio_path, audio_ms y audio_words ([cs, ce, t0, t1], sin la confianza)

Requiere la migración 0003_block_audio.sql.

USO:
    python tools/subir_audio.py --book 1 --dir "Z:/clonador de voz/prueba_p113/resultado"
    python tools/subir_audio.py --book 1 --dir ... --dry-run     # solo muestra qué haría

CONFIG (env vars):
    SUPABASE_URL          ej. https://xxxx.supabase.co
    SUPABASE_SERVICE_KEY  la service_role key (Settings → API). NO la anon key:
                          el bucket y la tabla no aceptan escrituras anónimas.
                          No la pegues en el código ni la subas al repo.
"""

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

BUCKET = "block-audio"
DEFAULT_URL = "https://ewyiuywiyykekoearvlo.supabase.co"


def pedir(metodo: str, url: str, clave: str, cuerpo: bytes, tipo: str,
          extra: dict | None = None) -> None:
    cabeceras = {"apikey": clave, "Authorization": f"Bearer {clave}", "Content-Type": tipo}
    cabeceras.update(extra or {})
    req = urllib.request.Request(url, data=cuerpo, method=metodo, headers=cabeceras)
    try:
        urllib.request.urlopen(req).read()
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"{metodo} {url} -> {e.code}: {e.read().decode(errors='replace')[:300]}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--book", type=int, required=True, help="book_id de los bloques")
    ap.add_argument("--dir", type=Path, required=True, help="carpeta con block_<id>.m4a/.json")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    base = os.environ.get("SUPABASE_URL", DEFAULT_URL).rstrip("/")
    clave = os.environ.get("SUPABASE_SERVICE_KEY", "")
    if not clave and not args.dry_run:
        sys.exit("Falta SUPABASE_SERVICE_KEY (la service_role key de Settings → API).")

    jsons = sorted(args.dir.glob("block_*.json"))
    if not jsons:
        sys.exit(f"No hay block_*.json en {args.dir}")

    total_kb = 0.0
    for i, ruta_json in enumerate(jsons, start=1):
        datos = json.loads(ruta_json.read_text("utf-8"))
        id_bloque = int(datos["block_id"])
        m4a = ruta_json.with_suffix(".m4a")
        if not m4a.is_file():
            print(f"[!] bloque {id_bloque}: falta {m4a.name}, se salta")
            continue

        ruta = f"book_{args.book}/block_{id_bloque}.m4a"
        palabras = [fila[:4] for fila in datos["palabras"]]
        kb = m4a.stat().st_size / 1024
        total_kb += kb

        if args.dry_run:
            print(f"[{i}/{len(jsons)}] {ruta}  {kb:.0f} KB  {len(palabras)} palabras")
            continue

        pedir("POST", f"{base}/storage/v1/object/{BUCKET}/{ruta}", clave,
              m4a.read_bytes(), "audio/mp4", {"x-upsert": "true"})
        pedir("PATCH", f"{base}/rest/v1/content_blocks?id=eq.{id_bloque}&book_id=eq.{args.book}",
              clave,
              json.dumps({"audio_path": ruta, "audio_ms": datos["duracion_ms"],
                          "audio_words": palabras}).encode(),
              "application/json", {"Prefer": "return=minimal"})
        print(f"[{i}/{len(jsons)}] bloque {id_bloque} subido ({kb:.0f} KB)")

    print(f"Listo: {len(jsons)} bloques, {total_kb / 1024:.2f} MB")


if __name__ == "__main__":
    main()
