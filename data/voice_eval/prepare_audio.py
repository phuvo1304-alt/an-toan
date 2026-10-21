"""Stage 2 / step 6a (version after deviation D5): prepare the audio of the 80 clips. NO scoring.

For each of the 40 pairs there is a real clip (FLEURS) and an AI clip (selection.csv + ai_clips_record.csv).
Four arms are written (all 16-bit PCM WAV, git-ignored under audio/):

CLEAN ARM  (audio/clean/<pair>_<real|ai>.wav)   16 kHz mono
  1. decode with the production voice server's own decoder (ffmpeg) from the ORIGINAL float32 file;
  2. gain 1: bring the WHOLE decoded clip to -28 dBFS RMS (float, no peak limit at this intermediate stage);
  3. trim leading/trailing silence: 20 ms non-overlapping frames (320 samples), silent if RMS < -45 dBFS (absolute),
     keep 10 frames = 0.2 s of padding each side -> the same threshold now behaves the same on quiet and loud clips;
  4. gain 2: bring the TRIMMED clip to exactly -28 dBFS RMS; the -1 dBFS peak cap is checked on this final clip only;
  5. write 16-bit PCM: round(x * 32767), clipped to the int16 range, no dither.
RAW ARM  (audio/raw_arm/)  original sample rate, mono; ONLY the sample format is converted to 16-bit PCM.
NOISE-MATCHED ARM  (audio/noise_matched/)  SIMULATED. Clean-arm files; the AI clips additionally get seeded pink Gaussian
  noise so that each AI clip's noise floor equals a draw from the noise floors of the REAL clips of the same split.
LEVEL-RANDOMIZED RAW ARM  (audio/raw_level_random/)  SIMULATED. Raw arm with one seeded random gain, uniform -20..0 dB,
  on every clip of both classes (applied to the original float samples, then one 16-bit rounding).

Also writes prepare_stats.csv and prints the checks (trimming, equal RMS, peak cap, noise before/after, level arm).
Needs numpy, soundfile and ffmpeg (through server_accepts.py).

    <.venv-vieneu>/python -I -X utf8 prepare_audio.py
"""
import csv
import hashlib
import shutil
import statistics as st
import sys
import zlib
from pathlib import Path

import numpy as np
import soundfile as sf

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
from server_accepts import server_decode, server_samples, server_samples_unchecked  # noqa: E402

# ---- constants fixed in PLAN.md sections 2 and 8 (D5), written before the new statistics were computed ----
SR = 16_000
FRAME = 320                  # 20 ms at 16 kHz
SILENCE_DBFS = -45.0
PAD_FRAMES = 10              # 0.2 s of padding each side
TARGET_RMS_DBFS = -28.0
RMS_TOLERANCE_DB = 0.05      # "every clip ends at the same RMS"
PEAK_CAP_DBFS = -1.0
PCM_SCALE = 32767
NFFT, HOP, ROLLOFF_FRAC = 1024, 512, 0.95
SHORT_S = 3.0
NOISE_SEED, LEVEL_SEED = 20261022, 20261023
NOISE_ITERS, NOISE_TOL_DB = 8, 0.25
LEVEL_GAIN_RANGE_DB = (-20.0, 0.0)
# ---- deviation D6 (matched raw arm), fixed in PLAN.md section 2 before it was prepared or checked ----
MATCH_SEED = 20261024
MATCH_LEVEL_RANGE_DBFS = (-40.0, -20.0)   # common whole-clip RMS target, drawn per clip, independent of class

CLEAN, RAW = HERE / "audio" / "clean", HERE / "audio" / "raw_arm"
NOISE, LEVEL = HERE / "audio" / "noise_matched", HERE / "audio" / "raw_level_random"
MATCHED = HERE / "audio" / "raw_matched"
STATS = HERE / "prepare_stats.csv"


def db(v):
    return 20.0 * np.log10(max(float(v), 1e-12))


def rms_db(x):
    return db(np.sqrt(np.mean(np.asarray(x, dtype=np.float64) ** 2)))


def frame_dbfs(x):
    n = int(np.ceil(len(x) / FRAME))
    return np.array([db(np.sqrt(np.mean(np.asarray(x[i * FRAME:(i + 1) * FRAME], dtype=np.float64) ** 2))) for i in range(n)])


