"""Stage 2 / step 5: generate the 40 AI clips, ONE per selected sentence, OFFLINE.

    <.venv-vieneu>/python -I -X utf8 make_ai_clips.py vieneu      # Turbo + Nano pairs
    <.venv-mms>/python    -I -X utf8 make_ai_clips.py mms         # MMS pairs
(run through the offline launcher: minimal environment, HF_HUB_OFFLINE=1; sockets are also blocked here)

Rules against cherry-picking (set before any clip existed):
  * each clip is generated exactly ONCE, with the fixed seed below, DEFAULT settings of every model
    (default voice settings, default speed), no regeneration for quality or taste; an existing clip is never overwritten;
  * if a generation CRASHES it is retried with the same seed and the crash is logged;
  * the exact text passed to the model (selection.csv raw_transcription) is stored in the record;
  * saved untouched at the model's native sample rate (32-bit float WAV): no trimming, normalisation,
    phone simulation or scoring.
Before generating, the script asserts and prints: no voice in both splits; the 12 held-out voices are exactly the
12 voices blind-checked by ear (audio/voice_check_key.csv); each held-out AI voice gender equals its real clip's gender.
Output: audio/ai_clips/<pair_id>.wav (git-ignored) and ai_clips_record.csv (local record, not committed yet).
"""
import csv
import hashlib
import json
import socket
import sys
import time
import unicodedata
from pathlib import Path

import numpy as np

try:
    import soundfile as sf
except ImportError:          # the MMS environment is hash-pinned and has no soundfile: write the float WAV by hand
    sf = None


def _blocked(*a, **k):
    raise RuntimeError("NETWORK ATTEMPT BLOCKED")


socket.socket.connect = _blocked
socket.create_connection = _blocked
socket.getaddrinfo = _blocked

HERE = Path(__file__).resolve().parent
SEED = 20261021
OUT = HERE / "audio" / "ai_clips"
RECORD = HERE / "ai_clips_record.csv"
NFC = lambda s: unicodedata.normalize("NFC", s)  # noqa: E731
COMMITS = {"vieneu-turbo": "pnnbao-ump/VieNeu-TTS-v3-Turbo@61b85e3d937fbbacb387714180e8182823512523",
           "vieneu-nano": "pnnbao-ump/VieNeu-TTS-v3-Nano@aba295eb96a6fa6003ebe417cc1f2802a7adc1dc",
           "mms": "facebook/mms-tts-vie@b58928d033932a49aa8e3d6cf11625b25fe928d2"}
FIELDS = ["pair_id", "split", "tool", "voice", "voice_gender", "real_gender", "sentence_id", "text_passed", "text_sha256",
          "seed", "rng_method", "settings", "model_commit", "sample_rate", "frames", "duration_s", "gen_seconds",
          "attempts", "crash_log", "file", "sha256", "notes", "server_decode", "server_note"]


def load_rows():
    return list(csv.DictReader(open(HERE / "selection.csv", encoding="utf-8", newline="")))


def preflight(rows):
    ok = True
    # 0. counts
    cnt = {}
    for r in rows:
        cnt[(r["split"], r["ai_tool"])] = cnt.get((r["split"], r["ai_tool"]), 0) + 1
    want = {("tuning", "mms"): 6, ("tuning", "vieneu-turbo"): 5, ("tuning", "vieneu-nano"): 5,
            ("heldout", "vieneu-turbo"): 12, ("heldout", "vieneu-nano"): 12}
    assert cnt == want, cnt
    print("PRE-FLIGHT 0: clip counts per (split, tool) as required:", dict(sorted(cnt.items())))
    # 1. no voice in both splits (names count across tools; MMS excluded: single voice, tuning only)
    names = {"tuning": set(), "heldout": set()}
    for r in rows:
        if r["ai_tool"] != "mms":
            names[r["split"]].add(NFC(r["ai_voice"]))
    both = names["tuning"] & names["heldout"]
    assert not both, f"voice in both splits: {both}"
    print(f"PRE-FLIGHT 1: no voice appears in both splits (tuning {len(names['tuning'])} names, held-out {len(names['heldout'])} names, overlap = none)")
    # 2. held-out voices == blind-checked voices
    key = list(csv.DictReader(open(HERE / "audio" / "voice_check_key.csv", encoding="utf-8", newline="")))
    checked = {(k["tool"], NFC(k["voice"])) for k in key}
    held = {(r["ai_tool"].replace("vieneu-", ""), NFC(r["ai_voice"])) for r in rows if r["split"] == "heldout"}
    assert len(held) == 12 and held == checked, (sorted(held ^ checked))
    print("PRE-FLIGHT 2: the 12 held-out voices are exactly the 12 blind-checked voices:")
    for t, v in sorted(held):
        print(f"      {t:5s} {v}")
    # 3. gender: each held-out AI voice gender == its real clip's gender; and equals the SDK-declared gender
    declared = {}
    for t in ("turbo", "nano"):
        for v in json.load(open(HERE / f"voices_{t}.json", encoding="utf-8"))["voices"]:
            declared[(t, NFC(v["id"]))] = v["gender"]
    bad = []
    for r in rows:
        if r["split"] != "heldout":
            continue
        t = r["ai_tool"].replace("vieneu-", "")
        if r["ai_voice_gender"] != r["real_gender_fleurs"] or declared.get((t, NFC(r["ai_voice"]))) != r["ai_voice_gender"]:
            bad.append(r["pair_id"])
    assert not bad, bad
    print("PRE-FLIGHT 3: every held-out AI voice gender equals its real clip's gender (and the SDK-declared gender): 24 of 24 pairs")
    z = [(r["pair_id"], r["ai_tool"]) for r in rows if r["zalo_tts"] == "1"]
    assert len(z) == 5 and all(r["split"] == "heldout" for r in rows if r["zalo_tts"] == "1")
    print("PRE-FLIGHT 4: the 5 Zalo-path files will be COPIES of these held-out AI clips (not new generations):", z)


