"""Bakes the pinned PhoWhisper weights into ./model-asr and checks their sha256 before anything loads them
(the weights are a pickle-format pytorch_model.bin, so an unchecked file must never be loaded)."""
import hashlib
import sys
from pathlib import Path

from huggingface_hub import snapshot_download

from app import config

def verify(target: str, expected_prefix: str = config.ASR_WEIGHTS_SHA256) -> str:
    h = hashlib.sha256()
    with open(Path(target) / "pytorch_model.bin", "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    digest = h.hexdigest()
    if not digest.startswith(expected_prefix):
        raise SystemExit(f"pytorch_model.bin sha256 {digest[:16]} does not match the pinned {expected_prefix}: refusing")
    return digest


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else config.ASR_DIR
    snapshot_download(
        repo_id=config.ASR_REPO, revision=config.ASR_REVISION, local_dir=target,
        allow_patterns=["*.json", "merges.txt", "pytorch_model.bin"],
    )
    print("sha256", verify(target))
