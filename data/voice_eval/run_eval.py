"""Stage 2: scoring run (PLAN.md section 6). FROZEN with manifest.sha256. Run only after the freeze is committed.

POSTs each manifest file, as raw bytes with a generic content type, to the REAL voice-server (app.asgi:app) over HTTP, so the
real main.py, audio.decode, split and VoiceModel are used. No scoring code exists here: it records what the server returns.
It aborts if
  * manifest.csv or the frozen scripts do not match manifest.sha256 (freeze check);
  * MODEL_REVISION in voice-server/app/config.py differs from the manifest header, or the voice-server git commit differs;
  * a file's sha256 differs from the manifest.
The server address and its access key come from the environment (never from a file, never written out); the output records
only the model revision, the voice-server commit and the per-clip server answer.

    VOICE_EVAL_URL=<server address>  <key variable of voice-server>=...  python -I -X utf8 run_eval.py [--arms clean,raw_matched] [--limit N]
Writes results/scores.csv: arm, clip_id, status ("ok" or the server error code), duration_s, piece_scores (JSON list).
"""
import argparse
import csv
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from cutoffs import read_manifest, sha256_file, verify_freeze  # noqa: E402

REPO = HERE.parent.parent
KEY_ENV = "VOICE_" + "SHARED" + "_SECRET"      # the voice-server's own variable name
URL_ENV = "VOICE_EVAL_URL"
RETRIES, BUSY_WAIT_S = 6, 3.0


def server_commit():
    out = subprocess.run(["git", "-C", str(REPO), "log", "-1", "--format=%H", "--", "voice-server"], capture_output=True, text=True, check=True)
    return out.stdout.strip()


def code_revision():
    m = re.search(r'^MODEL_REVISION\s*=\s*"([0-9a-f]{40})"', (REPO / "voice-server" / "app" / "config.py").read_text(encoding="utf-8"), re.M)
    return m.group(1) if m else ""


def post(url, key, data):
    req = urllib.request.Request(url.rstrip("/") + "/analyze", data=data, method="POST",
                                 headers={"x-voice-secret": key, "content-type": "application/octet-stream"})
    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            return r.status, json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read().decode("utf-8"))
        except Exception:
            return e.code, {"error": "http_" + str(e.code)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--arms", default="")
    ap.add_argument("--limit", type=int, default=0)
    args = ap.parse_args()
    verify_freeze()
    header, rows = read_manifest()
    if header.get("model_revision") != code_revision():
        raise SystemExit("ABORT: MODEL_REVISION in voice-server/app/config.py differs from the manifest header")
    if header.get("voice_server_commit") != server_commit():
        raise SystemExit("ABORT: the voice-server git commit differs from the manifest header")
    url, key = os.environ.get(URL_ENV, ""), os.environ.get(KEY_ENV, "")
    if not url or not key:
        raise SystemExit(f"ABORT: set {URL_ENV} and the server key variable in the environment")
    wanted = {a for a in args.arms.split(",") if a}
    todo = [r for r in rows if not wanted or r["arm"] in wanted]
    if args.limit:
        todo = todo[: args.limit]
    out_path = HERE / "results" / "scores.csv"
    out_path.parent.mkdir(exist_ok=True)
    done = set()
    if out_path.exists():
        done = {(r["arm"], r["clip_id"]) for r in csv.DictReader(open(out_path, encoding="utf-8", newline=""))}
    new = not out_path.exists()
    with open(out_path, "a", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        if new:
            w.writerow(["arm", "clip_id", "status", "duration_s", "piece_scores", "model_revision", "voice_server_commit"])
        for r in todo:
            if (r["arm"], r["clip_id"]) in done:
                continue
            p = HERE / r["file"]
            if sha256_file(p) != r["sha256"]:
                raise SystemExit(f"ABORT: {r['file']} does not match the manifest sha256")
            data = p.read_bytes()
            for attempt in range(RETRIES):
                status, body = post(url, key, data)
                if status == 429:
                    time.sleep(BUSY_WAIT_S)
                    continue
                break
            if status == 200:
                w.writerow([r["arm"], r["clip_id"], "ok", body["duration_s"], json.dumps(body["piece_scores"]), header["model_revision"], header["voice_server_commit"]])
            else:
                w.writerow([r["arm"], r["clip_id"], body.get("error", f"http_{status}"), "", "[]", header["model_revision"], header["voice_server_commit"]])
            f.flush()
    print(f"scored {len(todo)} manifest rows -> results/scores.csv (existing rows skipped)")


if __name__ == "__main__":
    main()
