"""Run once (at image build time) to bake the pinned weights into ./model."""
import sys

from huggingface_hub import snapshot_download

from app import config

target = sys.argv[1] if len(sys.argv) > 1 else config.MODEL_DIR
path = snapshot_download(
    repo_id=config.MODEL_REPO,
    revision=config.MODEL_REVISION,
    local_dir=target,
    allow_patterns=["config.json", "preprocessor_config.json", "model.safetensors"],
)
print("model downloaded to", path)
