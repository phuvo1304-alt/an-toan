"""Stage 2 / step 6b: the three PHONE-LIKE arms (PLAN.md section 3), SIMULATED. Scores nothing, does not touch the detector.

From the CLEAN arm of all 80 clips (audio/clean/<clip>.wav, 16 kHz mono):
  1. band-limit to 300-3400 Hz: zero-phase, FFT-domain, Butterworth-shaped magnitude (4th order) at both edges;
  2. add seeded white Gaussian noise at 30.0 dB SNR relative to the band-limited clip's RMS (seed 20261025 per clip);
  3. encode with the local ffmpeg:  AAC 24 kbps -> .m4a | Opus 12 kbps (voip) -> .ogg | AMR-NB 12.2 kbps (8 kHz) -> .amr.
Each file follows its original into the same split and adds nothing to n. Then every file is run through the REAL production
decoder (server_accepts.server_decode) and the number accepted is reported; the features of the shortcut check are measured on
the server-converted signal and written to phone_stats.csv (prefixes pac_ = AAC, pop_ = Opus, pam_ = AMR-NB).
Codecs are simulated with the local ffmpeg (9.0.2-full_build, libopencore_amrnb for AMR-NB); the Debian ffmpeg of the production
image is NOT verified to decode AMR (Docker is unusable on this machine).

    python -I -X utf8 prepare_phone_arms.py     (numpy, soundfile; VOICE_FFMPEG_BIN set to a full ffmpeg)
"""
import csv
import hashlib
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
from prepare_audio import SR, add_features, clip_list, rng_for, write16  # noqa: E402
from server_accepts import server_decode, server_samples_unchecked  # noqa: E402

PHONE_SEED = 20261025
BAND_HZ = (300.0, 3400.0)
BUTTER_ORDER = 4
SNR_DB = 30.0
FFMPEG = os.environ.get("VOICE_FFMPEG_BIN", "ffmpeg")
ARMS = {  # arm -> (folder, extension, stats prefix, ffmpeg codec arguments)
    "phone_aac": ("phone_aac", ".m4a", "pac", ["-c:a", "aac", "-b:a", "24k"]),
    "phone_opus": ("phone_opus", ".ogg", "pop", ["-c:a", "libopus", "-b:a", "12k", "-application", "voip"]),
    "phone_amr": ("phone_amr", ".amr", "pam", ["-ar", "8000", "-ac", "1", "-c:a", "libopencore_amrnb", "-b:a", "12.2k"]),
}


def band_limit(x):
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    lo, hi = BAND_HZ
    mag = 1.0 / np.sqrt(1.0 + (f / hi) ** (2 * BUTTER_ORDER))                                          # low-pass
    mag *= 1.0 / np.sqrt(1.0 + (lo / np.maximum(f, 1e-9)) ** (2 * BUTTER_ORDER))                      # high-pass
    mag[0] = 0.0
    return np.fft.irfft(X * mag, n)


def make_source(cid):
    import soundfile as sf
    x, sr = sf.read(str(HERE / "audio" / "clean" / f"{cid}.wav"), dtype="float64")
    assert sr == SR and x.ndim == 1
    y = band_limit(x)
    rms = float(np.sqrt(np.mean(y ** 2)))
    noise = rng_for(PHONE_SEED, cid).standard_normal(len(y))
    noise *= rms / (10 ** (SNR_DB / 20.0)) / np.sqrt(np.mean(noise ** 2))
    z = y + noise
    peak = float(np.max(np.abs(z)))
    return z / peak * 10 ** (-1.0 / 20.0) if peak > 10 ** (-1.0 / 20.0) else z       # only if it would pass -1 dBFS (then scaled, noted)


def encode(src_wav, dst, codec_args):
    dst.parent.mkdir(parents=True, exist_ok=True)
    cmd = [FFMPEG, "-hide_banner", "-loglevel", "error", "-y", "-i", str(src_wav), *codec_args, str(dst)]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0 or not dst.exists() or dst.stat().st_size == 0:
        raise SystemExit(f"ffmpeg failed for {dst.name}: {r.stderr.strip()[:300]}")


def main():
    clips = clip_list()
    rows = [{"clip_id": c["clip_id"], "class": c["cls"], "split": c["split"]} for c in clips]
    counts = {a: {"accepted": 0, "rejected": []} for a in ARMS}
    with tempfile.TemporaryDirectory() as td:
        for c, row in zip(clips, rows):
            cid = c["clip_id"]
            src = Path(td) / f"{cid}.wav"
            write16(src, make_source(cid), SR)
            for arm, (folder, ext, pre, codec) in ARMS.items():
                dst = HERE / "audio" / folder / f"{cid}{ext}"
                encode(src, dst, codec)
                data = dst.read_bytes()
                ok, code, secs = server_decode(data)
                if ok:
                    counts[arm]["accepted"] += 1
                else:
                    counts[arm]["rejected"].append(f"{cid}:{code}")
                add_features(row, pre, server_samples_unchecked(data))
                row[f"{pre}_server_accepts"] = int(ok)
                row[f"{pre}_file"] = f"audio/{folder}/{cid}{ext}"
                row[f"{pre}_bytes"] = len(data)
                row[f"{pre}_sha256"] = hashlib.sha256(data).hexdigest()
    with open(HERE / "phone_stats.csv", "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    print("server decode (real voice-server audio.decode), accepted of 80:")
    for arm, r in counts.items():
        print(f"  {arm:11s} {r['accepted']}/80  rejected: {r['rejected'] or 'none'}")
    print("written: phone_stats.csv")


if __name__ == "__main__":
    main()
