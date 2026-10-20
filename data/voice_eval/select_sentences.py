"""Stage 2 / step 2: choose the evaluation sentences, real clips and TTS voices.

Rules are fixed in data/voice_eval/PLAN.md (section 1) and were written before any
score existed. This script uses only FLEURS *metadata* (the TSV files: ids, file names,
transcripts, lengths, gender labels). It downloads no audio, generates no speech and
scores nothing. Standard library only; fully deterministic.

    python -I -X utf8 select_sentences.py            # (re)build selection.csv
    python -I -X utf8 select_sentences.py --check    # verify selection.csv against selection.sha256

Every choice is "rank by sha256(seed|...) and take the first N", so nobody (including
the author) can steer it by looking at audio or scores.
"""
import csv
import hashlib
import re
import sys
import unicodedata
import urllib.request
from pathlib import Path

SEED = "20261021"

# FLEURS (google/fleurs, CC BY 4.0), pinned dataset revision read on 2026-10-21.
FLEURS_REVISION = "70bb2e84b976b7e960aa89f1c648e09c59f894dd"
FLEURS_URL = "https://huggingface.co/datasets/google/fleurs/resolve/{rev}/data/vi_vn/{split}.tsv"
TSV_SHA256 = {
    "train": "c714df11001942e0d1b3a00c0928828b30beb2e6331786032f7bf75d8ff88563",
    "dev": "c9bc17cede9765b1c75cb7a608f7066cb6bb6f8245cc75d721a5217a5dffb414",
    "test": "eb744c2be5f677b49c35527d428a4f647294bd0f67abd790c296e91efaaffb93",
}

HERE = Path(__file__).resolve().parent
CACHE = HERE / "cache"
OUT_CSV = HERE / "selection.csv"
OUT_SHA = HERE / "selection.sha256"

SAMPLE_RATE = 16_000
MIN_S, MAX_S, MAX_CHARS = 3.0, 13.0, 200

# Deviation D1 (2026-10-21, logged in CLAUDE.md section 14.5): one general text rule, added
# BEFORE any audio, TTS or score existed. TTS tools read digits, symbols, acronyms and foreign
# names differently from human readers, which would confound real vs AI. A sentence is eligible
# only if its text has Vietnamese letters, spaces and a fixed punctuation whitelist, and EVERY
# word is a phonotactically valid Vietnamese syllable (so "web", "Paris", "GPS", "30", "yen sign"
# all fail). No sentence was judged by listening or picked by hand.
ALLOWED_PUNCT = set(",.;:!?\"'()-–—…“”‘’«»")
TONE_MARKS = {"̀", "́", "̃", "̉", "̣"}   # grave, acute, tilde, hook, dot below
KEEP_MARKS = {"̂", "̆", "̛"}                         # circumflex, breve, horn
ALPHABET = set("abcdđeghiklmnopqrstuvxyăâêôơư")  # no f j w z
_ONSET = r"(?:ngh|ng|nh|ch|gh|gi|kh|ph|qu|th|tr|[bcdđghklmnrstvx])?"
_NUC3 = r"iêu|yêu|oai|oay|oeo|uây|uôi|ươi|ươu|uyê|uyu|uya|uai"
_NUC2 = (r"ai|ao|au|ay|âu|ây|eo|êu|ia|iê|iu|oa|oă|oe|oi|ôi|ơi|ua|uâ|uê|ui"
         r"|uô|uy|ưa|ưi|ươ|ưu|yê|oo")
_NUC1 = r"[aăâeêioôơuưy]"
SYLLABLE = re.compile(rf"^(?P<on>{_ONSET})(?P<nu>{_NUC3}|{_NUC2}|{_NUC1})(?P<co>ch|ng|nh|[cmnpt])?$")
OPEN_NUCLEI = set("ai ao au ay âu ây eo êu ia iu oi ôi ơi ua ui ưa ưi ưu "
                  "iêu yêu oai oay oeo uây uôi ươi ươu uya uai".split())
NEEDS_CODA = {"iê", "uô", "ươ", "yê", "uyê"}
CH_NH_NUCLEI = {"a", "e", "ê", "i", "oa", "oe", "uê", "uy"}

N_TUNING = 16        # male, FLEURS train
N_HELD_MALE = 12     # FLEURS test (all male)
N_HELD_FEMALE = 12   # FLEURS train block, sentences not in tuning