def merge_record(new_rows):
    cur = {}
    if RECORD.exists():
        for r in csv.DictReader(open(RECORD, encoding="utf-8", newline="")):
            cur[r["pair_id"]] = r
    for r in new_rows:
        cur[r["pair_id"]] = {k: r.get(k, "") for k in FIELDS}
    order = {r["pair_id"]: i for i, r in enumerate(load_rows())}
    with open(RECORD, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS, lineterminator="\n")
        w.writeheader()
        w.writerows(sorted(cur.values(), key=lambda r: order[r["pair_id"]]))


def save(path, wav, sr):
    wav = np.asarray(wav, dtype=np.float32).reshape(-1)
    if wav.size == 0 or not np.all(np.isfinite(wav)):
        raise RuntimeError("empty or non-finite audio")
    if sf is not None:
        sf.write(str(path), wav, sr, subtype="FLOAT")
    else:                                                     # minimal IEEE-float32 mono WAV (format tag 3)
        import struct
        data = wav.astype("<f4").tobytes()
        hdr = (b"RIFF" + struct.pack("<I", 4 + (8 + 16) + (8 + 4) + (8 + len(data))) + b"WAVE"
               + b"fmt " + struct.pack("<IHHIIHH", 16, 3, 1, sr, sr * 4, 4, 32)
               + b"fact" + struct.pack("<II", 4, len(wav)) + b"data" + struct.pack("<I", len(data)))
        path.write_bytes(hdr + data)
    return len(wav)


def run_pair(r, gen, sr, settings, rng_method, tool):
    """Generate once (retry with the same seed only after a crash). Returns the record row."""
    path = OUT / f"{r['pair_id']}.wav"
    if path.exists():
        sys.exit(f"STOP: {path.name} already exists; a clip is never regenerated or overwritten")
    text = NFC(r["raw_transcription"])
    assert hashlib.sha256(r["raw_transcription"].encode("utf-8")).hexdigest() == r["text_sha256"], "text differs from selection.csv"
    crash, attempts, t0 = [], 0, time.perf_counter()
    while True:
        attempts += 1
        try:
            wav = gen(text)
            frames = save(path, wav, sr)
            break
        except Exception as e:                                   # a crash only: log and retry, same seed
            crash.append(f"attempt {attempts}: {type(e).__name__}: {str(e)[:160]}")
            if attempts >= 2:
                sys.exit(f"STOP: {r['pair_id']} crashed twice: {crash}")
    took = time.perf_counter() - t0
    return {"pair_id": r["pair_id"], "split": r["split"], "tool": tool, "voice": r["ai_voice"], "voice_gender": r["ai_voice_gender"],
            "real_gender": r["real_gender_fleurs"], "sentence_id": r["sentence_id"], "text_passed": text, "text_sha256": r["text_sha256"],
            "seed": SEED, "rng_method": rng_method, "settings": settings, "model_commit": COMMITS[tool], "sample_rate": sr,
            "frames": frames, "duration_s": f"{frames / sr:.3f}", "gen_seconds": f"{took:.1f}", "attempts": attempts,
            "crash_log": " | ".join(crash), "file": f"audio/ai_clips/{path.name}",
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "notes": ""}


