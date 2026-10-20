"""Runs the real pinned model. Skipped when the weights are not downloaded
(run `python download_model.py` first). Checks shape and range only: the
scores are not calibrated, so no test may assert 'real' or 'fake'."""
import os

import pytest
from fastapi.testclient import TestClient

from app import config
from app.main import create_app

MODEL_PRESENT = os.path.exists(os.path.join(config.MODEL_DIR, "model.safetensors"))


@pytest.mark.skipif(not MODEL_PRESENT, reason="model weights not downloaded")
def test_real_model_end_to_end(clip):
    client = TestClient(create_app())  # loads the real model
    r = client.post(
        "/analyze", content=clip("m4a", 30.0),
        headers={"content-type": "audio/mp4", "x-voice-secret": os.environ["VOICE_SHARED_SECRET"]},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert len(body["piece_scores"]) == 3
    assert all(0.0 <= s <= 1.0 for s in body["piece_scores"])