def rolloff95(x, sr):
    x = np.asarray(x, dtype=np.float64)
    if len(x) < NFFT:
        x = np.pad(x, (0, NFFT - len(x)))
    win = np.hanning(NFFT)
    frames = np.stack([x[i:i + NFFT] * win for i in range(0, len(x) - NFFT + 1, HOP)])
    power = np.mean(np.abs(np.fft.rfft(frames, axis=1)) ** 2, axis=0)
    return int(np.searchsorted(np.cumsum(power), ROLLOFF_FRAC * power.sum())) * sr / NFFT


def noise_floor(x):
    return float(np.percentile(frame_dbfs(x), 10))


def features(x16):
    """The seven shortcut-check features of a 16 kHz mono signal."""
    f = frame_dbfs(x16)
    active = f >= SILENCE_DBFS
    if active.any():
        lead, trail = int(np.argmax(active)), int(len(active) - 1 - np.max(np.where(active)))
    else:
        lead, trail = len(active), 0
    return {"duration_s": len(x16) / SR, "lead_silence_s": lead * FRAME / SR, "trail_silence_s": trail * FRAME / SR,
            "noise_floor_dbfs": float(np.percentile(f, 10)), "rms_dbfs": rms_db(x16),
            "peak_dbfs": db(np.max(np.abs(x16))), "rolloff95_hz": rolloff95(x16, SR)}


def trim(x):
    f = frame_dbfs(x)
    active = np.where(f >= SILENCE_DBFS)[0]
    if len(active) == 0:
        return x, {"no_active_frames": 1, "start": 0, "end": len(x)}
    return x[max(0, (int(active[0]) - PAD_FRAMES) * FRAME):min(len(x), (int(active[-1]) + 1 + PAD_FRAMES) * FRAME)], \
        {"no_active_frames": 0, "start": max(0, (int(active[0]) - PAD_FRAMES) * FRAME), "end": min(len(x), (int(active[-1]) + 1 + PAD_FRAMES) * FRAME)}


def to_int16(x):
    q = np.round(np.asarray(x, dtype=np.float64) * PCM_SCALE)
    return np.clip(q, -32768, 32767).astype("<i2"), int(np.sum(np.abs(q) > 32767))


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def rng_for(seed, clip_id):
    return np.random.default_rng(np.random.SeedSequence([seed, zlib.crc32(clip_id.encode("utf-8"))]))


def pink(n, rng):
    """Gaussian noise with power proportional to 1/f (white noise shaped in the frequency domain), unit RMS."""
    W = np.fft.rfft(rng.standard_normal(n))
    f = np.arange(len(W), dtype=np.float64)
    f[0] = 1.0
    W = W / np.sqrt(f)
    W[0] = 0.0
    p = np.fft.irfft(W, n)
    return p / np.sqrt(np.mean(p ** 2))


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


def write16(path, x, sr):
    q, clipped = to_int16(x)
    path.parent.mkdir(parents=True, exist_ok=True)
    sf.write(str(path), q, sr, subtype="PCM_16")
    return clipped


def add_features(row, prefix, x16):
    for k, v in features(x16).items():
        row[f"{prefix}_{k}"] = f"{v:.4f}"


