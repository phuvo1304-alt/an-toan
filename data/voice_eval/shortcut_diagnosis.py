"""Stage 2 / step 6a: DIAGNOSIS of the shortcut-flagged level-randomized raw arm. INFORMATION ONLY.

It does not change the gate: the gate statistic stays the combined AUC of the seven fixed features
(shortcut_check.py), the threshold stays 0.75, and per PLAN.md section 8 no feature or threshold may be
added, removed or changed to get under 0.75. Nothing is scored; the detector is not touched.

Fixed in code before it was run:
  * arm: level-randomized raw (prefix lr_ in prepare_stats.csv); held-out = 24 real + 24 AI; AI = positive;
  * the same classifier (ridge logistic, L2 = 1.0, standardised on tuning, trained on the 16 + 16 tuning clips) and the
    same stratified bootstrap (2,000 resamples, seed 20261021, percentile 95%) as shortcut_check.py;
  * per-feature AUC with a 95% interval for the seven gate features plus three metadata properties that the production
    server discards when it converts to 16 kHz mono: the ORIGINAL sample rate, the ORIGINAL bit depth (32-bit float for
    all clips) and the arm file's bit depth (16-bit PCM for all clips);
  * combined AUC with 95% intervals for: the 7 gate features (= the gate statistic), the same 7 + the two metadata
    properties (original sample rate and original bit depth), and four ablations that show where the separation lives:
    without the level features (rms, peak), without the silence features (lead, trail), without both,
    and without both and without duration.
    (The ablations are estimates of what a repair of that kind could leave; they are NOT a new gate.)
  * WHAT-IF (an estimate, not a gate): if the AI clips' edge silence were replaced by a real clip's edge silence of the same
    split (a repair that matches silence), their duration would change. For each of 200 seeded draws every AI clip's duration
    becomes  duration - (own leading + trailing silence) + (edge silence of a randomly drawn real clip of the same split),
    where a real clip's edge silence = the part trimmed by the clean arm + 0.4 s of padding. Reported: the single-feature
    AUC of the new duration and the combined AUC of (new duration, noise floor, roll-off), as mean and 5th-95th percentile
    over the draws. Level and silence features are assumed equalised by such a repair; noise floor and roll-off are unchanged.
Reads prepare_stats.csv and shortcut_check.json, writes shortcut_diagnosis.json.

    python -I -X utf8 shortcut_diagnosis.py        (numpy only)
"""
import csv
import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
from shortcut_check import BOOT_B, BOOT_SEED, FEATURES, L2, THRESHOLD, auc, fit_logreg, predict  # noqa: E402

ARM_PREFIX = "lr"
WHAT_IF_DRAWS = 200
PAD_S = 0.4          # the clean arm keeps 0.2 s of padding on each side
META = ["orig_sample_rate_hz", "orig_bit_depth"]
ABLATIONS = {
    "A1 without level features (rms, peak)": ["duration_s", "lead_silence_s", "trail_silence_s", "noise_floor_dbfs", "rolloff95_hz"],
    "A2 without silence features (lead, trail)": ["duration_s", "noise_floor_dbfs", "rms_dbfs", "peak_dbfs", "rolloff95_hz"],
    "A3 without level and silence features": ["duration_s", "noise_floor_dbfs", "rolloff95_hz"],
    "A4 without level, silence and duration": ["noise_floor_dbfs", "rolloff95_hz"],
}


def columns(rows):
    cols = {f: np.array([float(r[f"{ARM_PREFIX}_{f}"]) for r in rows]) for f in FEATURES}
    cols["orig_sample_rate_hz"] = np.array([float(r["orig_sample_rate"]) for r in rows])
    cols["orig_bit_depth"] = np.array([float(r["orig_bit_depth"]) for r in rows])
    cols["arm_bit_depth"] = np.full(len(rows), 16.0)
    return cols


def boot_indices(y_te):
    rng = np.random.default_rng(BOOT_SEED)
    pos, neg = np.where(y_te == 1)[0], np.where(y_te == 0)[0]
    return [np.concatenate([rng.choice(pos, len(pos)), rng.choice(neg, len(neg))]) for _ in range(BOOT_B)]