# Voices. Names from the model cards; every name below was also found, with the same
# gender, in the voices_v3_*.json files of vieneu==3.8.3 on 2026-10-21 (that gender is
# the SDK's own label: declared, NOT verified by listening).
SDK_BASIS = "declared in vieneu 3.8.3 preset file (not yet verified by listening)"
TURBO_TUNING = [("Thanh Bình", "male"), ("Xuân Vĩnh", "male"),
                ("Quỳnh Anh", "female"), ("Ngọc Trân", "female"), ("Kim Thanh", "female")]
NANO_TUNING = [("Anh Khôi", "male"), ("Minh Quân", "male"), ("Mạnh Dũng", "male"),
               ("Mai Anh", "female"), ("Trúc Ly", "female")]
MMS_TUNING = [("mms-tts-vie", "unknown")]
TURBO_HELD = {"male": ["Minh Đức", "Phạm Tuyên", "Quang Sơn"],
              "female": ["Ngọc Linh", "Đoan Trang", "Thục Đoan"]}
NANO_HELD = {"male": ["Hữu Quân", "Adam", "Đức Trí"],
             "female": ["Ái Hân", "Xuân Tiên", "Mỹ Duyên"]}
TUNING_AI_COUNTS = [("mms", 6), ("vieneu-turbo", 5), ("vieneu-nano", 5)]

COLUMNS = [
    "pair_id", "split", "real_source", "sentence_id", "real_clip_file", "real_gender_fleurs",
    "real_num_samples", "real_duration_s", "ai_tool", "ai_voice", "ai_voice_gender",
    "ai_voice_gender_basis", "owner_reads", "zalo_tts", "text_sha256", "raw_transcription",
]


def h(*parts):
    """Deterministic ranking key: sha256 of 'seed|part|part...'."""
    return hashlib.sha256("|".join((SEED,) + tuple(parts)).encode("utf-8")).hexdigest()


def norm(text):
    text = unicodedata.normalize("NFC", text).lower()
    return " ".join("".join(c if (c.isalnum() or c.isspace()) else " " for c in text).split())


def load_tsv(split):
    CACHE.mkdir(exist_ok=True)
    path = CACHE / f"{split}.tsv"
    if not path.exists():
        url = FLEURS_URL.format(rev=FLEURS_REVISION, split=split)
        print(f"downloading metadata {split}.tsv (transcripts only, no audio)")
        urllib.request.urlretrieve(url, path)
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != TSV_SHA256[split]:
        sys.exit(f"{split}.tsv hash mismatch: {digest} != {TSV_SHA256[split]}")
    with open(path, encoding="utf-8", newline="") as f:
        rows = list(csv.reader(f, delimiter="\t", quoting=csv.QUOTE_NONE))
    out = []
    for r in rows:
        assert len(r) == 7, f"unexpected column count in {split}.tsv"
        sid, fname, raw, _norm, _tok, nsamp, gender = r
        out.append({"id": sid, "file": fname, "raw": unicodedata.normalize("NFC", raw),
                    "num_samples": int(nsamp), "gender": gender.lower(), "split": split})
    return out


def _strip_tones(word):
    """Remove tone marks (keeping the vowel-quality marks); None if a mark sits on a non-vowel."""
    out, prev = [], ""
    for ch in unicodedata.normalize("NFD", word.lower()):
        if unicodedata.category(ch) == "Mn":
            if ch in TONE_MARKS:
                if prev not in "aeiouy":
                    return None
                continue
            if ch in KEEP_MARKS:
                out.append(ch)
                continue
            return None            # any other accent (n-tilde, u-umlaut, ...) is not Vietnamese
        out.append(ch)
        prev = ch
    return unicodedata.normalize("NFC", "".join(out))


def syllable_ok(word):
    s = _strip_tones(word)
    if not s or not set(s) <= ALPHABET:
        return False
    m = SYLLABLE.match(s)
    if not m:
        return False
    nu, co = m.group("nu"), m.group("co") or ""
    if nu in OPEN_NUCLEI and co:
        return False
    if nu in NEEDS_CODA and not co:
        return False
    if co in ("ch", "nh") and nu not in CH_NH_NUCLEI:
        return False
    if co == "ng" and nu in ("i", "y", "ơ", "ia"):
        return False
    if co == "c" and nu in ("i", "y", "ê", "ơ"):
        return False
    return True


def text_ok(text):
    """True if the text has only Vietnamese letters, spaces, whitelisted punctuation, and every
    word is a valid Vietnamese syllable (rejects digits, symbols, acronyms, foreign words)."""
    words, cur = [], []
    for ch in unicodedata.normalize("NFC", text):
        if ch.isspace() or ch in ALLOWED_PUNCT:
            words.append("".join(cur))
            cur = []
        elif unicodedata.category(ch)[0] in "LM":
            cur.append(ch)
        else:
            return False           # digit, currency, other symbol, unlisted punctuation
    words.append("".join(cur))
    return all(syllable_ok(w) for w in words if w)