def process(c):
    info = sf.info(str(c["path"]))
    x_native, sr_native = sf.read(str(c["path"]), dtype="float64")
    assert info.channels == 1, c["clip_id"]
    row = {"clip_id": c["clip_id"], "pair_id": c["pair_id"], "class": c["cls"], "tool": c["tool"], "split": c["split"], "gender": c["gender"],
           "orig_sample_rate": sr_native, "orig_channels": info.channels, "orig_format": f"{info.format}/{info.subtype}",
           "orig_bit_depth": {"FLOAT": 32, "PCM_16": 16, "PCM_24": 24, "DOUBLE": 64}.get(info.subtype, ""),
           "orig_duration_s": f"{len(x_native) / sr_native:.3f}", "native_rolloff95_hz": f"{rolloff95(x_native, sr_native):.0f}",
           "orig_file": str(c["path"].relative_to(HERE)).replace("\\", "/"), "orig_sha256": sha(c["path"])}
    # ---------------- clean arm ----------------
    x, _ = server_samples(c["path"].read_bytes())                      # 16 kHz mono float32, production decoder
    add_features(row, "pre", x)
    g1_db = TARGET_RMS_DBFS - rms_db(x)                                # gain 1: whole clip -> -28 dBFS (float, no cap)
    xs = x.astype(np.float64) * 10 ** (g1_db / 20.0)
    ys, ti = trim(xs)
    removed = np.concatenate([xs[:ti["start"]], xs[ti["end"]:]]) if (ti["start"] or ti["end"] < len(xs)) else np.array([])
    rem_db = frame_dbfs(removed) if len(removed) else np.array([-200.0])
    e_total = float(np.sum(xs ** 2))
    lead_s, trail_s = ti["start"] / SR, (len(xs) - ti["end"]) / SR
    g2_db = TARGET_RMS_DBFS - rms_db(ys)                               # gain 2: trimmed clip -> -28 dBFS
    capped = False
    if db(np.max(np.abs(ys))) + g2_db > PEAK_CAP_DBFS:                 # the cap applies to the FINAL clip only
        g2_db, capped = PEAK_CAP_DBFS - db(np.max(np.abs(ys))), True
    zs = ys * 10 ** (g2_db / 20.0)
    act_xs = frame_dbfs(xs) >= SILENCE_DBFS                            # edge silence of the normalized clip (used by the D6 arm)
    row["edge_lead_s"] = f"{(int(np.argmax(act_xs)) if act_xs.any() else len(act_xs)) * FRAME / SR:.3f}"
    row["edge_trail_s"] = f"{(int(len(act_xs) - 1 - np.max(np.where(act_xs))) if act_xs.any() else 0) * FRAME / SR:.3f}"
    row.update({"gain1_db": f"{g1_db:.2f}", "intermediate_peak_dbfs": f"{db(np.max(np.abs(xs))):.2f}", "gain2_db": f"{g2_db:.2f}",
                "peak_cap_applied": int(capped), "trim_lead_s": f"{lead_s:.3f}", "trim_trail_s": f"{trail_s:.3f}",
                "trim_total_s": f"{lead_s + trail_s:.3f}", "trim_no_active_frames": ti["no_active_frames"],
                "removed_max_frame_dbfs": f"{float(np.max(rem_db)):.1f}",
                "removed_energy_fraction": f"{(float(np.sum(removed ** 2)) / e_total) if e_total and len(removed) else 0.0:.6f}",
                "input_noise_floor_after_gain1_dbfs": f"{noise_floor(xs):.2f}"})
    cpath = CLEAN / f"{c['clip_id']}.wav"
    row["clean_clipped_samples"] = write16(cpath, zs, SR)
    row.update({"clean_file": f"audio/clean/{cpath.name}", "clean_sha256": sha(cpath)})
    xc, _ = sf.read(str(cpath), dtype="float64")
    add_features(row, "clean", xc)
    # ---------------- raw arm: ONLY the sample format changes ----------------
    clip_raw = write16(RAW / f"{c['clip_id']}.wav", x_native, sr_native)
    rpath = RAW / f"{c['clip_id']}.wav"
    back, sr_back = sf.read(str(rpath), dtype="float64")
    row.update({"raw_sample_rate": sr_back, "raw_channels": sf.info(str(rpath)).channels, "raw_frames_equal": int(len(back) == len(x_native)),
                "raw_clipped_samples": clip_raw, "raw_max_quant_error": f"{float(np.max(np.abs(back - x_native))):.2e}",
                "raw_file": f"audio/raw_arm/{rpath.name}", "raw_sha256": sha(rpath)})
    add_features(row, "raw", server_samples_unchecked(rpath.read_bytes()))
    # ---------------- level-randomized raw arm: seeded gain U(-20, 0) dB on every clip ----------------
    g_db = float(rng_for(LEVEL_SEED, c["clip_id"]).uniform(*LEVEL_GAIN_RANGE_DB))
    lpath = LEVEL / f"{c['clip_id']}.wav"
    clipped_l = write16(lpath, x_native * 10 ** (g_db / 20.0), sr_native)
    ok, code, _ = server_decode(lpath.read_bytes())
    row.update({"lr_gain_db": f"{g_db:.2f}", "lr_whole_clip_rms_dbfs_native": f"{rms_db(x_native * 10 ** (g_db / 20.0)):.2f}",
                "lr_server_decode": "ok" if ok else code, "lr_clipped_samples": clipped_l,
                "lr_file": f"audio/raw_level_random/{lpath.name}", "lr_sha256": sha(lpath)})
    add_features(row, "lr", server_samples_unchecked(lpath.read_bytes()))
    return row