def do_vieneu(rows):
    from vieneu import Vieneu
    mine = [r for r in rows if r["ai_tool"] in ("vieneu-turbo", "vieneu-nano")]
    out, engines = [], {}
    if any(r["ai_tool"] == "vieneu-turbo" for r in mine):
        engines["vieneu-turbo"] = Vieneu(mode="v3turbo", backend="onnx", precision="fp32",
                                         onnx_dir=str(HERE / "models" / "vieneu-turbo" / "onnx_update"))
    if any(r["ai_tool"] == "vieneu-nano" for r in mine):
        engines["vieneu-nano"] = Vieneu(mode="v3nano", onnx_dir=str(HERE / "models" / "vieneu-nano"))
    import inspect
    tdef = {k: v.default for k, v in inspect.signature(engines["vieneu-turbo"].infer).parameters.items()
            if k in ("temperature", "top_k", "top_p", "repetition_penalty", "max_chars", "silence_p")} if "vieneu-turbo" in engines else {}
    nano = engines.get("vieneu-nano")
    ndef = {"steps": nano.default_steps, "cfg": nano.default_cfg, "sway": 0.0, "speed": 1.0, "max_chars": 140} if nano else {}
    for r in mine:
        tool, voice = r["ai_tool"], r["ai_voice"]
        eng = engines[tool]
        if tool == "vieneu-turbo":
            def gen(text, eng=eng, voice=voice):
                np.random.seed(SEED)                              # Turbo samples with numpy's global RNG
                return eng.infer(text, voice=voice, apply_watermark=False)
            settings, method = f"SDK defaults {json.dumps(tdef)}; fp32 onnx_update; voice preset; apply_watermark=False", "np.random.seed(seed) immediately before the clip"
        else:
            def gen(text, eng=eng, voice=voice):
                return eng.infer(text, voice=voice, seed=SEED, apply_watermark=False)
            settings, method = f"SDK defaults {json.dumps(ndef)}; voice preset; seed passed; apply_watermark=False", "infer(seed=seed) (per-chunk default_rng(seed+i))"
        row = run_pair(r, gen, eng.sample_rate, settings, method, tool)
        out.append(row)
        print(f"  {row['pair_id']:5s} {tool:13s} {voice:11s} {row['duration_s']:>7s}s @ {row['sample_rate']} Hz  gen {row['gen_seconds']}s  attempts {row['attempts']}", flush=True)
    return out


def do_mms(rows):
    import torch
    from transformers import AutoTokenizer, VitsModel
    d = HERE / ".venv-mms" / "models" / "mms-tts-vie"
    tok = AutoTokenizer.from_pretrained(str(d), local_files_only=True, trust_remote_code=False)
    model = VitsModel.from_pretrained(str(d), use_safetensors=True, local_files_only=True, trust_remote_code=False).eval()
    vocab = set(tok.get_vocab())
    cfg = model.config
    settings = (f"transformers defaults from config: speaking_rate {cfg.speaking_rate}, noise_scale {cfg.noise_scale}, "
                f"noise_scale_duration {cfg.noise_scale_duration}; safetensors; single built-in speaker")
    out = []
    for r in [r for r in rows if r["ai_tool"] == "mms"]:
        def gen(text):
            ids = tok(text, return_tensors="pt")
            torch.manual_seed(SEED)
            with torch.no_grad():
                return model(**ids).waveform[0].numpy()
        row = run_pair(r, gen, cfg.sampling_rate, settings, "torch.manual_seed(seed) immediately before the clip", "mms")
        dropped = sorted({c for c in NFC(r["raw_transcription"]).lower() if c not in vocab})
        row["notes"] = "characters not in the MMS vocabulary (dropped by its tokenizer): " + (repr("".join(dropped)) if dropped else "none")
        out.append(row)
        print(f"  {row['pair_id']:5s} mms           {r['ai_voice']:11s} {row['duration_s']:>7s}s @ {row['sample_rate']} Hz  gen {row['gen_seconds']}s  dropped chars: {''.join(dropped) or 'none'}", flush=True)
    return out


def main():
    which = sys.argv[1] if len(sys.argv) > 1 else ""
    if which not in ("vieneu", "mms"):
        sys.exit("usage: make_ai_clips.py vieneu|mms")
    rows = load_rows()
    preflight(rows)
    OUT.mkdir(parents=True, exist_ok=True)
    t0 = time.perf_counter()
    new = do_vieneu(rows) if which == "vieneu" else do_mms(rows)
    merge_record(new)
    print(f"{which}: {len(new)} clips generated in {time.perf_counter() - t0:.0f} s (including model load); record -> {RECORD.name}")


if __name__ == "__main__":
    main()
