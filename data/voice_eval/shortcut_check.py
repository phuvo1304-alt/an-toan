"""Stage 2 / step 6a: the SHORTCUT CHECK, as defined in PLAN.md section 2 and (since deviation D5) run on four arms.
Does not touch the detector and scores nothing: it asks whether simple properties of the audio (not the voice
itself) already separate the AI clips from the real clips.

Fixed in code before it was run on the D5 arms (see the constants below and PLAN.md section 2):
  * features: the seven listed in FEATURES, measured on the arm's files as the production server converts them
    (prefix in prepare_stats.csv: clean_, nm_, raw_, lr_);
  * classifier: ridge logistic regression (L2 = 1.0), features standardised on the TUNING set, trained on the
    tuning clips (16 real + 16 AI), scored on the HELD-OUT clips (24 real + 24 AI); AI = positive class;
  * an arm is FLAGGED if its held-out AUC is at least 0.75; a flagged GATE arm cannot be used for the ON gate;
  * interval: stratified bootstrap of the held-out clips, 2,000 resamples, seed 20261021, percentile 95%;
  * arms: clean (gate), noise-matched (gate), level-randomized raw (gate), plain raw (descriptive only);
  * also reported, descriptively: the AUC of every single feature (direction chosen on the tuning set).
Reads prepare_stats.csv, writes shortcut_check.json.

    python -I -X utf8 shortcut_check.py        (numpy only)
"""
import csv
import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
FEATURES = ["duration_s", "lead_silence_s", "trail_silence_s", "noise_floor_dbfs", "rms_dbfs", "peak_dbfs", "rolloff95_hz"]
THRESHOLD = 0.75
L2 = 1.0
BOOT_B = 2000
BOOT_SEED = 20261021


def auc(score, y):
    """Mann-Whitney AUC, AI (y=1) positive, ties count 0.5."""
    pos, neg = score[y == 1], score[y == 0]
    if len(pos) == 0 or len(neg) == 0:
        return float("nan")
    gt = (pos[:, None] > neg[None, :]).sum() + 0.5 * (pos[:, None] == neg[None, :]).sum()
    return float(gt / (len(pos) * len(neg)))


def fit_logreg(X, y, l2=L2, iters=100):
    """Ridge logistic regression by Newton's method (intercept not penalised)."""
    Xb = np.c_[np.ones(len(X)), X]
    w = np.zeros(Xb.shape[1])
    R = np.eye(Xb.shape[1]) * l2
    R[0, 0] = 0.0
    for _ in range(iters):
        p = 1.0 / (1.0 + np.exp(-np.clip(Xb @ w, -30, 30)))
        g = Xb.T @ (y - p) - R @ w
        H = Xb.T @ (Xb * (p * (1 - p) + 1e-9)[:, None]) + R
        step = np.linalg.solve(H, g)
        w += step
        if np.max(np.abs(step)) < 1e-9:
            break
    return w


def predict(w, X):
    return np.c_[np.ones(len(X)), X] @ w