def noise_matched(rows):
    """Second pass: noise-matched arm. Real clips are copied unchanged; AI clips get seeded pink noise."""
    NOISE.mkdir(parents=True, exist_ok=True)
    real_floors = {sp: sorted(float(r["clean_noise_floor_dbfs"]) for r in rows if r["class"] == "real" and r["split"] == sp)
                   for sp in ("tuning", "heldout")}
    for r in rows:
        src, dst = HERE / r["clean_file"], NOISE / f"{r['clip_id']}.wav"
        y, _ = sf.read(str(src), dtype="float64")
        if r["class"] == "real":
            shutil.copyfile(src, dst)
            r.update({"nm_target_floor_dbfs": "", "nm_noise_level_dbfs": "", "nm_iterations": 0, "nm_status": "real clip unchanged"})
        else:
            rng = rng_for(NOISE_SEED, r["clip_id"])
            target = float(rng.choice(real_floors[r["split"]]))
            own = noise_floor(y)
            status, level, it, mix = "", float("nan"), 0, y
            if own >= target - NOISE_TOL_DB:
                status = "no noise needed (own floor already at or above the draw)"
                shutil.copyfile(src, dst)                                          # identical to the clean-arm file
            else:
                n0 = pink(len(y), rng)
                level = target
                for it in range(1, NOISE_ITERS + 1):
                    mix = y + n0 * 10 ** (level / 20.0)
                    err = target - noise_floor(mix)
                    if abs(err) <= NOISE_TOL_DB:
                        break
                    level += float(np.clip(err, -6.0, 6.0))
                status = "noise added" if abs(target - noise_floor(mix)) <= NOISE_TOL_DB else "did not converge"
                mix = mix * 10 ** ((TARGET_RMS_DBFS - rms_db(mix)) / 20.0)        # back to exactly -28 dBFS RMS
                if db(np.max(np.abs(mix))) > PEAK_CAP_DBFS:                        # record and respect the final peak cap
                    mix = mix * 10 ** ((PEAK_CAP_DBFS - db(np.max(np.abs(mix)))) / 20.0)
                    status += "; peak cap applied"
                write16(dst, mix, SR)
            r.update({"nm_target_floor_dbfs": f"{target:.2f}", "nm_noise_level_dbfs": "" if np.isnan(level) else f"{level:.2f}",
                      "nm_iterations": it, "nm_status": status, "nm_own_floor_before_dbfs": f"{own:.2f}"})
        r["nm_file"], r["nm_sha256"] = f"audio/noise_matched/{dst.name}", sha(dst)
        add_features(r, "nm", sf.read(str(dst), dtype="float64")[0])


def floor_after_server(x, sr):
    """Noise floor of a float signal as the production server converts it (16 kHz mono), without quantization."""
    import io
    buf = io.BytesIO()
    sf.write(buf, np.asarray(x, dtype=np.float32), sr, format="WAV", subtype="FLOAT")
    return noise_floor(server_samples_unchecked(buf.getvalue()))


