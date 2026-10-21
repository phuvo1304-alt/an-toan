"""Stage 2 / step 4a: clips for the BLIND gender check of the 12 held-out TTS voices.

One short clip per held-out voice (voices read from selection.csv, so the list cannot drift from
the plan), made OFFLINE with the pinned local models. The same neutral sentence for every voice.
Filenames are random opaque ids; the voice order is shuffled; every file gets the same timestamp,
so neither the names nor the folder listing reveal which voice is which. The key (filename ->
tool, voice, declared gender) goes to a separate file. Nothing here scores anything.

    <venv-vieneu>/python -I -X utf8 make_voice_check.py     (run through the offline launcher)

Output (git-ignored):  audio/voice_check/clip_xxxxxx.wav   and   audio/voice_check_key.csv
"""
import csv
import json
import os
import random
import secrets
import socket
import sys
import time
import unicodedata
from pathlib import Path

import numpy as np
import soundfile as sf


def _blocked(*a, **k):
    raise RuntimeError("NETWORK ATTEMPT BLOCKED")


socket.socket.connect = _blocked
socket.create_connection = _blocked
socket.getaddrinfo = _blocked

HERE = Path(__file__).resolve().parent
OUT_DIR = HERE / "audio" / "voice_check"
KEY = HERE / "audio" / "voice_check_key.csv"
SEED = 20261021
TEXT = unicodedata.normalize("NFC", sys.argv[1] if len(sys.argv) > 1 else "Hôm nay trời đẹp, tôi đi dạo trong công viên gần nhà.")
PEAK = 0.8   # listening copies only: peak-normalise so the 12 clips have a similar volume


def heldout_voices():
    rows = list(csv.DictReader(open(HERE / "selection.csv", encoding="utf-8", newline="")))
    seen = {}
    for r in rows:
        if r["split"] == "heldout":
            seen[(r["ai_tool"].replace("vieneu-", ""), unicodedata.normalize("NFC", r["ai_voice"]))] = r["ai_voice_gender"]
    assert len(seen) == 12, f"expected 12 held-out voices, found {len(seen)}"
    return seen


def main():
    from vieneu import Vieneu
    np.random.seed(SEED)
    random.seed(SEED)
    voices = heldout_voices()
    t_all = time.perf_counter()
    engines, load_s = {}, {}
    t0 = time.perf_counter()
    engines["turbo"] = Vieneu(mode="v3turbo", backend="onnx", precision="fp32",
                              onnx_dir=str(HERE / "models" / "vieneu-turbo" / "onnx_update"))
    load_s["turbo"] = time.perf_counter() - t0
    t0 = time.perf_counter()
    engines["nano"] = Vieneu(mode="v3nano", onnx_dir=str(HERE / "models" / "vieneu-nano"))
    load_s["nano"] = time.perf_counter() - t0

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for old in OUT_DIR.glob("*.wav"):
        old.unlink()
    order = sorted(voices)                      # then shuffled with a CSPRNG so the order is not guessable
    random.SystemRandom().shuffle(order)
    names, used = {}, set()
    for key in order:
        while True:
            n = f"clip_{secrets.token_hex(3)}.wav"
            if n not in used:
                used.add(n)
                break
        names[key] = n

    t_gen = time.perf_counter()
    rows, fixed_time = [], time.time()
    for tool, voice in order:
        eng = engines[tool]
        t0 = time.perf_counter()
        wav = eng.infer(TEXT, voice=voice, apply_watermark=False)
        took = time.perf_counter() - t0
        wav = np.asarray(wav, dtype=np.float32)
        if wav.size == 0 or not np.all(np.isfinite(wav)):
            sys.exit(f"STOP: empty or invalid audio for {tool}/{voice}")
        wav = wav * (PEAK / max(float(np.max(np.abs(wav))), 1e-6))
        path = OUT_DIR / names[(tool, voice)]
        sf.write(str(path), wav, eng.sample_rate, subtype="PCM_16")
        os.utime(path, (fixed_time, fixed_time))
        rows.append({"filename": path.name, "tool": tool, "voice": voice, "declared_gender": voices[(tool, voice)],
                     "sample_rate": eng.sample_rate, "duration_s": f"{len(wav) / eng.sample_rate:.2f}",
                     "synth_seconds": f"{took:.1f}"})
    gen_s = time.perf_counter() - t_gen

    with open(KEY, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]), lineterminator="\n")
        w.writeheader()
        w.writerows(sorted(rows, key=lambda r: r["filename"]))
    print(json.dumps({"clips": len(rows), "text": TEXT, "load_seconds": {k: round(v, 1) for k, v in load_s.items()},
                      "generation_seconds": round(gen_s, 1), "total_seconds": round(time.perf_counter() - t_all, 1),
                      "durations_s": sorted(float(r["duration_s"]) for r in rows)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
