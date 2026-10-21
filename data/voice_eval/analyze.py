"""Stage 2: analysis of results/scores.csv (PLAN.md sections 7, 8a). FROZEN with manifest.sha256.

EVERYTHING THIS SCRIPT PRINTS IS DESCRIPTIVE, NOT VALIDATION (PLAN 8a). It decides nothing: the feature stays OFF under every
reading; the script only applies the pre-registered reading (a)/(b)/(c) mechanically and lists the arms the trace rule (D7)
excludes. Handling of server rejections is fixed here: a clip the server rejects has no score, is excluded from AUC (its count
is reported), and counts as "Can't tell" in the label tables.

Per ARM and per MODEL GROUP (VieNeu Turbo, VieNeu Nano, both combined = "VieNeu"): held-out AUC of the clip score (AI of the group
vs all held-out real clips) with a stratified bootstrap 95% interval, the reading, and false-positive (real called "Leans AI") /
false-negative (AI called "Leans human") rates and "Can't tell" shares with Wilson 95% intervals, plus a gender breakdown (gender
is confounded with recording batch: male real from FLEURS test, female real from FLEURS train). Tuning numbers are shown only for
transparency and are labelled optimistic. Cut-offs: cutoffs.py (clean arm tuning clips only).

    python -I -X utf8 analyze.py          -> results/metrics.json, results/report.md
"""
import csv
import json
import sys
from collections import defaultdict
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from cutoffs import (CANT_TELL, LEANS_AI, LEANS_HUMAN, auc_ci, clip_score, label, read_manifest, reading,  # noqa: E402
                     tuning_cutoffs, verify_freeze, wilson)

GROUPS = {"VieNeu Turbo": ["vieneu-turbo"], "VieNeu Nano": ["vieneu-nano"], "VieNeu (both)": ["vieneu-turbo", "vieneu-nano"]}
TRACE_FLAG = 0.75


def load_scores(path):
    out = {}
    for r in csv.DictReader(open(path, encoding="utf-8", newline="")):
        out[(r["arm"], r["clip_id"])] = (r["status"], float(r["duration_s"]) if r["duration_s"] else 0.0, json.loads(r["piece_scores"]))
    return out


def rate(k, n):
    lo, hi = wilson(k, n)
    return {"k": int(k), "n": int(n), "rate": round(k / n, 3) if n else None, "wilson95": [round(lo, 3), round(hi, 3)]}


def analyze(rows, scores, trace=None):
    arms = list(dict.fromkeys(r["arm"] for r in rows))
    by = defaultdict(list)
    for r in rows:
        by[r["arm"]].append(r)

    def sc(r):
        s = scores.get((r["arm"], r["clip_id"]))
        return s if s and s[0] == "ok" and s[2] else None

    clean = by["clean"]
    tun_real = [clip_score(sc(r)[2]) for r in clean if r["split"] == "tuning" and r["role"] == "real"]
    tun_ai = [clip_score(sc(r)[2]) for r in clean if r["split"] == "tuning" and r["role"] == "ai"]
    if len(tun_real) != 16 or len(tun_ai) != 16:
        raise SystemExit(f"cut-offs need all 16 + 16 clean-arm tuning clips scored (got {len(tun_real)} + {len(tun_ai)})")
    cut = tuning_cutoffs(tun_real, tun_ai)

    def lab(r):
        s = sc(r)
        return label(s[2], s[1], cut) if s else CANT_TELL

    res = {"descriptive_only": True, "cutoffs_from_clean_arm_tuning": cut, "arms": {}}
    for arm in arms:
        a = {"groups": {}, "tuning_optimistic": {}}
        held = [r for r in by[arm] if r["split"] == "heldout"]
        real = [r for r in held if r["role"] == "real"]
        a["server_rejected"] = {"real": sum(1 for r in by[arm] if r["role"] == "real" and not sc(r)),
                                "ai": sum(1 for r in by[arm] if r["role"] == "ai" and not sc(r))}
        for g, tools in GROUPS.items():
            ai = [r for r in held if r["role"] == "ai" and r["tool"] in tools]
            used = [r for r in real + ai if sc(r)]
            y = np.array([1 if r["role"] == "ai" else 0 for r in used])
            sco = np.array([clip_score(sc(r)[2]) for r in used])
            if (y == 1).sum() and (y == 0).sum():
                p, lo, hi = auc_ci(sco, y)
                gres = {"heldout_auc": round(p, 3), "ci95": [round(lo, 3), round(hi, 3)], "reading": reading(p, lo, hi), "n_scored": [int((y == 0).sum()), int((y == 1).sum())]}
            else:
                gres = {"heldout_auc": None, "reading": "c_inconclusive", "n_scored": [int((y == 0).sum()), int((y == 1).sum())]}
            L = {r["clip_id"]: lab(r) for r in real + ai}
            gres["false_positive_real_leans_ai"] = rate(sum(L[r["clip_id"]] == LEANS_AI for r in real), len(real))
            gres["false_negative_ai_leans_human"] = rate(sum(L[r["clip_id"]] == LEANS_HUMAN for r in ai), len(ai))
            gres["cant_tell_real"] = rate(sum(L[r["clip_id"]] == CANT_TELL for r in real), len(real))
            gres["cant_tell_ai"] = rate(sum(L[r["clip_id"]] == CANT_TELL for r in ai), len(ai))
            gres["cant_tell_all"] = rate(sum(v == CANT_TELL for v in L.values()), len(L))
            gres["by_gender"] = {}
            for gender in ("male", "female"):
                rr, aa = [r for r in real if r["gender"] == gender], [r for r in ai if r["gender"] == gender]
                gres["by_gender"][gender] = {"real_leans_ai": rate(sum(L[r["clip_id"]] == LEANS_AI for r in rr), len(rr)),
                                             "ai_leans_human": rate(sum(L[r["clip_id"]] == LEANS_HUMAN for r in aa), len(aa))}
            a["groups"][g] = gres
        tr = [r for r in by[arm] if r["split"] == "tuning"]
        used = [r for r in tr if sc(r)]
        y = np.array([1 if r["role"] == "ai" else 0 for r in used])
        if (y == 1).sum() and (y == 0).sum():
            p, lo, hi = auc_ci(np.array([clip_score(sc(r)[2]) for r in used]), y)
            a["tuning_optimistic"] = {"auc": round(p, 3), "ci95": [round(lo, 3), round(hi, 3)], "note": "optimistic: cut-offs were chosen on these clips"}
        res["arms"][arm] = a
    if trace:
        res["trace_rule_d7"] = {"threshold": TRACE_FLAG,
                                "direction_free_auc": {k: v["direction_free_auc"] for k, v in trace["arms"].items()},
                                "excluded_arms": [k for k, v in trace["arms"].items() if v["direction_free_auc"] >= TRACE_FLAG]}
    gate = ["clean", "noise_matched", "matched_raw"]
    excl = res.get("trace_rule_d7", {}).get("excluded_arms", [])
    res["on_limited_item2_satisfiable"] = not any(g in excl for g in gate)
    res["feature_state"] = "OFF (every reading in PLAN 8a keeps it OFF; scores are descriptive, not validation)"
    return res