def matched_raw(rows, clips):
    """Deviation D6: the matched raw arm (SIMULATED). Common loudness for both classes; AI clips get real-like
    edge silence and matched pink noise. Native sample rate, mono, one final 16-bit rounding."""
    by_id = {c["clip_id"]: c for c in clips}
    real_by_split = {sp: sorted((r for r in rows if r["class"] == "real" and r["split"] == sp), key=lambda r: r["clip_id"])
                     for sp in ("tuning", "heldout")}
    for r in rows:
        x, sr = sf.read(str(by_id[r["clip_id"]]["path"]), dtype="float64")
        rng = rng_for(MATCH_SEED, r["clip_id"])
        level = float(rng.uniform(*MATCH_LEVEL_RANGE_DBFS))             # draw 1: common loudness (same distribution for both classes)
        xn = x * 10 ** ((TARGET_RMS_DBFS - rms_db(x)) / 20.0)           # normalized domain (whole-clip RMS -28 dBFS)
        mix = xn
        info = {"mr_pad_lead_s": "", "mr_pad_trail_s": "", "mr_drawn_real": "", "mr_target_floor_dbfs": "", "mr_noise_level_dbfs": "",
                "mr_iterations": 0, "mr_status": "real clip: gain only", "mr_floor_error_db": ""}
        if r["class"] == "ai":
            pool = real_by_split[r["split"]]
            j = pool[int(rng.integers(0, len(pool)))]                   # draw 2: which real clip's edge silence and noise floor
            pad_l = max(0.0, float(j["edge_lead_s"]) - float(r["edge_lead_s"]))
            pad_t = max(0.0, float(j["edge_trail_s"]) - float(r["edge_trail_s"]))
            xp = np.concatenate([np.zeros(int(round(pad_l * sr))), xn, np.zeros(int(round(pad_t * sr)))])
            target = float(j["input_noise_floor_after_gain1_dbfs"])     # the drawn real clip's floor, normalized domain
            info.update({"mr_pad_lead_s": f"{pad_l:.3f}", "mr_pad_trail_s": f"{pad_t:.3f}", "mr_drawn_real": j["clip_id"], "mr_target_floor_dbfs": f"{target:.2f}"})
            if pad_l == 0.0 and pad_t == 0.0 and floor_after_server(xp, sr) >= target - NOISE_TOL_DB:
                info["mr_status"] = "no noise needed (no padding, own floor already at or above the draw)"
                mix = xp
            else:
                n0 = pink(len(xp), rng)                                 # draw 3: the noise
                lvl, it = target, 0
                for it in range(1, NOISE_ITERS + 1):
                    mix = xp + n0 * 10 ** (lvl / 20.0)
                    err = target - floor_after_server(mix, sr)
                    if abs(err) <= NOISE_TOL_DB:
                        break
                    lvl += float(np.clip(err, -6.0, 6.0))
                err = target - floor_after_server(mix, sr)
                info.update({"mr_noise_level_dbfs": f"{lvl:.2f}", "mr_iterations": it, "mr_floor_error_db": f"{err:.2f}",
                             "mr_status": "padded and noise added" if abs(err) <= NOISE_TOL_DB else "did not converge"})
        gain_db = level - rms_db(mix)                                   # scale to the drawn common loudness
        capped = db(np.max(np.abs(mix))) + gain_db > PEAK_CAP_DBFS
        if capped:
            gain_db = PEAK_CAP_DBFS - db(np.max(np.abs(mix)))
        final = mix * 10 ** (gain_db / 20.0)
        path = MATCHED / f"{r['clip_id']}.wav"
        clipped = write16(path, final, sr)
        ok, code, _ = server_decode(path.read_bytes())
        r.update(info)
        r.update({"mr_level_target_dbfs": f"{level:.2f}", "mr_final_whole_rms_dbfs_native": f"{rms_db(final):.2f}", "mr_gain_db": f"{gain_db:.2f}",
                  "mr_capped": int(capped), "mr_server_decode": "ok" if ok else code, "mr_clipped_samples": clipped,
                  "mr_file": f"audio/raw_matched/{path.name}", "mr_sha256": sha(path)})
        add_features(r, "mr", server_samples_unchecked(path.read_bytes()))


def mmm(vals):
    return f"{min(vals):7.2f} / {st.median(vals):7.2f} / {max(vals):7.2f}"