def eligible_basic(row):
    dur = row["num_samples"] / SAMPLE_RATE
    return MIN_S <= dur <= MAX_S and len(row["raw"]) <= MAX_CHARS


def eligible(row):
    return eligible_basic(row) and text_ok(row["raw"])


def by_sentence(rows, gender):
    """sentence id -> eligible clip rows of the given gender."""
    d = {}
    for r in rows:
        if r["gender"] == gender and eligible(r):
            d.setdefault(r["id"], []).append(r)
    return d


def take(candidates, n, exclude=()):
    ids = sorted((i for i in candidates if i not in exclude), key=lambda i: h("sentence", i))
    return ids[:n]


def pick_clip(clips):
    return sorted(clips, key=lambda r: h("clip", r["file"]))[0]


def assign_voices(sentence_ids, voices):
    """Hash-ordered sentences -> hash-ordered voices, cycling (each voice gets equal clips)."""
    sents = sorted(sentence_ids, key=lambda i: h("ai-voice", i))
    vs = sorted(voices, key=lambda v: h("voice", v[0]))
    return {s: vs[k % len(vs)] for k, s in enumerate(sents)}


def build():
    train, dev, test = load_tsv("train"), load_tsv("dev"), load_tsv("test")
    del dev  # kept untouched as a reserve (PLAN.md section 1)
    assert not ({r["id"] for r in train} & {r["id"] for r in test}), "train/test share a sentence id"
    assert not ({norm(r["raw"]) for r in train} & {norm(r["raw"]) for r in test}), "train/test share text"

    train_m, train_f, test_m = by_sentence(train, "male"), by_sentence(train, "female"), by_sentence(test, "male")

    tuning_ids = take(train_m, N_TUNING)
    held_m_ids = take(test_m, N_HELD_MALE)
    held_f_ids = take(train_f, N_HELD_FEMALE, exclude=set(tuning_ids))
    assert (len(tuning_ids), len(held_m_ids), len(held_f_ids)) == (N_TUNING, N_HELD_MALE, N_HELD_FEMALE)

    pairs = []  # dicts, in pair_id order
    for k, sid in enumerate(tuning_ids, 1):
        pairs.append({"pair_id": f"T{k:02d}", "split": "tuning", "real_source": "fleurs_train",
                      "clip": pick_clip(train_m[sid])})
    for k, sid in enumerate(held_m_ids, 1):
        pairs.append({"pair_id": f"HM{k:02d}", "split": "heldout", "real_source": "fleurs_test",
                      "clip": pick_clip(test_m[sid])})
    for k, sid in enumerate(held_f_ids, 1):
        pairs.append({"pair_id": f"HF{k:02d}", "split": "heldout", "real_source": "fleurs_train",
                      "clip": pick_clip(train_f[sid])})
    sid_of = lambda p: p["clip"]["id"]  # noqa: E731
    texts = [norm(p["clip"]["raw"]) for p in pairs]
    assert len(set(map(sid_of, pairs))) == 40 and len(set(texts)) == 40, "sentences must be unique"

    # ---- AI tool + voice per pair --------------------------------------------------
    ai = {}  # sentence id -> (tool, voice, gender, basis)
    t_sents = sorted(tuning_ids, key=lambda i: h("ai-tool", i))
    pos = 0
    for tool, n in TUNING_AI_COUNTS:
        group = t_sents[pos:pos + n]
        pos += n
        voices = {"mms": MMS_TUNING, "vieneu-turbo": TURBO_TUNING, "vieneu-nano": NANO_TUNING}[tool]
        for sid, (name, gender) in assign_voices(group, voices).items():
            ai[sid] = (tool, name, gender, "unknown (single MMS voice)" if tool == "mms" else SDK_BASIS)
    for gender, ids in (("male", held_m_ids), ("female", held_f_ids)):
        s = sorted(ids, key=lambda i: h("ai-tool", i))
        for tool, group, roster in (("vieneu-turbo", s[:6], TURBO_HELD[gender]),
                                    ("vieneu-nano", s[6:], NANO_HELD[gender])):
            for sid, (name, g) in assign_voices(group, [(v, gender) for v in roster]).items():
                ai[sid] = (tool, name, g, SDK_BASIS)

    # ---- Zalo phone-path: owner reads the 12 held-out male-test sentences; 5 TTS files ----
    held_ids = held_m_ids + held_f_ids
    zalo = []
    for tool in ("vieneu-turbo", "vieneu-nano"):
        zalo += sorted((i for i in held_ids if ai[i][0] == tool), key=lambda i: h("zalo", i))[:2]
    zalo += sorted((i for i in held_ids if i not in zalo), key=lambda i: h("zalo", i))[:1]
    assert len(zalo) == 5

    # ---- voice-disjointness between splits (shared Turbo/Nano names count as one) ----
    split_of = lambda sid: "tuning" if sid in tuning_ids else "heldout"  # noqa: E731
    names = {"tuning": set(), "heldout": set()}
    for sid, (tool, name, _g, _b) in ai.items():
        if tool != "mms":
            names[split_of(sid)].add(name)
    assert not (names["tuning"] & names["heldout"]), "a TTS voice name appears in both splits"
    counts = {}
    for sid, (tool, name, *_r) in ai.items():
        counts[(split_of(sid), tool, name)] = counts.get((split_of(sid), tool, name), 0) + 1
    assert all(c == 2 for k, c in counts.items() if k[0] == "heldout"), counts
    assert all(c == 1 for k, c in counts.items() if k[0] == "tuning" and k[1] != "mms"), counts

    rows = []
    for p in pairs:
        c = p["clip"]
        tool, name, gender, basis = ai[c["id"]]
        rows.append({
            "pair_id": p["pair_id"], "split": p["split"], "real_source": p["real_source"],
            "sentence_id": c["id"], "real_clip_file": c["file"], "real_gender_fleurs": c["gender"],
            "real_num_samples": c["num_samples"], "real_duration_s": f"{c['num_samples'] / SAMPLE_RATE:.2f}",
            "ai_tool": tool, "ai_voice": name, "ai_voice_gender": gender, "ai_voice_gender_basis": basis,
            "owner_reads": int(p["pair_id"].startswith("HM")), "zalo_tts": int(c["id"] in zalo),
            "text_sha256": hashlib.sha256(c["raw"].encode("utf-8")).hexdigest(),
            "raw_transcription": c["raw"],
        })
    return rows