def interval(score, y, boots):
    v = [auc(score[i], y[i]) for i in boots]
    return [round(float(x), 3) for x in np.percentile(v, [2.5, 97.5])]


def combined(cols, names, y, tun, boots):
    X = np.column_stack([cols[n] for n in names])
    mu, sd = X[tun].mean(axis=0), X[tun].std(axis=0)
    sd[sd < 1e-9] = 1.0
    Z = (X - mu) / sd
    w = fit_logreg(Z[tun], y[tun])
    s = predict(w, Z[~tun])
    return {"features": names, "heldout_auc": round(auc(s, y[~tun]), 3), "ci95": interval(s, y[~tun], boots),
            "in_sample_tuning_auc": round(auc(predict(w, Z[tun]), y[tun]), 3)}


def what_if_duration(rows, cols, y, tun):
    """Estimate of the duration shortcut if the AI clips' edge silence were matched to the real clips'. Information only."""
    def f(r, k):
        return float(r[k])
    real_edge = {sp: np.array([f(r, "trim_total_s") + PAD_S for r in rows if r["class"] == "real" and r["split"] == sp]) for sp in ("tuning", "heldout")}
    ai_idx = [i for i, r in enumerate(rows) if r["class"] == "ai"]
    base = np.array([f(r, "pre_duration_s") - f(r, "pre_lead_silence_s") - f(r, "pre_trail_silence_s") for r in rows])
    singles, combos = [], []
    for d in range(WHAT_IF_DRAWS):
        rng = np.random.default_rng(np.random.SeedSequence([BOOT_SEED, 6, d]))
        dur = np.array([f(r, "pre_duration_s") for r in rows])
        for i in ai_idx:
            dur[i] = base[i] + rng.choice(real_edge[rows[i]["split"]])
        a_tun = auc(dur[tun], y[tun])
        sign = 1.0 if a_tun >= 0.5 else -1.0
        singles.append(auc(sign * dur[~tun], y[~tun]))
        X = np.column_stack([dur, cols["noise_floor_dbfs"], cols["rolloff95_hz"]])
        mu, sd = X[tun].mean(axis=0), X[tun].std(axis=0)
        sd[sd < 1e-9] = 1.0
        Z = (X - mu) / sd
        w = fit_logreg(Z[tun], y[tun])
        combos.append(auc(predict(w, Z[~tun]), y[~tun]))
    q = lambda v: [round(float(x), 3) for x in (np.mean(v), *np.percentile(v, [5, 95]))]  # noqa: E731
    med_old = float(np.median([f(r, "pre_duration_s") for r in rows if r["class"] == "ai"]))
    return {"draws": WHAT_IF_DRAWS, "ai_median_duration_now_s": round(med_old, 2),
            "single_duration_auc_mean_p5_p95": q(singles), "combined_duration_noise_rolloff_auc_mean_p5_p95": q(combos),
            "real_median_edge_silence_s": round(float(np.median(np.concatenate(list(real_edge.values())))), 2),
            "ai_median_own_edge_silence_s": round(float(np.median([f(r, "pre_lead_silence_s") + f(r, "pre_trail_silence_s") for r in rows if r["class"] == "ai"])), 2)}


