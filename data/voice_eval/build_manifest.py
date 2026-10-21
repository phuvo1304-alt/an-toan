"""Stage 2 (PLAN.md section 5): writes manifest.csv for the scoring arms. Run once at the freeze; the output is hashed in
manifest.sha256 BEFORE the first score. Reads selection.csv, ai_clips_record.csv, prepare_stats.csv, phone_stats.csv and the audio
files (git-ignored). The Zalo phone-path set is NOT here; it gets its own manifest when recorded.

    python -I -X utf8 build_manifest.py          (VOICE_FFMPEG_BIN set; the venv with numpy)
"""
import csv
import hashlib
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from server_accepts import server_decode  # noqa: E402

REPO = HERE.parent.parent
# arm -> (folder, extension, stats prefix, stats file, kind, derived_from)
ARMS = {
    "clean": ("clean", ".wav", "clean", "prepare_stats.csv", "gate", "original clip"),
    "noise_matched": ("noise_matched", ".wav", "nm", "prepare_stats.csv", "gate", "original clip (AI clips get simulated pink noise)"),
    "matched_raw": ("raw_matched", ".wav", "mr", "prepare_stats.csv", "gate", "original clip (simulated gain, AI padding and noise)"),
    "raw": ("raw_arm", ".wav", "raw", "prepare_stats.csv", "descriptive", "original clip, only converted to 16-bit mono"),
    "phone_aac": ("phone_aac", ".m4a", "pac", "phone_stats.csv", "phone-like (simulated)", "clean arm clip, band-limit 300-3400 Hz, 30 dB SNR noise, AAC 24 kbps"),
    "phone_opus": ("phone_opus", ".ogg", "pop", "phone_stats.csv", "phone-like (simulated)", "clean arm clip, band-limit 300-3400 Hz, 30 dB SNR noise, Opus 12 kbps"),
    "phone_amr": ("phone_amr", ".amr", "pam", "phone_stats.csv", "phone-like (simulated)", "clean arm clip, band-limit 300-3400 Hz, 30 dB SNR noise, AMR-NB 12.2 kbps"),
}
ARM_SEEDS = {"clean": "none", "noise_matched": 20261022, "matched_raw": 20261024, "raw": "none", "phone_aac": 20261025, "phone_opus": 20261025, "phone_amr": 20261025}
FIELDS = ["clip_id", "arm", "arm_kind", "pair_id", "role", "split", "source", "source_split", "sentence_id", "speaker_label", "tool", "voice", "gender",
          "gender_check", "derived_from", "duration_s", "orig_sample_rate", "lead_silence_s", "trail_silence_s", "server_accepts", "file", "bytes", "sha256",
          "tts_model_commit", "seed"]


def git(*a):
    return subprocess.run(["git", "-C", str(REPO), *a], capture_output=True, text=True, check=True).stdout.strip()


def main():
    sel = list(csv.DictReader(open(HERE / "selection.csv", encoding="utf-8", newline="")))
    rec = {r["pair_id"]: r for r in csv.DictReader(open(HERE / "ai_clips_record.csv", encoding="utf-8", newline=""))}
    stats = {}
    for f in ("prepare_stats.csv", "phone_stats.csv"):
        for r in csv.DictReader(open(HERE / f, encoding="utf-8", newline="")):
            stats.setdefault(r["clip_id"], {}).update(r)
    rows = []
    for arm, (folder, ext, pre, _, kind, derived) in ARMS.items():
        for s in sel:
            for role in ("real", "ai"):
                cid = f"{s['pair_id']}_{role}"
                p = HERE / "audio" / folder / f"{cid}{ext}"
                data = p.read_bytes()
                ok, _, secs = server_decode(data)
                st = stats[cid]
                heldout_tts = s["split"] == "heldout" and role == "ai"
                rows.append({
                    "clip_id": "c" + hashlib.sha256(f"{arm}|{cid}".encode()).hexdigest()[:10], "arm": arm, "arm_kind": kind, "pair_id": s["pair_id"],
                    "role": role, "split": s["split"], "source": "fleurs" if role == "real" else "tts", "source_split": s["real_source"] if role == "real" else "",
                    "sentence_id": s["sentence_id"], "speaker_label": f"unknown-{s['real_gender_fleurs']}" if role == "real" else s["ai_voice"],
                    "tool": "fleurs" if role == "real" else s["ai_tool"], "voice": "" if role == "real" else s["ai_voice"],
                    "gender": s["real_gender_fleurs"] if role == "real" else s["ai_voice_gender"],
                    "gender_check": "n/a" if role == "real" else ("unknown" if s["ai_tool"] == "mms" else ("human-blind-confirmed" if heldout_tts else "declared-unverified")),
                    "derived_from": derived, "duration_s": f"{secs:.2f}" if ok else "", "orig_sample_rate": st["orig_sample_rate"],
                    "lead_silence_s": st[f"{pre}_lead_silence_s"] if f"{pre}_lead_silence_s" in st else "",
                    "trail_silence_s": st[f"{pre}_trail_silence_s"] if f"{pre}_trail_silence_s" in st else "",
                    "server_accepts": int(ok), "file": f"audio/{folder}/{cid}{ext}", "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
                    "tts_model_commit": rec[s["pair_id"]]["model_commit"] if role == "ai" else "", "seed": ARM_SEEDS[arm] if role == "real" or arm != "clean" else rec[s["pair_id"]]["seed"],
                })
    header = {
        "manifest": "An Toan voice evaluation, scoring arms (Zalo set excluded)",
        "created": "2026-10-22",
        "model_repo": "garystafford/wav2vec2-deepfake-voice-detector",
        "model_revision": [l for l in (REPO / "voice-server/app/config.py").read_text(encoding="utf-8").splitlines() if l.startswith("MODEL_REVISION")][0].split('"')[1],
        "voice_server_commit": git("log", "-1", "--format=%H", "--", "voice-server"),
        "selection_sha256": hashlib.sha256((HERE / "selection.csv").read_bytes()).hexdigest(),
        "fleurs_revision": "70bb2e84b976b7e960aa89f1c648e09c59f894dd",
        "arms": ",".join(ARMS),
        "ffmpeg_for_arm_encoding": "9.0.2-full_build (local, simulated codecs)",
        "rows": str(len(rows)),
    }
    with open(HERE / "manifest.csv", "w", encoding="utf-8", newline="") as f:
        for k, v in header.items():
            f.write(f"#{k}: {v}\n")
        w = csv.DictWriter(f, fieldnames=FIELDS, lineterminator="\n")
        w.writeheader()
        w.writerows(rows)
    print(f"manifest.csv: {len(rows)} rows, arms {list(ARMS)}; server decode accepted {sum(r['server_accepts'] for r in rows)}/{len(rows)}")


if __name__ == "__main__":
    main()