def report(rows):
    f = lambda r, k: float(r[k])  # noqa: E731
    real = [r for r in rows if r["class"] == "real"]
    ai = [r for r in rows if r["class"] == "ai"]
    print(f"\nprepared {len(rows)} clips -> {STATS.name}; arms: clean, raw_arm, noise_matched, raw_level_random")

    print("\n== 1. NORMALISE FIRST, THEN TRIM: trimming check (removed parts must stay below the silence rule of %.0f dBFS)" % SILENCE_DBFS)
    print("  clips whose removed parts contain a frame at or above the rule:", [r["clip_id"] for r in rows if f(r, "removed_max_frame_dbfs") >= SILENCE_DBFS] or "none")
    print("  clips with no active frame (left untrimmed):", [r["clip_id"] for r in rows if int(r["trim_no_active_frames"]) == 1] or "none")
    for name, rs in (("REAL", real), ("AI", ai)):
        lead, trail = max(rs, key=lambda r: f(r, "trim_lead_s")), max(rs, key=lambda r: f(r, "trim_trail_s"))
        tot, en = max(rs, key=lambda r: f(r, "trim_total_s")), max(rs, key=lambda r: f(r, "removed_energy_fraction"))
        print(f"  {name:4s}: largest leading trim {lead['trim_lead_s']} s ({lead['clip_id']}), trailing {trail['trim_trail_s']} s ({trail['clip_id']}), total {tot['trim_total_s']} s ({tot['clip_id']}); "
              f"loudest removed frame {max(f(r, 'removed_max_frame_dbfs') for r in rs):.1f} dBFS; largest share of energy removed {f(en, 'removed_energy_fraction') * 100:.4f}% ({en['clip_id']}); "
              f"median trimmed {st.median(f(r, 'trim_total_s') for r in rs):.2f} s; clips trimmed by under 0.1 s: {sum(1 for r in rs if f(r, 'trim_total_s') < 0.1)}")
    print("  real clips losing more than 1% of their energy:", [(r["clip_id"], f"{f(r, 'removed_energy_fraction') * 100:.2f}%") for r in real if f(r, "removed_energy_fraction") > 0.01] or "none")
    hm05 = next(r for r in rows if r["clip_id"] == "HM05_real")
    print(f"  HM05_real: {hm05['pre_duration_s']} s -> {hm05['clean_duration_s']} s after trimming (trimmed {hm05['trim_total_s']} s, energy removed {f(hm05, 'removed_energy_fraction') * 100:.3f}%); before D5 it was 0.42 s")
    print("  real clips whose noise floor after gain 1 is at or above the -45 dBFS rule (their silence cannot be trimmed):",
          [(r["clip_id"], r["input_noise_floor_after_gain1_dbfs"]) for r in real if f(r, "input_noise_floor_after_gain1_dbfs") >= SILENCE_DBFS] or "none")
    print("  AI clips, same:", [(r["clip_id"], r["input_noise_floor_after_gain1_dbfs"]) for r in ai if f(r, "input_noise_floor_after_gain1_dbfs") >= SILENCE_DBFS] or "none")

    print("\n== 2. -28 dBFS TARGET: every clip ends at the same RMS?")
    cr = [f(r, "clean_rms_dbfs") for r in rows]
    off = [(r["clip_id"], r["clean_rms_dbfs"]) for r in rows if abs(f(r, "clean_rms_dbfs") - TARGET_RMS_DBFS) > RMS_TOLERANCE_DB]
    print(f"  final clean RMS dBFS min / median / max: {mmm(cr)} | clips outside {TARGET_RMS_DBFS} +- {RMS_TOLERANCE_DB} dB: {off or 'none'}")
    print(f"  peak cap bound on the final clip: {[r['clip_id'] for r in rows if int(r['peak_cap_applied']) == 1] or 'none'} | final peak max {max(f(r, 'clean_peak_dbfs') for r in rows):.2f} dBFS | "
          f"clipped samples {sum(int(r['clean_clipped_samples']) for r in rows)}")
    print(f"  intermediate peak after gain 1 (float, no cap): max {max(f(r, 'intermediate_peak_dbfs') for r in rows):.2f} dBFS; clips above -1 dBFS at that stage: "
          f"{[(r['clip_id'], r['intermediate_peak_dbfs']) for r in rows if f(r, 'intermediate_peak_dbfs') > PEAK_CAP_DBFS] or 'none'}")
    short = [(r["clip_id"], r["clean_duration_s"]) for r in rows if f(r, "clean_duration_s") < SHORT_S]
    print(f"  clips below {SHORT_S:g} s after trimming: {len(short)} of 80 -> {short or 'none'}")
    print(f"  duration after trimming min / median / max (s): real {mmm([f(r, 'clean_duration_s') for r in real])} | AI {mmm([f(r, 'clean_duration_s') for r in ai])}")

    print("\n== 3. NOISE-MATCHED ARM (SIMULATED): noise floor (10th percentile of 20 ms frame levels, dBFS) before and after, min / median / max")
    for sp in ("tuning", "heldout"):
        rr, aa = [r for r in real if r["split"] == sp], [r for r in ai if r["split"] == sp]
        print(f"  split {sp:7s} REAL clean (unchanged)    n={len(rr):2d}  {mmm([f(r, 'clean_noise_floor_dbfs') for r in rr])}")
        print(f"  {'':13s} AI   clean (before)      n={len(aa):2d}  {mmm([f(r, 'clean_noise_floor_dbfs') for r in aa])}")
        print(f"  {'':13s} AI   noise-matched (after) n={len(aa):2d}  {mmm([f(r, 'nm_noise_floor_dbfs') for r in aa])}")
    err = [abs(f(r, "nm_noise_floor_dbfs") - f(r, "nm_target_floor_dbfs")) for r in ai]
    print(f"  measured floor vs the drawn target, absolute error (dB): mean {st.mean(err):.2f}, max {max(err):.2f}; status counts: "
          f"{ {s: sum(1 for r in ai if r['nm_status'] == s) for s in sorted({r['nm_status'] for r in ai})} }; iterations max {max(int(r['nm_iterations']) for r in ai)}")
    print("  noise type: pink Gaussian noise (power ~ 1/f), independent seeded draw per clip, seed %d; noise level added (dBFS RMS) min / median / max: %s" %
          (NOISE_SEED, mmm([f(r, 'nm_noise_level_dbfs') for r in ai if r['nm_noise_level_dbfs']] or [0.0])))
    print(f"  all noise-matched files end at -28 dBFS RMS within {max(abs(f(r, 'nm_rms_dbfs') - TARGET_RMS_DBFS) for r in rows):.3f} dB")

    print("\n== 4. LEVEL-RANDOMIZED RAW ARM (SIMULATED): seeded gain U(%.0f, %.0f) dB on every clip, seed %d" % (*LEVEL_GAIN_RANGE_DB, LEVEL_SEED))
    for name, rs in (("REAL", real), ("AI", ai)):
        g = [f(r, "lr_gain_db") for r in rs]
        rejected = [(r["clip_id"], r["lr_server_decode"], r["lr_whole_clip_rms_dbfs_native"]) for r in rs if r["lr_server_decode"] != "ok"]
        print(f"  {name:4s}: gain dB min/median/max {mmm(g)} | whole-clip RMS after gain {mmm([f(r, 'lr_whole_clip_rms_dbfs_native') for r in rs])} dBFS | rejected by the production server: {len(rejected)} {rejected or ''}")
    print(f"  clipped samples in this arm: {sum(int(r['lr_clipped_samples']) for r in rows)} | loudness (RMS dBFS of the server-converted clip) real {mmm([f(r, 'lr_rms_dbfs') for r in real])} vs AI {mmm([f(r, 'lr_rms_dbfs') for r in ai])}")

    print("\n== 4b. MATCHED RAW ARM (SIMULATED, deviation D6): common loudness U(%.0f, %.0f) dBFS, seed %d; AI clips get matched edge silence and pink noise" % (*MATCH_LEVEL_RANGE_DBFS, MATCH_SEED))
    for name, rs in (("REAL", real), ("AI", ai)):
        rej = [(r["clip_id"], r["mr_server_decode"], r["mr_final_whole_rms_dbfs_native"]) for r in rs if r["mr_server_decode"] != "ok"]
        print(f"  {name:4s}: drawn target RMS {mmm([f(r, 'mr_level_target_dbfs') for r in rs])} | final whole-clip RMS {mmm([f(r, 'mr_final_whole_rms_dbfs_native') for r in rs])} dBFS | "
              f"peak-capped: {sum(int(r['mr_capped']) for r in rs)} | clipped samples {sum(int(r['mr_clipped_samples']) for r in rs)} | REJECTED BY THE PRODUCTION SERVER AS SILENT OR OTHER: {len(rej)} {rej or ''}")
    print(f"  edge silence (normalized domain, s) min / median / max: real lead {mmm([f(r, 'edge_lead_s') for r in real])} | real trail {mmm([f(r, 'edge_trail_s') for r in real])}")
    print(f"      AI own lead {mmm([f(r, 'edge_lead_s') for r in ai])} | AI own trail {mmm([f(r, 'edge_trail_s') for r in ai])}")
    print(f"      AI pad added: lead {mmm([f(r, 'mr_pad_lead_s') for r in ai])} | trail {mmm([f(r, 'mr_pad_trail_s') for r in ai])}")
    print(f"      AI edge silence in the arm (server-converted features): lead {mmm([f(r, 'mr_lead_silence_s') for r in ai])} | trail {mmm([f(r, 'mr_trail_silence_s') for r in ai])}  vs real lead {mmm([f(r, 'mr_lead_silence_s') for r in real])} | trail {mmm([f(r, 'mr_trail_silence_s') for r in real])}")
    print(f"  duration (s): real {mmm([f(r, 'mr_duration_s') for r in real])} | AI {mmm([f(r, 'mr_duration_s') for r in ai])} (AI before padding: {mmm([f(r, 'pre_duration_s') for r in ai])})")
    errs = [abs(f(r, "mr_floor_error_db")) for r in ai if r["mr_floor_error_db"] != ""]
    print(f"  AI statuses: { {s: sum(1 for r in ai if r['mr_status'] == s) for s in sorted({r['mr_status'] for r in ai})} } | floor error vs the drawn target |dB| mean {st.mean(errs):.2f}, max {max(errs):.2f}")
    print(f"  noise floor in the arm (dBFS) real {mmm([f(r, 'mr_noise_floor_dbfs') for r in real])} | AI {mmm([f(r, 'mr_noise_floor_dbfs') for r in ai])}")
    print(f"  loudness as the server sees it (RMS dBFS) real {mmm([f(r, 'mr_rms_dbfs') for r in real])} | AI {mmm([f(r, 'mr_rms_dbfs') for r in ai])}")

    print("\n== 5. RAW ARM (only the sample format changed)")
    print(f"  same frame count as the original: {sum(int(r['raw_frames_equal']) for r in rows)} of 80 | sample rates unchanged: "
          f"{all(int(r['raw_sample_rate']) == int(r['orig_sample_rate']) for r in rows)} | channels all 1: {all(int(r['raw_channels']) == 1 for r in rows)} | "
          f"clipped samples: {sum(int(r['raw_clipped_samples']) for r in rows)} | largest rounding error: {max(f(r, 'raw_max_quant_error') for r in rows):.1e}")

    print("\n== 6. STATISTICS per class and per tool (min / median / max); pre = decoded 16 kHz signal before any gain or trim")
    groups = [("REAL (40)", real), ("AI (40)", ai)] + [(f"AI {t}", [r for r in ai if r["tool"] == t]) for t in ("mms", "vieneu-turbo", "vieneu-nano")]
    for name, rs in groups:
        rates, fmts = {}, {}
        for r in rs:
            rates[int(r["orig_sample_rate"])] = rates.get(int(r["orig_sample_rate"]), 0) + 1
            fmts[f"{r['orig_format']} ({r['orig_bit_depth']}-bit)"] = fmts.get(f"{r['orig_format']} ({r['orig_bit_depth']}-bit)", 0) + 1
        print(f"\n  {name}  (n={len(rs)})  original sample rate {dict(sorted(rates.items()))}  format {fmts}")
        for label, col in (("duration before trimming (s)", "pre_duration_s"), ("leading silence before trim (s)", "pre_lead_silence_s"),
                           ("trailing silence before trim (s)", "pre_trail_silence_s"), ("RMS before normalisation (dBFS)", "pre_rms_dbfs"),
                           ("peak before normalisation (dBFS)", "pre_peak_dbfs"), ("noise floor before (dBFS)", "pre_noise_floor_dbfs"),
                           ("95% roll-off at 16 kHz (Hz)", "pre_rolloff95_hz"), ("95% roll-off at native rate (Hz)", "native_rolloff95_hz"),
                           ("duration after trimming (s)", "clean_duration_s"), ("clean-arm peak (dBFS)", "clean_peak_dbfs"),
                           ("clean-arm noise floor (dBFS)", "clean_noise_floor_dbfs")):
            print(f"    {label:34s} {mmm([f(r, col) for r in rs])}")


def main():
    clips = clip_list()
    for d in (CLEAN, RAW, NOISE, LEVEL, MATCHED):         # rebuild every arm from scratch
        if d.exists():
            shutil.rmtree(d)
    rows = [process(c) for c in clips]
    noise_matched(rows)
    matched_raw(rows, clips)
    cols = []
    for r in rows:
        for k in r:
            if k not in cols:
                cols.append(k)
    with open(STATS, "w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=cols, lineterminator="\n", restval="")
        w.writeheader()
        w.writerows(rows)
    report(rows)


if __name__ == "__main__":
    main()
