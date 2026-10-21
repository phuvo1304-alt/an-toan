"""Self-test of cutoffs.py / analyze.py on SYNTHETIC numbers (no audio, no model, no score). Run before the freeze:
    python -I -X utf8 test_analysis.py"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np  # noqa: E402

from analyze import analyze  # noqa: E402
from cutoffs import CANT_TELL, LEANS_AI, LEANS_HUMAN, label, reading, tuning_cutoffs, wilson  # noqa: E402

c = tuning_cutoffs([.1, .2, .3, .4, .5, .6, .7, .8], [.2, .3, .9, .95, .96, .97, .98, .99])
assert c["t_hum"] == .7 and c["t_ai"] == .3 and not c["usable_gap"]        # overlapping classes: no usable gap
c = tuning_cutoffs([.01 * i for i in range(16)], [.8 + .01 * i for i in range(16)])
assert c["usable_gap"] and abs(c["t_hum"] - .14) < 1e-9 and abs(c["t_ai"] - .81) < 1e-9
assert label([.9, .95], 5, c) == LEANS_AI and label([.05, .02], 5, c) == LEANS_HUMAN and label([.4, .5], 5, c) == CANT_TELL
assert label([.9, .95], 2.9, c) == CANT_TELL and label([.9, .05], 5, c) == CANT_TELL      # short clip; opposite piece
assert label([.5], 5, c) == CANT_TELL
assert reading(.6, .4, .69) == "a_credible_negative" and reading(.45, .3, .8) == "a_credible_negative"
assert reading(.95, .82, 1.0) == "b_high_but_confounded" and reading(.8, .6, .9) == "c_inconclusive"
lo, hi = wilson(0, 24)
assert lo == 0 and 0.13 < hi < 0.16

rng = np.random.default_rng(1)
rows, scores = [], {}
for arm in ("clean", "raw"):
    n = 0
    for split, nr, tools in (("tuning", 16, ["mms"] * 6 + ["vieneu-turbo"] * 5 + ["vieneu-nano"] * 5), ("heldout", 24, ["vieneu-turbo"] * 12 + ["vieneu-nano"] * 12)):
        for role, tl in (("real", ["fleurs"] * nr), ("ai", tools)):
            for i, tool in enumerate(tl):
                n += 1
                cid = f"c{arm}{n}"
                rows.append({"arm": arm, "clip_id": cid, "role": role, "split": split, "tool": tool, "gender": "male" if i % 2 else "female"})
                m = 0.9 if role == "ai" else 0.1
                scores[(arm, cid)] = ("ok", 6.0, list(np.clip(rng.normal(m, 0.03, 2), 0, 1)))
res = analyze(rows, scores, {"arms": {"clean": {"direction_free_auc": .6}, "raw": {"direction_free_auc": .8}}})
g = res["arms"]["clean"]["groups"]["VieNeu (both)"]
assert g["heldout_auc"] == 1.0 and g["reading"] == "b_high_but_confounded" and res["trace_rule_d7"]["excluded_arms"] == ["raw"]
assert g["false_positive_real_leans_ai"]["k"] == 0 and g["false_negative_ai_leans_human"]["n"] == 24 and res["on_limited_item2_satisfiable"]
print("test_analysis: all checks passed (synthetic numbers only)")
