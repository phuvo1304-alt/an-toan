"""Stage 2 / step 6a: prepare the audio of the 80 clips exactly as PLAN.md section 2 says. NO scoring.

For each of the 40 pairs there is a real clip (FLEURS) and an AI clip (selection.csv + ai_clips_record.csv).

CLEAN ARM  (audio/clean/<pair>_<real|ai>.wav)
  1. decode with the production voice server's own decoder (ffmpeg) from the ORIGINAL float32 file
     -> 16 kHz mono float32 (never from a 16-bit copy);
  2. trim leading and trailing silence: 20 ms non-overlapping frames (320 samples); a frame is silent if its
     RMS is below -45 dBFS (absolute, full scale = 1.0); keep 10 frames = 0.2 s of padding each side;
  3. RMS-normalise the trimmed clip to -23 dBFS with one gain; if the peak would exceed -1 dBFS the gain is
     reduced so the peak is exactly -1 dBFS;
  4. write 16-bit PCM WAV: round(x * 32767), clipped to the int16 range, no dither.
RAW ARM  (audio/raw_arm/<pair>_<real|ai>.wav)
  the original clip with ONLY the sample format converted to 16-bit PCM by the same rounding; sample rate,
  channel count and content untouched (no resampling, trimming, gain).

Also computes the per-clip statistics (prepare_stats.csv) and verifies that trimming removed only silence.
Standard library + numpy + soundfile; needs ffmpeg through server_accepts.py.

    <.venv-vieneu>/python -I -X utf8 prepare_audio.py
"""
import csv
import hashlib
import statistics as st
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
from server_accepts import server_samples  # noqa: E402

# ---- constants fixed in PLAN.md section 2 / written before any statistic was computed -------------
SR = 16_000
FRAME = 320                  # 20 ms at 16 kHz
SILENCE_DBFS = -45.0
PAD_FRAMES = 10              # 0.2 s of padding each side
TARGET_RMS_DBFS = -23.0
PEAK_CAP_DBFS = -1.0
PCM_SCALE = 32767
NFFT, HOP, ROLLOFF_FRAC = 1024, 512, 0.95
SHORT_S = 3.0                # clips shorter than this after trimming are counted (PLAN section 6: "Can't tell")

CLEAN = HERE / "audio" / "clean"
RAW = HERE / "audio" / "raw_arm"
STATS = HERE / "prepare_stats.csv"


def db(v):
    return 20.0 * np.log10(max(float(v), 1e-12))


def frame_dbfs(x):
    """Level of each 20 ms frame in dBFS (the last frame may be shorter)."""
    n = int(np.ceil(len(x) / FRAME))
    return np.array([db(np.sqrt(np.mean(x[i * FRAME:(i + 1) * FRAME].astype(np.float64) ** 2))) for i in range(n)])


def rolloff95(x, sr):
    """Frequency (Hz) below which 95% of the average power spectrum lies (1024-sample Hann frames, hop 512)."""
    x = np.asarray(x, dtype=np.float64)
    if len(x) < NFFT:
        x = np.pad(x, (0, NFFT - len(x)))
    win = np.hanning(NFFT)
    frames = np.stack([x[i:i + NFFT] * win for i in range(0, len(x) - NFFT + 1, HOP)])
    power = np.mean(np.abs(np.fft.rfft(frames, axis=1)) ** 2, axis=0)
    cum = np.cumsum(power)
    k = int(np.searchsorted(cum, ROLLOFF_FRAC * cum[-1]))
    return k * sr / NFFT


def features(x16):
    """The seven shortcut-check features (also used for the statistics) of a 16 kHz mono signal."""
    f = frame_dbfs(x16)
    active = f >= SILENCE_DBFS
    if active.any():
        lead = int(np.argmax(active))
        trail = int(len(active) - 1 - np.max(np.where(active)))
    else:
        lead, trail = len(active), 0
    return {"duration_s": len(x16) / SR, "lead_silence_s": lead * FRAME / SR, "trail_silence_s": trail * FRAME / SR,
            "noise_floor_dbfs": float(np.percentile(f, 10)), "rms_dbfs": db(np.sqrt(np.mean(np.asarray(x16, np.float64) ** 2))),
            "peak_dbfs": db(np.max(np.abs(x16))), "rolloff95_hz": rolloff95(x16, SR)}


