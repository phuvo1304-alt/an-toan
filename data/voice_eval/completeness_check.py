"""Stage 2 / step 5b: completeness check of the AI clips (listening check prepared; NO regeneration here).

RULE, fixed in code before any result was looked at:
  speed = characters of the text passed to the model / clip duration in seconds.
  A clip is FLAGGED if its speed is below 0.6x or above 1.6x of the MEDIAN speed of the clips of the SAME tool.
  HM02 is always included (owner instruction). If more than 10 clips are flagged the script STOPS before copying anything.
  Controls: 4 UNFLAGGED clips chosen at random with a fixed seed (recorded below).
  Only the flagged clips plus the controls are copied, never the key, with opaque shuffled names and identical timestamps,
  to C:\\Users\\phuvo\\Documents\\voice_check2\\ together with sentences.txt (opaque name -> exact sentence text).
  The mapping (opaque name -> clip id, flagged or control, speed) stays in the git-ignored audio/voice_check2_key.csv.

DEFECT criterion, stated in advance: "the audio stops before the sentence ends or skips words".
  Only if the owner reports a defect may that clip be regenerated, ONCE, with a different fixed seed (20261022),
  logged as deviation D4 (reason: defective generation, not taste). A defect in a CONTROL clip means the speed
  rule is not sufficient, and then nothing is regenerated until a better rule is agreed, before any scoring.
Nothing is prepared, normalised, simulated, scored, committed or pushed.

    <venv>/python -I -X utf8 completeness_check.py
"""
import csv
import random
import secrets
import shutil
import statistics as st
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEST = Path(r"C:\Users\phuvo\Documents\voice_check2")
KEY = HERE / "audio" / "voice_check2_key.csv"

LOW, HIGH = 0.6, 1.6                  # flag if speed < LOW x tool median or > HIGH x tool median
ALWAYS = ("HM02",)                    # always included
MAX_FLAGGED = 10                      # more than this: stop and report before copying anything
N_CONTROLS = 4
CONTROL_SEED = 20261021               # random.Random(CONTROL_SEED).sample(sorted unflagged pair ids, 4)


def main():
    rec = list(csv.DictReader(open(HERE / "ai_clips_record.csv", encoding="utf-8", newline="")))
    assert len(rec) == 40
    for r in rec:
        r["chars_per_s"] = len(r["text_passed"]) / float(r["duration_s"])
    med = {t: st.median(r["chars_per_s"] for r in rec if r["tool"] == t) for t in sorted({r["tool"] for r in rec})}
    for r in rec:
        r["ratio"] = r["chars_per_s"] / med[r["tool"]]
        r["by_rule"] = r["ratio"] < LOW or r["ratio"] > HIGH
    flagged = [r for r in rec if r["by_rule"] or r["pair_id"] in ALWAYS]
    print("median speed per tool (chars/s):", {t: round(m, 2) for t, m in med.items()})
    print(f"rule: flag if speed < {LOW}x or > {HIGH}x of the same tool's median; always include {list(ALWAYS)}")
    print(f"flagged by the rule alone: {sum(r['by_rule'] for r in rec)} | flagged in total (with the always-include clips): {len(flagged)}")
    print("ratio to the tool median, all 40: min %.2f max %.2f" % (min(r["ratio"] for r in rec), max(r["ratio"] for r in rec)))
    if len(flagged) > MAX_FLAGGED:
        print(f"STOP: {len(flagged)} clips flagged (more than {MAX_FLAGGED}); nothing copied. Flagged ids: {[r['pair_id'] for r in flagged]}")
        sys.exit(2)
    unflagged = sorted(r["pair_id"] for r in rec if r not in flagged)
    controls = random.Random(CONTROL_SEED).sample(unflagged, N_CONTROLS)
    chosen = [(r, "flagged") for r in flagged] + [(next(x for x in rec if x["pair_id"] == pid), "control") for pid in controls]

    if DEST.exists():
        shutil.rmtree(DEST)
    DEST.mkdir(parents=True)
    order = list(chosen)
    random.SystemRandom().shuffle(order)                       # the order carries no information
    used, key_rows, lines, stamp = set(), [], [], time.time()
    for r, role in order:
        while True:
            name = f"check_{secrets.token_hex(3)}.wav"
            if name not in used:
                used.add(name)
                break
        shutil.copyfile(HERE / r["file"], DEST / name)          # byte-identical copy of the clip
        import os
        os.utime(DEST / name, (stamp, stamp))
        key_rows.append({"filename": name, "pair_id": r["pair_id"], "role": role, "tool": r["tool"], "voice": r["voice"],
                         "chars_per_s": f"{r['chars_per_s']:.2f}", "ratio_to_tool_median": f"{r['ratio']:.2f}",
                         "flagged_by_rule": int(r["by_rule"]), "sha256": r["sha256"]})
        lines.append((name, r["text_passed"]))
    lines.sort()
    with open(KEY, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(key_rows[0]), lineterminator="\n")
        w.writeheader()
        w.writerows(sorted(key_rows, key=lambda k: k["filename"]))
    header = (
        "CHECK 2: did the voice finish the sentence?\n"
        "For each file below, listen to it and read the sentence next to it.\n"
        "DEFECT means: the audio stops before the sentence ends, or it skips words.\n"
        "Odd voice, accent, speed or sound quality is NOT a defect.\n"
        "Reply with one line per file: filename and OK or DEFECT (for a defect, say what is missing).\n"
        "Example:  check_xxxxxx.wav OK\n\n")
    (DEST / "sentences.txt").write_text(header + "\n".join(f"{n}\n    {t}\n" for n, t in lines), encoding="utf-8", newline="\n")
    names = sorted(p.name for p in DEST.iterdir())
    print(f"copied {len(chosen)} clips (never the key) to {DEST}; folder now holds {len(names)} files: {names}")
    print(f"controls chosen with random.Random({CONTROL_SEED}).sample(sorted unflagged ids, {N_CONTROLS}); mapping kept in {KEY.name} (git-ignored, not shown)")


if __name__ == "__main__":
    main()