def write_csv(rows, path):
    with open(path, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=COLUMNS, lineterminator="\n")
        w.writeheader()
        w.writerows(rows)


def pool_report():
    train, test = load_tsv("train"), load_tsv("test")
    print("eligible sentences (distinct ids with >=1 eligible clip), before -> after the text rule D1:")
    for name, rows_, g in (("train male  ", train, "male"), ("train female", train, "female"), ("test male   ", test, "male")):
        before = {r["id"] for r in rows_ if r["gender"] == g and eligible_basic(r)}
        after = {r["id"] for r in rows_ if r["gender"] == g and eligible(r)}
        print(f"  {name}: {len(before):4d} -> {len(after):4d}")


def summary(rows):
    from collections import Counter
    print("rows:", len(rows))
    print("split x real_source x real gender:",
          dict(Counter((r["split"], r["real_source"], r["real_gender_fleurs"]) for r in rows)))
    print("AI tool x split:", dict(Counter((r["ai_tool"], r["split"]) for r in rows)))
    print("held-out AI tool x voice gender:",
          dict(Counter((r["ai_tool"], r["ai_voice_gender"]) for r in rows if r["split"] == "heldout")))
    print("held-out real gender == AI voice gender for every pair:",
          all(r["real_gender_fleurs"] == r["ai_voice_gender"] for r in rows if r["split"] == "heldout"))
    print("owner_reads:", sum(r["owner_reads"] for r in rows), "| zalo_tts:", sum(r["zalo_tts"] for r in rows))
    durs = [float(r["real_duration_s"]) for r in rows]
    print(f"real clip duration s: min {min(durs):.2f} / max {max(durs):.2f}")


def main():
    rows = build()
    tmp = HERE / "selection.csv.tmp"
    write_csv(rows, tmp)
    digest = hashlib.sha256(tmp.read_bytes()).hexdigest()
    if "--check" in sys.argv:
        recorded = OUT_SHA.read_text(encoding="utf-8").split()[0]
        actual_file = hashlib.sha256(OUT_CSV.read_bytes()).hexdigest()
        tmp.unlink()
        print("regenerated  :", digest)
        print("selection.csv:", actual_file)
        print("recorded     :", recorded)
        ok = digest == actual_file == recorded
        print("CHECK", "OK: identical" if ok else "FAILED")
        sys.exit(0 if ok else 1)
    tmp.replace(OUT_CSV)
    OUT_SHA.write_text(f"{digest}  selection.csv\n", encoding="utf-8", newline="\n")
    summary(rows)
    pool_report()
    print("selection.csv sha256:", digest)


if __name__ == "__main__":
    main()