def trim(x):
    """Returns (trimmed, info). Removes leading/trailing runs of silent frames, keeping 0.2 s of padding."""
    f = frame_dbfs(x)
    active = np.where(f >= SILENCE_DBFS)[0]
    if len(active) == 0:
        return x, {"no_active_frames": 1, "start": 0, "end": len(x)}
    start = max(0, (int(active[0]) - PAD_FRAMES) * FRAME)
    end = min(len(x), (int(active[-1]) + 1 + PAD_FRAMES) * FRAME)
    return x[start:end], {"no_active_frames": 0, "start": start, "end": end}


def normalise(y):
    rms_db = db(np.sqrt(np.mean(y.astype(np.float64) ** 2)))
    gain_db = TARGET_RMS_DBFS - rms_db
    peak = float(np.max(np.abs(y)))
    capped = False
    if db(peak) + gain_db > PEAK_CAP_DBFS:
        gain_db = PEAK_CAP_DBFS - db(peak)
        capped = True
    return (y.astype(np.float64) * 10 ** (gain_db / 20.0)), gain_db, capped


def to_int16(x):
    q = np.round(np.asarray(x, dtype=np.float64) * PCM_SCALE)
    clipped = int(np.sum(np.abs(q) > 32767))
    return np.clip(q, -32768, 32767).astype("<i2"), clipped


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def clip_list():
    sel = list(csv.DictReader(open(HERE / "selection.csv", encoding="utf-8", newline="")))
    rec = {r["pair_id"]: r for r in csv.DictReader(open(HERE / "ai_clips_record.csv", encoding="utf-8", newline=""))}
    out = []
    for r in sel:
        out.append({"clip_id": f"{r['pair_id']}_real", "pair_id": r["pair_id"], "cls": "real", "tool": "fleurs", "split": r["split"],
                    "gender": r["real_gender_fleurs"], "path": HERE / "audio" / "fleurs_orig" / r["real_clip_file"]})
        out.append({"clip_id": f"{r['pair_id']}_ai", "pair_id": r["pair_id"], "cls": "ai", "tool": r["ai_tool"], "split": r["split"],
                    "gender": r["ai_voice_gender"], "path": HERE / rec[r["pair_id"]]["file"]})
    assert len(out) == 80
    return out


