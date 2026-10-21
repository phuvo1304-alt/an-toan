"""Stage 2 / step 3: offline LOAD test (no synthesis) and preset-voice listing.

Run with the Python of the matching isolated environment, in a minimal environment with
HF_HUB_OFFLINE=1 (see fetch_models.py). Sockets are blocked before anything is imported, so
any network attempt fails loudly.

    <venv-vieneu>/python -I -X utf8 check_models.py turbo|nano
    <venv-mms>/python    -I -X utf8 check_models.py mms

Prints one JSON line per model with pass/fail and load time. For turbo/nano it also writes the
SDK's list_preset_voices() output (plus the SDK's own gender label) to voices_<tool>.json next to
this script, to be merged into voices_listed.txt. No audio is generated.
"""
import json
import socket
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent


def _blocked(*a, **k):
    raise RuntimeError("NETWORK ATTEMPT BLOCKED")


socket.socket.connect = _blocked
socket.create_connection = _blocked
socket.getaddrinfo = _blocked


def result(name, ok, seconds, **extra):
    print(json.dumps({"model": name, "load": "PASS" if ok else "FAIL", "load_seconds": round(seconds, 2), **extra},
                     ensure_ascii=False))


def sdk_genders(fn):
    import importlib.util
    pkg = Path(importlib.util.find_spec("vieneu").origin).parent / "assets" / fn
    presets = json.load(open(pkg, encoding="utf-8"))["presets"]
    return {name: e.get("gender") for name, e in presets.items()}


def check_vieneu(tool):
    from vieneu import Vieneu
    t0 = time.perf_counter()
    try:
        if tool == "turbo":
            tts = Vieneu(mode="v3turbo", backend="onnx", precision="fp32",
                         onnx_dir=str(HERE / "models" / "vieneu-turbo" / "onnx_update"))
        else:
            tts = Vieneu(mode="v3nano", onnx_dir=str(HERE / "models" / "vieneu-nano"))
    except Exception as e:                      # report, do not hide
        result(tool, False, time.perf_counter() - t0, error=f"{type(e).__name__}: {str(e)[:300]}")
        return 1
    secs = time.perf_counter() - t0
    listed = [list(x) for x in tts.list_preset_voices()]
    genders = sdk_genders("voices_v3_turbo.json" if tool == "turbo" else "voices_v3_nano.json")
    out = [{"label": a, "id": b, "gender": genders.get(a) or genders.get(b)} for a, b, *_ in listed]
    json.dump({"tool": tool, "backend": getattr(tts, "backend", "onnx"), "voices": out},
              open(HERE / f"voices_{tool}.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    result(tool, True, secs, backend=getattr(tts, "backend", "onnx"), sample_rate=getattr(tts, "sample_rate", None),
           voices_listed=len(out))
    return 0


def check_mms():
    import torch
    from transformers import AutoTokenizer, VitsModel
    d = HERE / ".venv-mms" / "models" / "mms-tts-vie"
    t0 = time.perf_counter()
    try:
        tok = AutoTokenizer.from_pretrained(str(d), local_files_only=True, trust_remote_code=False)
        model = VitsModel.from_pretrained(str(d), use_safetensors=True, local_files_only=True, trust_remote_code=False)
        model.eval()
    except Exception as e:
        result("mms", False, time.perf_counter() - t0, error=f"{type(e).__name__}: {str(e)[:300]}")
        return 1
    secs = time.perf_counter() - t0
    n_params = sum(p.numel() for p in model.parameters())
    result("mms", True, secs, parameters_millions=round(n_params / 1e6, 1), sampling_rate=model.config.sampling_rate,
           num_speakers=model.config.num_speakers, tokenizer=type(tok).__name__, torch=torch.__version__)
    return 0


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else ""
    if which in ("turbo", "nano"):
        sys.exit(check_vieneu(which))
    if which == "mms":
        sys.exit(check_mms())
    sys.exit("usage: check_models.py turbo|nano|mms")
