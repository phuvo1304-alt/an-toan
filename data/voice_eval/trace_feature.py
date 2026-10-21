"""Stage 2 / step 6b: the "sample-rate trace" feature, DEFINED BEFORE it was computed on anything. No scoring.

Why: the AI clips were synthesized at 24 or 48 kHz and are converted to 16 kHz by the production server, while the real
clips are natively 16 kHz. The original sample rate separates the held-out classes perfectly (AUC 1.000) but the server
discards it. The question this feature asks is whether a TRACE of that conversion is still present in the signal the
detector actually sees.

DEFINITION (fixed here, before any value was computed):
  signal  : the clip as the production voice server converts it (its own ffmpeg command): 16 kHz mono float32;
  spectrum: the average power spectrum of that signal over 1024-sample Hann frames, hop 512 (the same estimator as the
            95% roll-off statistic);
  feature : hf_edge_db = 10 * log10( P[7000 Hz, 8000 Hz) / P[1000 Hz, 3000 Hz) ), where P[a, b) is the sum of the average
            power over the FFT bins with a <= f < b (1e-20 added to both sums). It is the energy just below the 16 kHz
            Nyquist frequency (where a resampler's anti-alias filter and a recording device's own low-pass leave their
            different marks) relative to the speech band.
  AUC     : held-out (24 real + 24 AI) AUC of the single feature, AI = positive, direction chosen on the tuning set
            (16 + 16), exactly like the single-feature AUCs of shortcut_check.py; 95% interval from the same stratified
            bootstrap (2,000 resamples, seed 20261021). An arm is "trace-flagged" if this AUC is at least 0.75 (the same
            threshold as the shortcut check). The direction-free value max(AUC, 1 - AUC) is reported next to it.
  arms    : clean, noise-matched, matched raw, the three phone-like arms (and, for context, plain raw and level-randomized raw).
Nothing is tuned: no band, threshold or direction rule may be changed after seeing a value.

    <.venv-vieneu>/python -I -X utf8 trace_feature.py        (needs numpy, soundfile, ffmpeg through server_accepts.py)
"""
import csv
import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
from server_accepts import server_samples_unchecked  # noqa: E402
from shortcut_check import BOOT_B, BOOT_SEED, THRESHOLD, auc  # noqa: E402

SR = 16_000
NFFT, HOP = 1024, 512
HIGH_BAND, REF_BAND = (7000.0, 8000.0), (1000.0, 3000.0)
EPS = 1e-20
# arm name -> (folder under audio/, file extension, is a gate arm in PLAN.md section 8 / reported only)
ARMS = {
    "clean": ("clean", ".wav", "gate"),
    "noise_matched": ("noise_matched", ".wav", "gate"),
    "matched_raw": ("raw_matched", ".wav", "gate"),
    "phone_aac": ("phone_aac", ".m4a", "phone-like"),
    "phone_opus": ("phone_opus", ".ogg", "phone-like"),
    "phone_amr": ("phone_amr", ".amr", "phone-like"),
    "raw": ("raw_arm", ".wav", "descriptive"),
    "level_randomized_raw": ("raw_level_random", ".wav", "descriptive"),
}


def hf_edge_db(x16):
    x = np.asarray(x16, dtype=np.float64)
    if len(x) < NFFT:
        x = np.pad(x, (0, NFFT - len(x)))
    win = np.hanning(NFFT)
    frames = np.stack([x[i:i + NFFT] * win for i in range(0, len(x) - NFFT + 1, HOP)])
    power = np.mean(np.abs(np.fft.rfft(frames, axis=1)) ** 2, axis=0)
    freqs = np.arange(len(power)) * SR / NFFT
    p = lambda lo, hi: float(power[(freqs >= lo) & (freqs < hi)].sum()) + EPS  # noqa: E731
    return 10.0 * np.log10(p(*HIGH_BAND) / p(*REF_BAND))


def main():
    sel = list(csv.DictReader(open(HERE / "selection.csv", encoding="utf-8", newline="")))
    clips = [(f"{r['pair_id']}_{c}", c, r["split"]) for r in sel for c in ("real", "ai")]
    y = np.array([1 if c == "ai" else 0 for _, c, _ in clips])
    tun = np.array([s == "tuning" for _, _, s in clips])
    y_te = y[~tun]
    rng = np.random.default_rng(BOOT_SEED)
    pos, neg = np.where(y_te == 1)[0], np.where(y_te == 0)[0]
    boots = [np.concatenate([rng.choice(pos, len(pos)), rng.choice(neg, len(neg))]) for _ in range(BOOT_B)]
    out, table = {"feature": "hf_edge_db = 10*log10(P[7000,8000) / P[1000,3000)) of the server-converted 16 kHz signal",
                  "threshold": THRESHOLD, "bootstrap": {"resamples": BOOT_B, "seed": BOOT_SEED}, "arms": {}}, []
    for arm, (folder, ext, kind) in ARMS.items():
        vals = []
        for cid, _, _ in clips:
            p = HERE / "audio" / folder / f"{cid}{ext}"
            vals.append(hf_edge_db(server_samples_unchecked(p.read_bytes())))
        v = np.array(vals)
        a_tun = auc(v[tun], y[tun])
        sign = 1.0 if a_tun >= 0.5 else -1.0
        a = auc(sign * v[~tun], y_te)
        lo, hi = np.percentile([auc(sign * v[~tun][i], y_te[i]) for i in boots], [2.5, 97.5])
        free = max(a, 1.0 - a)
        res = {"kind": kind, "heldout_auc": round(a, 3), "ci95": [round(float(lo), 3), round(float(hi), 3)], "tuning_auc": round(a_tun, 3),
               "direction": "AI higher" if sign > 0 else "AI lower", "direction_free_auc": round(free, 3),
               "trace_flagged": bool(a >= THRESHOLD), "trace_flagged_direction_free": bool(free >= THRESHOLD),
               "median_real_db": round(float(np.median(v[y == 0])), 2), "median_ai_db": round(float(np.median(v[y == 1])), 2),
               "values": {cid: round(float(x), 3) for (cid, _, _), x in zip(clips, vals)}}
        out["arms"][arm] = res
        table.append((arm, res))
    (HERE / "trace_feature.json").write_text(json.dumps(out, indent=1), encoding="utf-8")
    print(f"{'arm':22s} {'kind':12s} {'held-out AUC':>12s} {'95% interval':>16s} {'tuning':>7s} {'direction-free':>14s}  flagged  median real -> AI (dB)")
    for arm, r in table:
        print(f"{arm:22s} {r['kind']:12s} {r['heldout_auc']:12.3f}  [{r['ci95'][0]:.3f}, {r['ci95'][1]:.3f}] {r['tuning_auc']:7.3f} {r['direction_free_auc']:14.3f}  "
              f"{'YES' if r['trace_flagged'] else 'no ':3s}      {r['median_real_db']:7.2f} -> {r['median_ai_db']:7.2f} ({r['direction']})")
    print("written: trace_feature.json")


if __name__ == "__main__":
    main()