def run(rows, prefix):
    X = np.array([[float(r[f"{prefix}_{f}"]) for f in FEATURES] for r in rows])
    y = np.array([1 if r["class"] == "ai" else 0 for r in rows])
    tun = np.array([r["split"] == "tuning" for r in rows])
    mu, sd = X[tun].mean(axis=0), X[tun].std(axis=0)
    sd[sd < 1e-9] = 1.0
    Z = (X - mu) / sd
    w = fit_logreg(Z[tun], y[tun])
    s_te, y_te = predict(w, Z[~tun]), y[~tun]
    a = auc(s_te, y_te)
    rng = np.random.default_rng(BOOT_SEED)
    pos, neg = np.where(y_te == 1)[0], np.where(y_te == 0)[0]
    boots = []
    for _ in range(BOOT_B):
        idx = np.concatenate([rng.choice(pos, len(pos)), rng.choice(neg, len(neg))])
        boots.append(auc(s_te[idx], y_te[idx]))
    lo, hi = np.percentile(boots, [2.5, 97.5])
    single = {}
    for j, f in enumerate(FEATURES):
        a_tun = auc(X[tun][:, j], y[tun])                          # direction chosen on the tuning set
        sign = 1.0 if a_tun >= 0.5 else -1.0
        a_te = auc(sign * X[~tun][:, j], y_te)
        single[f] = {"auc_heldout_direction_from_tuning": round(a_te, 3), "tuning_auc": round(a_tun, 3),
                     "ai_higher": bool(sign > 0),
                     "median_real": round(float(np.median(X[:, j][(y == 0)])), 3), "median_ai": round(float(np.median(X[:, j][(y == 1)])), 3)}
    return {"n_tuning": [int(((y == 0) & tun).sum()), int(((y == 1) & tun).sum())],
            "n_heldout": [int(((y == 0) & ~tun).sum()), int(((y == 1) & ~tun).sum())],
            "heldout_auc": round(a, 3), "ci95": [round(float(lo), 3), round(float(hi), 3)],
            "tuning_auc_in_sample": round(auc(predict(w, Z[tun]), y[tun]), 3),
            "weights_standardised": {f: round(float(w[1 + j]), 3) for j, f in enumerate(FEATURES)},
            "single_feature": single}


def show(name, res, decide):
    print(f"\n=== {name}")
    print(f"  tuning clips (real, AI) {res['n_tuning']} | held-out clips (real, AI) {res['n_heldout']}")
    print(f"  combined classifier: held-out AUC {res['heldout_auc']:.3f}  bootstrap 95% interval [{res['ci95'][0]:.3f}, {res['ci95'][1]:.3f}]  (in-sample tuning AUC {res['tuning_auc_in_sample']:.3f})")
    if decide:
        print(f"  VERDICT (threshold {THRESHOLD}): " + ("CONFOUNDED (AUC >= %.2f): no detector claim may be made" % THRESHOLD if res["heldout_auc"] >= THRESHOLD else "not flagged (AUC below %.2f)" % THRESHOLD))
    print("  single features, held-out AUC (direction from tuning) | tuning AUC | median real -> median AI:")
    for f, s in sorted(res["single_feature"].items(), key=lambda kv: -kv[1]["auc_heldout_direction_from_tuning"]):
        print(f"    {f:18s} {s['auc_heldout_direction_from_tuning']:.3f} | {s['tuning_auc']:.3f} | {s['median_real']:>9} -> {s['median_ai']:>9}  ({'AI higher' if s['ai_higher'] else 'AI lower'})")
    print("  standardised weights: " + ", ".join(f"{f} {v:+.2f}" for f, v in sorted(res["weights_standardised"].items(), key=lambda kv: -abs(kv[1]))))


ARMS = [("clean", "clean", True), ("noise_matched", "nm", True), ("matched_raw", "mr", True),
        ("level_randomized_raw", "lr", False), ("raw", "raw", False)]     # deviation D6: matched raw replaces level-randomized raw as the gate arm


def main():
    rows = list(csv.DictReader(open(HERE / "prepare_stats.csv", encoding="utf-8", newline="")))
    assert len(rows) == 80
    out = {"features": FEATURES, "threshold": THRESHOLD, "l2": L2, "bootstrap": {"resamples": BOOT_B, "seed": BOOT_SEED, "stratified": True}, "arms": {}}
    for name, prefix, gate in ARMS:
        res = run(rows, prefix)
        res["gate_arm"] = gate
        res["flagged"] = bool(res["heldout_auc"] >= THRESHOLD)
        out["arms"][name] = res
        show(f"{name.upper()} ARM ({'GATE arm' if gate else 'descriptive only, not a gate arm'})", res, decide=True)
    gates = {n: a for n, a in out["arms"].items() if a["gate_arm"]}
    out["gate_arms_flagged"] = [n for n, a in gates.items() if a["flagged"]]
    print()
    print("GATE ARMS FLAGGED (held-out AUC >= %.2f): %s" % (THRESHOLD, out["gate_arms_flagged"] or "none"))
    (HERE / "shortcut_check.json").write_text(json.dumps(out, indent=1), encoding="utf-8")
    print("written: shortcut_check.json")


if __name__ == "__main__":
    main()