def main():
    rows = list(csv.DictReader(open(HERE / "prepare_stats.csv", encoding="utf-8", newline="")))
    assert len(rows) == 80
    y = np.array([1 if r["class"] == "ai" else 0 for r in rows])
    tun = np.array([r["split"] == "tuning" for r in rows])
    cols = columns(rows)
    y_te = y[~tun]
    boots = boot_indices(y_te)
    plain_raw = json.load(open(HERE / "shortcut_check.json", encoding="utf-8"))["arms"]["raw"]["single_feature"]

    single = []
    for name in FEATURES + META + ["arm_bit_depth"]:
        a_tun = auc(cols[name][tun], y[tun])
        sign = 1.0 if a_tun >= 0.5 else -1.0
        s = sign * cols[name][~tun]
        a = auc(s, y_te)
        single.append({"feature": name, "kind": "gate feature" if name in FEATURES else "metadata (discarded by the server)",
                       "heldout_auc": round(a, 3), "ci95": interval(s, y_te, boots), "tuning_auc": round(a_tun, 3),
                       "direction": "AI higher" if sign > 0 else "AI lower",
                       "median_real": round(float(np.median(cols[name][y == 0])), 3), "median_ai": round(float(np.median(cols[name][y == 1])), 3),
                       "plain_raw_arm_auc": plain_raw.get(name, {}).get("auc_heldout_direction_from_tuning")})
    single.sort(key=lambda d: -d["heldout_auc"])

    variants = {"V7 the 7 gate features (the gate statistic)": combined(cols, FEATURES, y, tun, boots),
                "V9 the 7 + original sample rate + original bit depth": combined(cols, FEATURES + META, y, tun, boots)}
    for k, names in ABLATIONS.items():
        variants[k] = combined(cols, names, y, tun, boots)

    out = {"arm": "level_randomized_raw", "threshold": THRESHOLD, "l2": L2, "bootstrap": {"resamples": BOOT_B, "seed": BOOT_SEED},
           "per_feature": single, "combined": variants,
           "original_sample_rate_counts": {"real": {int(k): int(v) for k, v in zip(*np.unique(cols["orig_sample_rate_hz"][y == 0], return_counts=True))},
                                            "ai": {int(k): int(v) for k, v in zip(*np.unique(cols["orig_sample_rate_hz"][y == 1], return_counts=True))}},
           "heldout_ai_sample_rates": {int(k): int(v) for k, v in zip(*np.unique(cols["orig_sample_rate_hz"][~tun & (y == 1)], return_counts=True))}}
    out["what_if_edge_silence_matched"] = what_if_duration(rows, cols, y, tun)
    (HERE / "shortcut_diagnosis.json").write_text(json.dumps(out, indent=1), encoding="utf-8")

    print(f"LEVEL-RANDOMIZED RAW ARM, held-out {int(((y == 0) & ~tun).sum())} real + {int(((y == 1) & ~tun).sum())} AI; per-feature AUC (direction from tuning), 95% bootstrap interval, sorted")
    print(f"  {'feature':22s} {'held-out AUC':>12s}  {'95% interval':>16s}  {'tuning':>6s}  {'plain raw':>9s}  median real -> median AI")
    for d in single:
        pr = "" if d["plain_raw_arm_auc"] is None else f"{d['plain_raw_arm_auc']:.3f}"
        print(f"  {d['feature']:22s} {d['heldout_auc']:12.3f}  [{d['ci95'][0]:.3f}, {d['ci95'][1]:.3f}]  {d['tuning_auc']:6.3f}  {pr:>9s}  {d['median_real']} -> {d['median_ai']} ({d['direction']})")
    print(f"\nCOMBINED CLASSIFIER, held-out AUC with 95% interval (threshold {THRESHOLD:.2f}):")
    for k, v in variants.items():
        print(f"  {k:60s} {v['heldout_auc']:.3f}  [{v['ci95'][0]:.3f}, {v['ci95'][1]:.3f}]   (in-sample {v['in_sample_tuning_auc']:.3f})")
    print("\noriginal sample rate counts: real", out["original_sample_rate_counts"]["real"], "| AI", out["original_sample_rate_counts"]["ai"], "| held-out AI", out["heldout_ai_sample_rates"])
    w = out["what_if_edge_silence_matched"]
    print()
    print(f"WHAT-IF (estimate only): AI edge silence replaced by real-like edge silence (real median {w['real_median_edge_silence_s']} s, AI now {w['ai_median_own_edge_silence_s']} s); {w['draws']} seeded draws")
    print(f"  single-feature duration AUC (mean, 5th, 95th percentile): {w['single_duration_auc_mean_p5_p95']}   (now 0.823)")
    print(f"  combined AUC of (new duration, noise floor, roll-off): {w['combined_duration_noise_rolloff_auc_mean_p5_p95']}   (now, with the current duration: 0.769)")
    print("written: shortcut_diagnosis.json")


if __name__ == "__main__":
    main()
