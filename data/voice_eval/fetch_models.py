"""Stage 2 / step 3: download ONLY the model files the TTS tools need, by pinned commit.

Run with the Python of the matching isolated environment, in a minimal environment
(no secrets):  <venv>/python -I -X utf8 fetch_models.py <group> [<group> ...]
    groups: turbo nano codec   (run with .venv-vieneu)
            mms                (run with .venv-mms)
    no group + --manifest      write models.sha256 for everything present (hashes only)

Safety rules enforced here, not just promised:
  * every repo is pinned to an exact commit; files are chosen from an explicit list;
  * refuses to run with < 3 GB free, or if the chosen files total > 1.2 GB;
  * refuses any pickle-type file (.bin .pt .pth .pkl .ckpt) and any .py file, so nothing
    that could need trust_remote_code or unpickling is ever fetched;
  * after download, every file's size and hash is checked against the listing of the
    pinned commit (LFS sha256, or the git blob id for small files).
No audio, no FLEURS data. Weights are git-ignored (models/ and .venv*/).
"""
import hashlib
import json
import shutil
import sys
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
MODELS = HERE / "models"
HF_CACHE = MODELS / "hf_cache" / "hub"          # standard HF cache layout (used by the SDK for the codec)
MMS_DIR = HERE / ".venv-mms" / "models" / "mms-tts-vie"
OUT_HASHES = HERE / "models.sha256"

MIN_FREE_BYTES = 3 * 1024**3
MAX_TOTAL_BYTES = int(1.2 * 1024**3)
BANNED_SUFFIXES = (".bin", ".pt", ".pth", ".pkl", ".ckpt", ".py", ".pyc")

GROUPS = {
    "turbo": {
        "repo": "pnnbao-ump/VieNeu-TTS-v3-Turbo",
        "rev": "61b85e3d937fbbacb387714180e8182823512523",
        "dest": MODELS / "vieneu-turbo",
        "files": ["onnx_update/config.json", "onnx_update/tokenizer.json",
                  "onnx_update/vieneu_prefill.onnx", "onnx_update/vieneu_decode_step.onnx",
                  "onnx_update/vieneu_acoustic_cached.onnx", "onnx_update/vieneu_backbone_shared.data",
                  "onnx_update/vieneu_v3_heads.npz"],
    },
    "nano": {
        "repo": "pnnbao-ump/VieNeu-TTS-v3-Nano",
        "rev": "aba295eb96a6fa6003ebe417cc1f2802a7adc1dc",
        "dest": MODELS / "vieneu-nano",
        "files": ["text_encoder.onnx", "duration_predictor.onnx", "vector_estimator.onnx",
                  "codec_decoder.onnx", "config.json", "constants.npz"],
    },
    "codec": {
        # Turbo's CPU path decodes audio with this ONNX codec from a second repo. The SDK's loader
        # insists on fetching the two encoder files too (they are only used for voice cloning, which
        # we never call), so they are included: without them the offline load fails (found 2026-10-21).
        "repo": "OpenMOSS-Team/MOSS-Audio-Tokenizer-Nano-ONNX",
        "rev": "ceff0d0749bfb3fa2d61149794ec6feef0d1e1ae",
        "dest": None,                      # goes into the HF cache so the SDK finds it offline
        "files": ["moss_audio_tokenizer_decode_full.onnx", "moss_audio_tokenizer_decode_shared.data",
                  "moss_audio_tokenizer_decode_step.onnx", "codec_browser_onnx_meta.json",
                  "moss_audio_tokenizer_encode.onnx", "moss_audio_tokenizer_encode.data"],
    },
    "mms": {
        "repo": "facebook/mms-tts-vie",
        "rev": "b58928d033932a49aa8e3d6cf11625b25fe928d2",
        "dest": MMS_DIR,
        # model.safetensors ONLY. pytorch_model.bin (a pickle) is never fetched.
        "files": ["config.json", "tokenizer_config.json", "vocab.json", "special_tokens_map.json",
                  "model.safetensors"],
    },
}


def listing(repo, rev):
    url = f"https://huggingface.co/api/models/{repo}/tree/{rev}?recursive=true"
    with urllib.request.urlopen(url, timeout=60) as r:
        return {x["path"]: x for x in json.load(r) if x["type"] == "file"}