def process(c):
    info = sf.info(str(c["path"]))
    x_native, sr_native = sf.read(str(c["path"]), dtype="float64")
    assert info.channels == 1, c["clip_id"]
    row = {"clip_id": c["clip_id"], "pair_id": c["pair_id"], "class": c["cls"], "tool": c["tool"], "split": c["split"], "gender": c["gender"],
           "orig_sample_rate": sr_native, "orig_channels": info.channels, "orig_format": f"{info.format}/{info.subtype}",
           "orig_bit_depth": {"FLOAT": 32, "PCM_16": 16, "PCM_24": 24, "DOUBLE": 64}.get(info.subtype, ""), "orig_duration_s": f"{len(x_native) / sr_native:.3f}",
           "native_rolloff95_hz": f"{rolloff95(x_native, sr_native):.0f}", "orig_file": str(c["path"].relative_to(HERE)).replace("\\", "/"),
           "orig_sha256": sha(c["path"])}
    # ---- clean arm ----
    x, _ = server_samples(c["path"].read_bytes())                     # 16 kHz mono float32, production decoder
    pre = features(x)
    for k, v in pre.items():
        row[f"pre_{k}"] = f"{v:.4f}"
    y, tinfo = trim(x)
    lead_s, trail_s = tinfo["start"] / SR, (len(x) - tinfo["end"]) / SR
    removed = np.concatenate([x[:tinfo["start"]], x[tinfo["end"]:]]) if (tinfo["start"] or tinfo["end"] < len(x)) else np.array([], dtype=np.float32)
    rem_db = frame_dbfs(removed) if len(removed) else np.array([-200.0])
    e_total = float(np.sum(x.astype(np.float64) ** 2))
    row.update({"trim_lead_s": f"{lead_s:.3f}", "trim_trail_s": f"{trail_s:.3f}", "trim_total_s": f"{lead_s + trail_s:.3f}",
                "trim_no_active_frames": tinfo["no_active_frames"],
                "removed_max_frame_dbfs": f"{float(np.max(rem_db)):.1f}",
                "removed_energy_fraction": f"{(float(np.sum(removed.astype(np.float64) ** 2)) / e_total) if e_total else 0.0:.6f}",
                "removed_peak_dbfs": f"{db(np.max(np.abs(removed))) if len(removed) else -200.0:.1f}",
                "trimmed_rms_dbfs": f"{db(np.sqrt(np.mean(y.astype(np.float64) ** 2))):.2f}", "trimmed_peak_dbfs": f"{db(np.max(np.abs(y))):.2f}"})
    z, gain_db, capped = normalise(y)
    q, n_clipped = to_int16(z)
    CLEAN.mkdir(parents=True, exist_ok=True)
    cpath = CLEAN / f"{c['clip_id']}.wav"
    sf.write(str(cpath), q, SR, subtype="PCM_16")
    row.update({"gain_db": f"{gain_db:.2f}", "peak_cap_applied": int(capped), "clean_clipped_samples": n_clipped,
                "clean_file": f"audio/clean/{cpath.name}", "clean_sha256": sha(cpath)})
    xc, _ = sf.read(str(cpath), dtype="float64")
    for k, v in features(xc).items():                                  # features of the file the detector will see
        row[f"clean_{k}"] = f"{v:.4f}"
    # ---- raw arm: ONLY the sample format changes ----
    qr, n_clip_raw = to_int16(x_native)
    RAW.mkdir(parents=True, exist_ok=True)
    rpath = RAW / f"{c['clip_id']}.wav"
    sf.write(str(rpath), qr, sr_native, subtype="PCM_16")
    back, sr_back = sf.read(str(rpath), dtype="float64")
    xr, _ = server_samples(rpath.read_bytes())                         # what the production server sees for the raw arm
    row.update({"raw_sample_rate": sr_back, "raw_channels": sf.info(str(rpath)).channels, "raw_frames_equal": int(len(back) == len(x_native)),
                "raw_clipped_samples": n_clip_raw, "raw_max_quant_error": f"{float(np.max(np.abs(back - x_native))):.2e}",
                "raw_file": f"audio/raw_arm/{rpath.name}", "raw_sha256": sha(rpath)})
    for k, v in features(xr).items():
        row[f"raw_{k}"] = f"{v:.4f}"
    return row


def summarise(rows):
    def grp(sel):
        return [r for r in rows if sel(r)]

    def mmm(rs, col):
        v = [float(r[col]) for r in rs]
        return f"{min(v):7.2f} / {st.median(v):7.2f} / {max(v):7.2f}"
    groups = [("REAL (all 40)", grp(lambda r: r["class"] == "real")), ("AI (all 40)", grp(lambda r: r["class"] == "ai"))]
    groups += [(f"AI {t}", grp(lambda r, t=t: r["class"] == "ai" and r["tool"] == t)) for t in ("mms", "vieneu-turbo", "vieneu-nano")]
    print("\nSTATISTICS: min / median / max   (pre = decoded 16 kHz signal before trimming; trimmed = after trimming, before normalisation)")
    for name, rs in groups:
        print(f"\n== {name}  (n={len(rs)})")
        print(f"  duration before trimming (s)       {mmm(rs, 'pre_duration_s')}")
        print(f"  leading silence before trim (s)    {mmm(rs, 'pre_lead_silence_s')}")
        print(f"  trailing silence before trim (s)   {mmm(rs, 'pre_trail_silence_s')}")
        print(f"  RMS before normalisation (dBFS)    {mmm(rs, 'trimmed_rms_dbfs')}")
        print(f"  peak before normalisation (dBFS)   {mmm(rs, 'trimmed_peak_dbfs')}")
        print(f"  95% roll-off at 16 kHz (Hz)        {mmm(rs, 'pre_rolloff95_hz')}")
        print(f"  95% roll-off at native rate (Hz)   {mmm(rs, 'native_rolloff95_hz')}")
        print(f"  noise floor before trim (dBFS)     {mmm(rs, 'pre_noise_floor_dbfs')}")
        rates = {}
        for r in rs:
            rates[int(r["orig_sample_rate"])] = rates.get(int(r["orig_sample_rate"]), 0) + 1
        fmts = {}
        for r in rs:
            key = f"{r['orig_format']} ({r['orig_bit_depth']}-bit)"
            fmts[key] = fmts.get(key, 0) + 1
        print(f"  original sample rate (Hz): {dict(sorted(rates.items()))} | original format: {fmts}")
        print(f"  duration after trimming (s)        {mmm(rs, 'clean_duration_s')}")


