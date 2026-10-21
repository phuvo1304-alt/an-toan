"""Stage 2 / step 5 (checks): run every generated AI clip through the REAL voice-server decoder, verify the
recorded hashes, print per-clip facts and per-tool duration statistics next to the real clips, and make the five
Zalo-path COPIES. Changes nothing about the clips (no trimming, no normalisation, no regeneration, no scoring).

    <.venv-vieneu>/python -I -X utf8 check_ai_clips.py
"""
import csv
import hashlib
import shutil
import statistics as st
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
from server_accepts import server_decode, server_limits  # noqa: E402

RECORD = HERE / "ai_clips_record.csv"
ZALO = HERE / "audio" / "zalo_tts"


def stats(xs):
    xs = sorted(xs)
    return f"n={len(xs):2d}  min {xs[0]:5.2f}  median {st.median(xs):5.2f}  max {xs[-1]:5.2f}"


def main():
    lim = server_limits()
    sel = {r["pair_id"]: r for r in csv.DictReader(open(HERE / "selection.csv", encoding="utf-8", newline=""))}
    rows = list(csv.DictReader(open(RECORD, encoding="utf-8", newline="")))
    assert len(rows) == 40 and {r["pair_id"] for r in rows} == set(sel), "record must hold exactly the 40 selected pairs"
    print(f"server limits (imported from voice-server/app): silence RMS {lim['silence_rms']}, length {lim['min_seconds']}-{lim['max_seconds']} s")
    print(f"{'pair':5s} {'tool':13s} {'voice':11s} {'sr':>6s} {'dur s':>7s} {'real s':>7s} {'ai/real':>7s} {'rms':>7s} {'peak':>5s}  server decode")
    problems, fails = [], []
    for r in rows:
        p = HERE / r["file"]
        data = p.read_bytes()
        if hashlib.sha256(data).hexdigest() != r["sha256"]:
            problems.append(f"{r['pair_id']}: sha256 differs from the record")
        x, sr = sf.read(str(p), dtype="float64")
        dur = len(x) / sr
        if sr != int(r["sample_rate"]) or abs(dur - float(r["duration_s"])) > 0.002:
            problems.append(f"{r['pair_id']}: sample rate or duration differs from the record")
        ok, code, _ = server_decode(data)                                 # the production server's own decoder
        rms = float(np.sqrt(np.mean(x ** 2)))
        verdict = "accepted" if ok else {"silent": "REJECTED: silent", "empty": "REJECTED: too short", "too_long": "REJECTED: too long"}.get(code, "REJECTED: " + code)
        r["server_decode"] = "ok" if ok else code
        r["server_note"] = f"rms {rms:.4f} peak {float(np.max(np.abs(x))):.3f}"
        real = float(sel[r["pair_id"]]["real_duration_s"])
        print(f"{r['pair_id']:5s} {r['tool']:13s} {r['voice']:11s} {sr:6d} {dur:7.2f} {real:7.2f} {dur / real:7.2f} {rms:7.4f} {float(np.max(np.abs(x))):5.2f}  {verdict}")
        if not ok:
            fails.append((r["pair_id"], verdict))
    with open(RECORD, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]), lineterminator="\n")
        w.writeheader()
        w.writerows(rows)

    print("\nDURATIONS (seconds): AI clips per tool, next to the REAL clips of the same pairs")
    for tool in ("mms", "vieneu-turbo", "vieneu-nano"):
        ai = [float(r["duration_s"]) for r in rows if r["tool"] == tool]
        real = [float(sel[r["pair_id"]]["real_duration_s"]) for r in rows if r["tool"] == tool]
        print(f"  {tool:13s} AI   {stats(ai)}\n  {'':13s} real {stats(real)}")
    for split in ("tuning", "heldout"):
        ai = [float(r["duration_s"]) for r in rows if r["split"] == split]
        real = [float(sel[r["pair_id"]]["real_duration_s"]) for r in rows if r["split"] == split]
        print(f"  split {split:8s} AI {stats(ai)}\n  {'':14s}real {stats(real)}")
    ai_all = [float(r["duration_s"]) for r in rows]
    real_all = [float(sel[r["pair_id"]]["real_duration_s"]) for r in rows]
    print(f"  ALL 40         AI   {stats(ai_all)}\n  {'':14s}real {stats(real_all)}")
    ratios = [float(r["duration_s"]) / float(sel[r["pair_id"]]["real_duration_s"]) for r in rows]
    print(f"  AI/real length ratio per pair: min {min(ratios):.2f} median {st.median(ratios):.2f} max {max(ratios):.2f}; pairs with ratio < 0.6 or > 1.6:",
          [(r["pair_id"], round(q, 2)) for r, q in zip(rows, ratios) if q < 0.6 or q > 1.6] or "none")
    print("  sample rates of the AI clips:", {sr: sum(1 for r in rows if int(r["sample_rate"]) == sr) for sr in sorted({int(r['sample_rate']) for r in rows})},
          "| real clips: all 16000")

    ZALO.mkdir(parents=True, exist_ok=True)
    z = [r for r in rows if sel[r["pair_id"]]["zalo_tts"] == "1"]
    for r in z:
        shutil.copyfile(HERE / r["file"], ZALO / f"{r['pair_id']}.wav")
        assert hashlib.sha256((ZALO / f"{r['pair_id']}.wav").read_bytes()).hexdigest() == r["sha256"]
    print(f"\nZALO-PATH FILES: {len(z)} byte-identical COPIES of held-out AI clips (hash-checked) in audio/zalo_tts/: " + ", ".join(f"{r['pair_id']} ({r['tool']}, {r['voice']})" for r in z))

    print(f"\nSERVER LIMIT FAILURES: {fails or 'none'} | record/hash problems: {problems or 'none'}")
    print(f"accepted by the real voice-server decoder: {sum(1 for r in rows if r['server_decode'] == 'ok')} of 40")
    sys.exit(1 if (fails or problems) else 0)


if __name__ == "__main__":
    main()
