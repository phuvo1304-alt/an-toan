"""Stage 2 / step 4b: get the audio of EXACTLY the 40 real clips named in the frozen selection.csv.

FLEURS stores audio in gzip'd tar archives whose members are sorted by file name. A gzip stream
cannot be skipped into, so each archive is streamed from the start and the stream is closed as
soon as the last wanted file has been seen. Nothing but the wanted files is ever written to disk
(no archive is saved, so there is nothing big to delete afterwards).

    <venv>/python -I -X utf8 fetch_fleurs_audio.py             # download + extract + verify
    <venv>/python -I -X utf8 fetch_fleurs_audio.py --verify    # only re-run the checks
    <venv>/python -I -X utf8 fetch_fleurs_audio.py --list audio/d3_wanted.csv
                      # deviation D3: stream the REPLACEMENT CANDIDATES named in the list into audio/fleurs_candidates/

Safety: pinned dataset revision; refuses to start with < 5 GB free; aborts if more than 2.5 GB
would be read; only members named exactly like 'train/<digits>.wav' / 'test/<digits>.wav' that are
in the wanted set are extracted, and they are written to a fixed folder under a name taken from
selection.csv (the member path is never used to build a file path). Standard library plus
soundfile/numpy (for the checks). No TTS, no normalisation, no scoring.
"""
import csv
import hashlib
import re
import shutil
import sys
import time
import unicodedata
import urllib.request
import zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:                      # python -I does not add the script folder
    sys.path.insert(0, str(HERE))
CAND = HERE / "audio" / "fleurs_candidates"
REV = "70bb2e84b976b7e960aa89f1c648e09c59f894dd"        # pinned FLEURS dataset revision (same as select_sentences.py)
URL = "https://huggingface.co/datasets/google/fleurs/resolve/{rev}/data/vi_vn/audio/{split}.tar.gz"
OUT = HERE / "audio" / "fleurs_orig"
RECORD = HERE / "fleurs_originals.csv"
MIN_FREE = 5 * 1024**3
MAX_READ = int(2.5 * 1024**3)
NAME_RE = re.compile(r"^(train|test)/(\d{1,25})\.wav$")


def wanted_by_split():
    rows = list(csv.DictReader(open(HERE / "selection.csv", encoding="utf-8", newline="")))
    out = {"train": {}, "test": {}}
    for r in rows:
        split = r["real_source"].replace("fleurs_", "")
        out[split][r["real_clip_file"]] = r["pair_id"]
    return rows, out


def wanted_from_list(path):
    out = {"train": {}, "test": {}}
    for r in csv.DictReader(open(path, encoding="utf-8", newline="")):
        out[r["fleurs_split"]][r["file"]] = r["slot"]
    return out