def main():
    clips = clip_list()
    rows = [process(c) for c in clips]
    cols = list(rows[0])
    with open(STATS, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols, lineterminator="\n")
        w.writeheader()
        w.writerows(rows)
    print(f"prepared {len(rows)} clips: clean arm -> {CLEAN.name}/ (16-bit PCM, 16 kHz mono), raw arm -> {RAW.name}/ (16-bit PCM, original rate); statistics -> {STATS.name}")

    # ---- trimming check: only silence removed ----
    print("\nTRIM CHECK (the removed parts must stay below the silence rule of %.0f dBFS)" % SILENCE_DBFS)
    bad = [r["clip_id"] for r in rows if float(r["removed_max_frame_dbfs"]) >= SILENCE_DBFS]
    print(f"  clips whose removed parts contain a frame at or above {SILENCE_DBFS:.0f} dBFS: {bad or 'none'}")
    print(f"  clips with no active frame (left untrimmed): {[r['clip_id'] for r in rows if int(r['trim_no_active_frames']) == 1] or 'none'}")
    for cls in ("real", "ai"):
        rs = [r for r in rows if r["class"] == cls]
        lead = max(rs, key=lambda r: float(r["trim_lead_s"])); trail = max(rs, key=lambda r: float(r["trim_trail_s"]))
        tot = max(rs, key=lambda r: float(r["trim_total_s"])); en = max(rs, key=lambda r: float(r["removed_energy_fraction"]))
        loud = max(rs, key=lambda r: float(r["removed_max_frame_dbfs"]))
        print(f"  {cls.upper():4s}: largest leading trim {lead['trim_lead_s']} s ({lead['clip_id']}), trailing {trail['trim_trail_s']} s ({trail['clip_id']}), "
              f"total {tot['trim_total_s']} s ({tot['clip_id']}); loudest removed frame {loud['removed_max_frame_dbfs']} dBFS ({loud['clip_id']}); "
              f"largest share of clip energy removed {float(en['removed_energy_fraction']) * 100:.4f}% ({en['clip_id']}); "
              f"median trimmed {st.median(float(r['trim_total_s']) for r in rs):.2f} s")
    # ---- normalisation / quantisation checks ----
    capped = [r["clip_id"] for r in rows if int(r["peak_cap_applied"]) == 1]
    print(f"\nNORMALISATION: clips where the -1 dBFS peak cap lowered the gain (end below -23 dBFS RMS): {capped or 'none'}")
    print(f"  clean-arm clipped samples: {sum(int(r['clean_clipped_samples']) for r in rows)} | final clean RMS dBFS min/median/max: "
          f"{min(float(r['clean_rms_dbfs']) for r in rows):.2f} / {st.median(float(r['clean_rms_dbfs']) for r in rows):.2f} / {max(float(r['clean_rms_dbfs']) for r in rows):.2f} "
          f"| final peak max {max(float(r['clean_peak_dbfs']) for r in rows):.2f} dBFS")
    print(f"RAW ARM: files with the same frame count as the original: {sum(int(r['raw_frames_equal']) for r in rows)} of 80 | sample rates unchanged: "
          f"{all(int(r['raw_sample_rate']) == int(r['orig_sample_rate']) for r in rows)} | channels all 1: {all(int(r['raw_channels']) == 1 for r in rows)} | "
          f"clipped samples: {sum(int(r['raw_clipped_samples']) for r in rows)} | largest rounding error (full scale = 1): {max(float(r['raw_max_quant_error']) for r in rows):.1e}")
    short = [(r["clip_id"], r["clean_duration_s"]) for r in rows if float(r["clean_duration_s"]) < SHORT_S]
    print(f"\nCLIPS BELOW {SHORT_S:g} s AFTER TRIMMING: {len(short)} of 80 -> {short or 'none'}")
    for cls in ("real", "ai"):
        print(f"  {cls}: {sum(1 for r in rows if r['class'] == cls and float(r['clean_duration_s']) < SHORT_S)}")
    summarise(rows)


if __name__ == "__main__":
    main()
