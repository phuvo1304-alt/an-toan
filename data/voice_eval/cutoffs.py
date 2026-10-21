"""Stage 2: the pre-registered clip score, cut-offs and labels (PLAN.md sections 6, 7, 8a). FROZEN: no edits after the
manifest is hashed without a logged deviation. Pure functions, numpy only. All results are DESCRIPTIVE, not validation (8a).

Clip score = mean of the piece scores. Cut-offs are computed ONCE, from the 16 + 16 tuning clips of the CLEAN arm (all
tuning AI tools), and applied unchanged to every arm (deviation D8 fixed the direction of the two definitions of PLAN 7):
  t_hum = second-highest tuning REAL clip score;  "Leans human" iff score < t_hum  (at most 1 of 16 tuning AI clips can be below it,
          provided the gap is usable);
  t_ai  = second-lowest tuning AI clip score;     "Leans AI"    iff score > t_ai   (at most 1 of 16 tuning real clips can be above it);
  usable gap iff t_hum <= t_ai; the band [t_hum, t_ai] is "Can't tell". Otherwise (the classes overlap on tuning) all "Can't tell".
A clip under 3 s is "Can't tell". A "Leans" label also needs that no piece sits on the opposite side
(Leans AI: no piece below t_hum; Leans human: no piece above t_ai).
"""
import csv
import hashlib
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
MIN_LABEL_SECONDS = 3.0
LEANS_AI, LEANS_HUMAN, CANT_TELL = "leans_ai", "leans_human", "cant_tell"
BOOT_B = 2000
BOOT_SEED = 20261021
FROZEN_FILES = ["run_eval.py", "analyze.py", "cutoffs.py"]


def clip_score(piece_scores):
    return float(np.mean(piece_scores))


def tuning_cutoffs(real_scores, ai_scores):
    """real_scores / ai_scores: clip scores of the 16 tuning real and 16 tuning AI clips of the clean arm."""
    r = np.sort(np.asarray(real_scores, dtype=float))
    a = np.sort(np.asarray(ai_scores, dtype=float))
    if len(r) < 2 or len(a) < 2:
        raise ValueError("need at least 2 tuning clips per class")
    t_hum, t_ai = float(r[-2]), float(a[1])
    return {"t_ai": t_ai, "t_hum": t_hum, "usable_gap": bool(t_hum <= t_ai)}


def label(pieces, duration_s, cut):
    if not cut["usable_gap"] or duration_s < MIN_LABEL_SECONDS or len(pieces) == 0:
        return CANT_TELL
    s = clip_score(pieces)
    if s > cut["t_ai"] and not any(p < cut["t_hum"] for p in pieces):
        return LEANS_AI
    if s < cut["t_hum"] and not any(p > cut["t_ai"] for p in pieces):
        return LEANS_HUMAN
    return CANT_TELL


def auc(score, y):
    """Mann-Whitney AUC, AI (y=1) positive, ties 0.5."""
    score, y = np.asarray(score, float), np.asarray(y)
    pos, neg = score[y == 1], score[y == 0]
    if len(pos) == 0 or len(neg) == 0:
        return float("nan")
    return float(((pos[:, None] > neg[None, :]).sum() + 0.5 * (pos[:, None] == neg[None, :]).sum()) / (len(pos) * len(neg)))


def auc_ci(score, y):
    """Point AUC and stratified bootstrap 95% interval (2,000 resamples, seed 20261021, percentile)."""
    score, y = np.asarray(score, float), np.asarray(y)
    rng = np.random.default_rng(BOOT_SEED)
    pos, neg = np.where(y == 1)[0], np.where(y == 0)[0]
    boots = [auc(score[i], y[i]) for i in (np.concatenate([rng.choice(pos, len(pos)), rng.choice(neg, len(neg))]) for _ in range(BOOT_B))]
    lo, hi = np.percentile(boots, [2.5, 97.5])
    return auc(score, y), float(lo), float(hi)


def reading(a, lo, hi):
    """PLAN 8a. Every reading keeps the feature OFF; (b) is NOT evidence that the detector hears the voice."""
    if hi < 0.70 or a <= 0.5:
        return "a_credible_negative"
    if lo >= 0.80:
        return "b_high_but_confounded"
    return "c_inconclusive"


def wilson(k, n, z=1.959964):
    if n == 0:
        return (float("nan"), float("nan"))
    p = k / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z * np.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return (float(c - h), float(c + h))


def sha256_file(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def verify_freeze(strict=True):
    """Check manifest.csv and the three frozen scripts against manifest.sha256. Raises SystemExit on any mismatch."""
    listed = {}
    for line in (HERE / "manifest.sha256").read_text(encoding="utf-8").splitlines():
        if line.strip() and not line.startswith("#"):
            h, name = line.split(None, 1)
            listed[name.strip().lstrip("*")] = h
    for name in ["manifest.csv", *FROZEN_FILES]:
        if listed.get(name) != sha256_file(HERE / name):
            raise SystemExit(f"FREEZE VIOLATION: {name} does not match manifest.sha256 (log a deviation first)")
    return listed


def read_manifest(path=None):
    """Returns (header dict from '#key: value' lines, list of row dicts)."""
    path = Path(path or HERE / "manifest.csv")
    header, lines = {}, []
    for ln in path.read_text(encoding="utf-8").splitlines():
        if ln.startswith("#"):
            k, _, v = ln[1:].partition(":")
            header[k.strip()] = v.strip()
        else:
            lines.append(ln)
    return header, list(csv.DictReader(lines))