def stream_extract(split, wanted, budget, dest=None):
    """Stream <split>.tar.gz, write only the wanted members. Returns (compressed_bytes_read, found, seconds)."""
    req = urllib.request.Request(URL.format(rev=REV, split=split), headers={"User-Agent": "an-toan-eval/1.0"})
    d = zlib.decompressobj(16 + zlib.MAX_WBITS)
    buf, read, found, t0 = bytearray(), 0, set(), time.time()
    next_report = 100 * 1024 * 1024
    with urllib.request.urlopen(req, timeout=60) as resp:
        while True:
            chunk = resp.read(1 << 20)
            if not chunk:
                break
            read += len(chunk)
            if read > budget:
                sys.exit(f"STOP: read {read/1e6:.0f} MB from {split}.tar.gz, over the budget")
            buf += d.decompress(chunk)
            while True:                                      # consume complete tar members from buf
                if len(buf) < 512:
                    break
                hdr = bytes(buf[:512])
                if hdr.strip(b"\0") == b"":
                    return read, found, time.time() - t0
                name = hdr[:100].split(b"\0")[0].decode("utf-8", "replace")
                typeflag = hdr[156:157]
                size = int(hdr[124:136].split(b"\0")[0].strip() or b"0", 8)
                total = 512 + ((size + 511) // 512) * 512
                if len(buf) < total:
                    break
                m = NAME_RE.match(name)
                if m and m.group(1) == split and typeflag in (b"0", b"\0") and (m.group(2) + ".wav") in wanted:
                    fn = m.group(2) + ".wav"
                    target = dest or OUT
                    target.mkdir(parents=True, exist_ok=True)
                    (target / fn).write_bytes(bytes(buf[512:512 + size]))
                    found.add(fn)
                del buf[:total]
                if found == set(wanted):
                    return read, found, time.time() - t0
            if read >= next_report:
                print(f"  {split}: {read/1e6:.0f} MB read, {len(found)}/{len(wanted)} found", flush=True)
                next_report += 100 * 1024 * 1024
    return read, found, time.time() - t0


def sha256_file(p):
    h = hashlib.sha256()
    h.update(p.read_bytes())
    return h.hexdigest()


def tsv_index(split):
    """filename -> (sentence id, gender, num_samples) from the pinned, hash-checked metadata."""
    idx = {}
    for r in csv.reader(open(HERE / "cache" / f"{split}.tsv", encoding="utf-8", newline=""), delimiter="\t", quoting=csv.QUOTE_NONE):
        idx.setdefault(r[1], []).append((r[0], r[6].lower(), int(r[5])))
    return idx


def verify(rows):
    import numpy as np
    import soundfile as sf
    from server_accepts import server_decode
    tsv = {s: tsv_index(s) for s in ("train", "test")}
    out, bad = [], 0
    for r in rows:
        split = r["real_source"].replace("fleurs_", "")
        fn, p = r["real_clip_file"], OUT / r["real_clip_file"]
        rec = {"pair_id": r["pair_id"], "split": r["split"], "fleurs_split": split, "real_clip_file": fn,
               "sentence_id": r["sentence_id"], "gender_selection": r["real_gender_fleurs"]}
        problems = []
        if not p.exists():
            problems.append("file missing")
            rec.update(sha256="", server_decode="", orig_sample_rate="", channels="", subtype="", frames="", duration_s="", rms="", peak="")
        else:
            rec["sha256"] = sha256_file(p)
            ok_srv, code_srv, _ = server_decode(p.read_bytes())          # the production voice server's own decoder
            rec["server_decode"] = "ok" if ok_srv else code_srv
            if not ok_srv: problems.append(f"voice server rejects it: {code_srv}")
            try:
                info = sf.info(str(p)); x, sr = sf.read(str(p), dtype="float64", always_2d=True)
                dur = len(x) / sr
                rec.update(orig_sample_rate=sr, channels=info.channels, subtype=info.subtype, frames=len(x),
                           duration_s=f"{dur:.3f}", rms=f"{float(np.sqrt(np.mean(x**2))):.4f}", peak=f"{float(np.max(np.abs(x))):.3f}")
                if not (3.0 <= dur <= 13.0): problems.append(f"duration {dur:.2f}s outside 3-13 s")
                if not np.all(np.isfinite(x)): problems.append("non-finite samples")
                m = tsv[split].get(fn, [])
                if len(m) != 1: problems.append(f"filename found {len(m)} times in {split}.tsv")
                else:
                    tid, tg, tn = m[0]
                    if tid != r["sentence_id"]: problems.append(f"sentence id {tid} != selection {r['sentence_id']}")
                    if tg != r["real_gender_fleurs"]: problems.append(f"gender {tg} != selection {r['real_gender_fleurs']}")
                    if tn != len(x): problems.append(f"frames {len(x)} != TSV num_samples {tn}")
            except Exception as e:
                problems.append(f"decode failed: {type(e).__name__}")
                rec.update(server_decode=rec.get("server_decode", ""), orig_sample_rate="", channels="", subtype="", frames="", duration_s="", rms="", peak="")
        rec["checks"] = "PASS" if not problems else "FAIL"
        rec["problems"] = "; ".join(problems)
        bad += bool(problems)
        out.append(rec)
    with open(RECORD, "w", encoding="utf-8", newline="") as f:
        cols = ["pair_id", "split", "fleurs_split", "real_clip_file", "sentence_id", "gender_selection", "sha256",
                "server_decode", "orig_sample_rate", "channels", "subtype", "frames", "duration_s", "rms", "peak",
                "checks", "problems"]
        w = csv.DictWriter(f, fieldnames=cols, lineterminator="\n")
        w.writeheader(); w.writerows(out)
    return out, bad


def main():
    if "--list" in sys.argv:                                   # deviation D3: fetch replacement candidates only
        lst = Path(sys.argv[sys.argv.index("--list") + 1])
        wanted = wanted_from_list(lst)
        free = shutil.disk_usage(HERE).free
        print(f"free disk: {free/1e9:.1f} GB")
        if free < MIN_FREE:
            sys.exit("STOP: under 5 GB free")
        total_read = 0
        for split in ("test", "train"):
            todo = {fn for fn in wanted[split] if not (CAND / fn).exists()}
            if not todo:
                continue
            print(f"{split}: streaming for {len(todo)} candidate files ...", flush=True)
            read, found, secs = stream_extract(split, todo, MAX_READ - total_read, dest=CAND)
            total_read += read
            print(f"{split}: DONE read {read/1e6:.0f} MB (compressed) in {secs:.0f} s, found {len(found)}/{len(todo)}", flush=True)
            if todo - found:
                print(f"  NOT FOUND in archive: {sorted(todo - found)}")
        print(f"total compressed bytes read: {total_read/1e6:.0f} MB; candidates on disk: {len(list(CAND.glob('*.wav')))}")
        return
    rows, wanted = wanted_by_split()
    assert sum(len(v) for v in wanted.values()) == 40
    if "--verify" not in sys.argv:
        free = shutil.disk_usage(HERE).free
        print(f"free disk: {free/1e9:.1f} GB")
        if free < MIN_FREE:
            sys.exit("STOP: under 5 GB free")
        total_read, budget = 0, MAX_READ
        for split in ("test", "train"):
            todo = {fn for fn in wanted[split] if not (OUT / fn).exists()}
            if not todo:
                print(f"{split}: all {len(wanted[split])} files already present"); continue
            print(f"{split}: streaming for {len(todo)} files ...", flush=True)
            read, found, secs = stream_extract(split, todo, budget - total_read)
            total_read += read
            print(f"{split}: DONE read {read/1e6:.0f} MB (compressed) in {secs:.0f} s, found {len(found)}/{len(todo)}", flush=True)
            missing = todo - found
            if missing:
                print(f"  NOT FOUND in archive: {sorted(missing)}")
        print(f"total compressed bytes read: {total_read/1e6:.0f} MB")
    out, bad = verify(rows)
    print(f"verified {len(out)} clips: {len(out)-bad} PASS, {bad} FAIL; record written to {RECORD.name}")
    for r in out:
        if r["checks"] == "FAIL":
            print(f"  FAIL {r['pair_id']} {r['real_clip_file']}: {r['problems']}")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