def report(res):
    L = ["# Voice evaluation results (DESCRIPTIVE, NOT VALIDATION)", "",
         f"Cut-offs (clean arm, tuning only): t_ai {res['cutoffs_from_clean_arm_tuning']['t_ai']:.4f}, t_hum {res['cutoffs_from_clean_arm_tuning']['t_hum']:.4f}, usable gap: {res['cutoffs_from_clean_arm_tuning']['usable_gap']}.",
         f"Feature state: {res['feature_state']}.",
         f"Trace rule (D7) excludes: {res.get('trace_rule_d7', {}).get('excluded_arms', 'n/a')}; PLAN 8 item 2 satisfiable: {res['on_limited_item2_satisfiable']}.", "",
         "| Arm | Group | Held-out AUC [95%] | Reading | Real->Leans AI | AI->Leans human | Can't tell (all) | Server-rejected real/AI |", "|---|---|---|---|---|---|---|---|"]
    for arm, a in res["arms"].items():
        for g, r in a["groups"].items():
            ci = f"{r['heldout_auc']} [{r['ci95'][0]}, {r['ci95'][1]}]" if r["heldout_auc"] is not None else "n/a"
            f = lambda x: f"{x['k']}/{x['n']} ({x['wilson95'][0]}-{x['wilson95'][1]})"  # noqa: E731
            L.append(f"| {arm} | {g} | {ci} | {r['reading']} | {f(r['false_positive_real_leans_ai'])} | {f(r['false_negative_ai_leans_human'])} | {f(r['cant_tell_all'])} | {a['server_rejected']['real']}/{a['server_rejected']['ai']} |")
    L += ["", "Tuning AUC per arm (OPTIMISTIC, cut-offs chosen on these clips): " + "; ".join(f"{k} {v['tuning_optimistic'].get('auc')}" for k, v in res["arms"].items()), "",
          "Gender is confounded with recording batch (male real: FLEURS test; female real: FLEURS train). Every number above is descriptive only."]
    return "\n".join(L) + "\n"


def main():
    verify_freeze()
    _, rows = read_manifest()
    scores = load_scores(HERE / "results" / "scores.csv")
    tp = HERE / "trace_feature.json"
    trace = json.loads(tp.read_text(encoding="utf-8")) if tp.exists() else None
    res = analyze(rows, scores, trace)
    out = HERE / "results"
    out.mkdir(exist_ok=True)
    (out / "metrics.json").write_text(json.dumps(res, indent=1), encoding="utf-8")
    (out / "report.md").write_text(report(res), encoding="utf-8")
    print(report(res))


if __name__ == "__main__":
    main()
