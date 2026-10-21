"""Stage 2 / step 3: write voices_listed.txt and check PLAN.md section 1 voices against the SDK.

Reads voices_turbo.json / voices_nano.json (written by check_models.py from the SDK's own
list_preset_voices() output, offline, no synthesis), the PLAN.md voice bullets and selection.csv.
Standard library only. Reports; does not replace any voice.
"""
import csv
import json
import re
import sys
import unicodedata
from pathlib import Path

HERE = Path(__file__).resolve().parent
NFC = lambda s: unicodedata.normalize("NFC", s)  # noqa: E731
VI_GENDER = {"Nam": "male", "Nữ": "female"}


def plan_voices():
    """{(split, tool): [(name, gender)]} parsed from the PLAN.md bullets under section 1."""
    out = {}
    for line in (HERE / "PLAN.md").read_text(encoding="utf-8").splitlines():
        m = re.match(r"- \*\*(Tuning|Held-out), (Turbo|Nano):\*\* (.+)$", line)
        if not m:
            continue
        split, tool, rest = m.group(1).lower(), m.group(2).lower(), m.group(3).rstrip(".")
        voices = []
        for seg in rest.split(";"):
            sm = re.match(r"\s*(.+?)\s*\((M|F)\)\s*$", seg)
            names = re.split(r",\s*|\s+and\s+", sm.group(1))
            voices += [(NFC(n.strip()), "male" if sm.group(2) == "M" else "female") for n in names if n.strip()]
        out[(split, tool)] = voices
    return out


def main():
    listed, lines = {}, []
    lines.append("# SDK preset voices, as returned offline by list_preset_voices() (no synthesis). vieneu==3.8.3,")
    lines.append("# pinned model commits in models.sha256. Format: id | SDK gender field | gender word inside the label | full label")
    for tool in ("turbo", "nano"):
        d = json.load(open(HERE / f"voices_{tool}.json", encoding="utf-8"))
        lines.append(f"\n## {tool} ({len(d['voices'])} voices, backend={d['backend']})")
        listed[tool] = {}
        for v in d["voices"]:
            # the gender word is the first word AFTER the dash ("Nữ · Nam · ..." = female, South region)
            gm = re.search(r"—\s*(Nam|Nữ)", NFC(v["label"]))
            vi_word = gm.group(1) if gm else "?"
            listed[tool][NFC(v["id"])] = {"gender": v["gender"], "label_gender": VI_GENDER.get(vi_word, "?")}
            lines.append(f"{v['id']} | {v['gender']} | {VI_GENDER.get(vi_word, '?')} | {v['label']}")

    report = ["\n## Check of PLAN.md section 1 against the SDK"]
    problems = 0
    plan = plan_voices()
    expected_count = sum(len(v) for v in plan.values())
    report.append(f"voices named in PLAN.md section 1: {expected_count} ({', '.join(f'{k[0]}/{k[1]}={len(v)}' for k, v in sorted(plan.items()))})")
    for (split, tool), voices in sorted(plan.items()):
        for name, gender in voices:
            e = listed[tool].get(name)
            if e is None:
                near = [n for n in listed[tool] if NFC(n).casefold() == name.casefold() or name.casefold() in n.casefold()]
                report.append(f"  MISSING   {tool}/{split}: {name!r} not in the SDK list" + (f" (similar: {near})" if near else ""))
                problems += 1
            elif e["gender"] != gender or e["label_gender"] != gender:
                report.append(f"  GENDER    {tool}/{split}: {name!r} plan={gender} sdk={e['gender']} label={e['label_gender']}")
                problems += 1
            else:
                report.append(f"  ok        {tool}/{split}: {name!r} exact spelling, gender {gender} (SDK field and label agree)")

    # selection.csv: every voice used there must be one of the plan voices (exact spelling) and in the SDK list
    rows = list(csv.DictReader(open(HERE / "selection.csv", encoding="utf-8", newline="")))
    plan_names = {(t, n): g for (_s, t), vs in plan.items() for n, g in vs}
    used = {(r["ai_tool"].replace("vieneu-", ""), NFC(r["ai_voice"]), r["ai_voice_gender"]) for r in rows if r["ai_tool"] != "mms"}
    bad = [u for u in used if plan_names.get((u[0], u[1])) != u[2] or u[1] not in listed[u[0]]]
    report.append(f"selection.csv: {len(used)} distinct (tool, voice) pairs in use; pairs not matching PLAN.md/SDK: {bad or 'none'}")
    problems += len(bad)

    # extra voices the SDK has that the plan does not use (information)
    for tool in ("turbo", "nano"):
        unused = sorted(set(listed[tool]) - {n for (t, n) in plan_names if t == tool})
        report.append(f"SDK {tool} voices not used by the plan ({len(unused)}): {', '.join(unused)}")
    report.append(f"\nRESULT: {'all planned voices present with exact spelling and declared gender' if not problems else str(problems) + ' problem(s) above'}")

    (HERE / "voices_listed.txt").write_text("\n".join(lines + report) + "\n", encoding="utf-8", newline="\n")
    print("\n".join(report))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