def git_blob_id(path):
    data = path.read_bytes()
    return hashlib.sha1(b"blob %d\0" % len(data) + data).hexdigest()


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def preflight(names):
    free = shutil.disk_usage(HERE).free
    print(f"free disk: {free / 1e9:.1f} GB")
    if free < MIN_FREE_BYTES:
        sys.exit("STOP: under 3 GB free")
    total, plan = 0, {}
    for n in names:
        g = GROUPS[n]
        tree = listing(g["repo"], g["rev"])
        for f in g["files"]:
            if f.lower().endswith(BANNED_SUFFIXES):
                sys.exit(f"STOP: {n}/{f} is a pickle/code-type file")
            if f not in tree:
                sys.exit(f"STOP: {f} not in {g['repo']}@{g['rev'][:10]}")
            total += tree[f]["size"]
        plan[n] = tree
    print(f"selected download: {total / 1e6:.1f} MB for groups {names}")
    if total > MAX_TOTAL_BYTES:
        sys.exit("STOP: selected files exceed 1.2 GB")
    return plan


def fetch(name, tree):
    from huggingface_hub import hf_hub_download
    g = GROUPS[name]
    results = []
    for f in g["files"]:
        if g["dest"] is None:
            HF_CACHE.mkdir(parents=True, exist_ok=True)
            p = Path(hf_hub_download(g["repo"], f, revision=g["rev"], cache_dir=str(HF_CACHE)))
        else:
            g["dest"].mkdir(parents=True, exist_ok=True)
            p = Path(hf_hub_download(g["repo"], f, revision=g["rev"], local_dir=str(g["dest"])))
        entry = tree[f]
        size_ok = p.stat().st_size == entry["size"]
        if entry.get("lfs"):
            digest = sha256_file(p)
            hash_ok, kind = digest == entry["lfs"]["oid"], "sha256 (LFS oid)"
        else:
            hash_ok, kind = git_blob_id(p) == entry["oid"], "git blob id"
        print(f"  {'OK ' if size_ok and hash_ok else 'BAD'} {p.stat().st_size/1e6:9.2f} MB  {kind:17s} {name}/{f}")
        if not (size_ok and hash_ok):
            sys.exit(f"STOP: verification failed for {name}/{f}")
        results.append(f)
    if g["dest"] is None:   # make the pinned commit what 'main' resolves to, for the offline SDK lookup
        repo_dir = HF_CACHE / ("models--" + g["repo"].replace("/", "--"))
        (repo_dir / "refs").mkdir(parents=True, exist_ok=True)
        (repo_dir / "refs" / "main").write_text(g["rev"], encoding="utf-8")
        print(f"  refs/main -> {g['rev'][:10]} (so the SDK resolves the pinned commit offline)")


def write_manifest():
    lines = ["# models.sha256 -- hashes only, no weights. Generated by fetch_models.py (2026-10-21).",
             "# Format: <sha256>  <path relative to data/voice_eval>. Verify with sha256sum -c after cd data/voice_eval."]
    for name, g in GROUPS.items():
        lines.append(f"# {name}: {g['repo']} @ {g['rev']}")
        if g["dest"] is None:
            repo_dir = HF_CACHE / ("models--" + g["repo"].replace("/", "--")) / "snapshots" / g["rev"]
            files = [(repo_dir / f) for f in g["files"]]
        else:
            files = [(g["dest"] / f) for f in g["files"]]
        for p in files:
            if p.exists():
                lines.append(f"{sha256_file(p.resolve())}  {p.relative_to(HERE).as_posix()}")
            else:
                lines.append(f"# MISSING {p.relative_to(HERE).as_posix()}")
    OUT_HASHES.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"wrote {OUT_HASHES.name}: {sum(1 for l in lines if not l.startswith('#'))} files")


def main():
    args = sys.argv[1:]
    if "--manifest" in args:
        return write_manifest()
    names = [a for a in args if a in GROUPS]
    if not names:
        sys.exit("usage: fetch_models.py <turbo|nano|codec|mms> ... | --manifest")
    plan = preflight(names)
    for n in names:
        print(f"== {n}: {GROUPS[n]['repo']} @ {GROUPS[n]['rev']}")
        fetch(n, plan[n])


if __name__ == "__main__":
    main()
