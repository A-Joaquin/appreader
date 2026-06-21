#!/usr/bin/env python3
"""
QA de calidad de traducción + word_map para BlackReader.

Detecta fragmentos con alineación/traducción sospechosa en Supabase. Pensado
para correr en el pipeline de producción de word_maps, o a mano entre sesiones.

USO:
    python tools/check_wordmap_quality.py                 # todo el corpus
    python tools/check_wordmap_quality.py --book 1        # solo book_id=1
    python tools/check_wordmap_quality.py --semantic      # + chequeo semántico (LaBSE)

CONFIG (env vars, con defaults a la instancia de prueba):
    SUPABASE_URL   ej. https://xxxx.supabase.co
    SUPABASE_KEY   anon key

HEURÍSTICOS (baratos, sin modelo):
    1. ES = marcador de lista ("2.", "3.") y EN es una oración  -> desalineado.
    2. len(ES) < 0.35 * len(EN)  con len(EN) >= 25               -> traducción muy corta.
    3. cobertura word_map = entradas / palabras_EN < 0.40        -> alineación pobre.

LÍMITE CONOCIDO: los errores de "desfase con traducción completa pero
equivocada" (misma longitud, otra oración) NO los cazan los heurísticos.
Para esos usar --semantic (similitud cross-lingual EN<->ES por fragmento).
"""

import argparse
import json
import os
import re
import sys
import urllib.parse
import urllib.request

DEFAULT_URL = "https://ewyiuywiyykekoearvlo.supabase.co"
DEFAULT_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV3eWl1eXdpeXlrZWtvZWFydmxvIiwicm9sZSI6"
    "ImFub24iLCJpYXQiOjE3ODA0NTAyMTcsImV4cCI6MjA5NjAyNjIxN30."
    "faabc5HgHW9lX_YBePvmPV1e-FJGu55EXCyytbs3rLk"
)

WORD = re.compile(r"\w+", re.UNICODE)
MARKER = re.compile(r"^\s*\d+\.?\s*$")


def fetch_fragments(url, key, book_id=None):
    base = url.rstrip("/") + "/rest/v1/block_fragments"
    select = "id,block_id,fragment_order,original_text,translated_text,word_map"
    params = {"select": select, "order": "id"}
    if book_id is not None:
        # Filtra por book vía el bloque (requiere FK content_blocks).
        params["select"] = select + ",content_blocks!inner(book_id)"
        params["content_blocks.book_id"] = f"eq.{book_id}"
    query = urllib.parse.urlencode(params, safe="!*()")
    req = urllib.request.Request(
        f"{base}?{query}",
        headers={"apikey": key, "Authorization": f"Bearer {key}"},
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


def heuristic_reasons(orig, trans, word_map):
    o = (orig or "").strip()
    t = (trans or "").strip()
    wm = word_map or []
    n_words = len(WORD.findall(o))
    cov = (len(wm) / n_words) if n_words else 1.0
    reasons = []
    if MARKER.match(t) and not MARKER.match(o):
        reasons.append("ES=marcador")
    if len(o) >= 25 and len(t) < 0.35 * len(o):
        reasons.append("ES muy corta")
    if n_words >= 4 and cov < 0.40:
        reasons.append(f"cobertura baja {cov:.0%} ({len(wm)}/{n_words})")
    return reasons, n_words, len(wm)


def run_semantic(rows, threshold=0.55):
    """Marca fragmentos con baja similitud cross-lingual EN<->ES (LaBSE)."""
    try:
        from sentence_transformers import SentenceTransformer, util
    except ImportError:
        print(
            "  [semantic] Instala: pip install sentence-transformers",
            file=sys.stderr,
        )
        return []
    model = SentenceTransformer("sentence-transformers/LaBSE")
    flagged = []
    for r in rows:
        o = (r["original_text"] or "").strip()
        t = (r["translated_text"] or "").strip()
        if len(WORD.findall(o)) < 4:
            continue
        emb = model.encode([o, t], convert_to_tensor=True, normalize_embeddings=True)
        sim = float(util.cos_sim(emb[0], emb[1]))
        if sim < threshold:
            flagged.append((r, sim))
    return flagged


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--book", type=int, default=None)
    ap.add_argument("--semantic", action="store_true")
    args = ap.parse_args()

    url = os.environ.get("SUPABASE_URL", DEFAULT_URL)
    key = os.environ.get("SUPABASE_KEY", DEFAULT_KEY)

    rows = fetch_fragments(url, key, args.book)
    print(f"Total fragmentos analizados: {len(rows)}")

    flagged = []
    for r in rows:
        reasons, n_words, n_entries = heuristic_reasons(
            r["original_text"], r["translated_text"], r["word_map"]
        )
        if reasons:
            flagged.append((r, n_words, n_entries, "; ".join(reasons)))

    print(f"\n[heurístico] Fragmentos marcados: {len(flagged)}")
    print("id   blk ord  pal ent | EN -> ES | motivos")
    for r, nw, ne, why in sorted(flagged, key=lambda x: (x[0]["block_id"], x[0]["fragment_order"])):
        en = (r["original_text"] or "")[:45]
        es = (r["translated_text"] or "")[:32]
        print(f"{r['id']:<4} {r['block_id']:<3} {r['fragment_order']:<3}  {nw:<3} {ne:<3} | {en!r} -> {es!r} | {why}")

    if args.semantic:
        print("\n[semántico] Calculando similitud cross-lingual (LaBSE)…")
        sem = run_semantic(rows)
        print(f"[semántico] Fragmentos con baja similitud: {len(sem)}")
        for r, sim in sorted(sem, key=lambda x: x[1]):
            en = (r["original_text"] or "")[:40]
            es = (r["translated_text"] or "")[:40]
            print(f"  sim={sim:.2f}  id={r['id']}  {en!r} -> {es!r}")

    # Exit code != 0 si hay hallazgos (útil en CI del pipeline).
    sys.exit(1 if flagged else 0)


if __name__ == "__main__":
    main()
