import glob
import os
import tempfile

import numpy as np
import pytest
from fastapi.testclient import TestClient

from app import audio, config
from app.main import _busy, create_app
from conftest import FORMATS

SECRET = os.environ["VOICE_SHARED_SECRET"]


class FakeModel:
    """Test double: returns a fixed score per piece. Used in tests only."""

    def __init__(self):
        self.calls = []

    def fake_scores(self, pieces):
        self.calls.append([len(p) for p in pieces])
        return [0.25 for _ in pieces]


@pytest.fixture
def fake():
    return FakeModel()


@pytest.fixture
def client(fake):
    return TestClient(create_app(model=fake))


def post(client, body, ctype="audio/wav", secret=SECRET, headers=None):
    h = {"content-type": ctype}
    if secret is not None:
        h["x-voice-secret"] = secret
    h.update(headers or {})
    return client.post("/analyze", content=body, headers=h)


def leftover_temp_files():
    return glob.glob(os.path.join(tempfile.gettempdir(), "clip-*"))


# ---- auth / request checks -------------------------------------------------

def test_healthz_needs_no_secret(client):
    assert client.get("/healthz").json() == {"ok": True}


def test_missing_or_wrong_secret_is_401(client, clip):
    data = clip()
    assert post(client, data, secret=None).status_code == 401
    assert post(client, data, secret="wrong-secret-0123456789").status_code == 401
    assert post(client, data, secret=SECRET[:-1]).status_code == 401


def test_server_refuses_to_start_without_secret(monkeypatch):
    monkeypatch.setenv("VOICE_SHARED_SECRET", "short")
    with pytest.raises(RuntimeError):
        create_app(model=FakeModel())


def test_wrong_content_type_is_415_and_body_not_decoded(client, fake):
    r = post(client, b"x" * 100, ctype="application/json")
    assert (r.status_code, r.json()["error"]) == (415, "unsupported_type")
    assert fake.calls == []


def test_oversized_declared_body_is_413(client, monkeypatch):
    monkeypatch.setattr(config, "MAX_BODY_BYTES", 1000)
    r = post(client, b"\0" * 2000)
    assert (r.status_code, r.json()["error"]) == (413, "too_large")


def test_empty_body_is_400(client):
    r = post(client, b"")
    assert r.status_code == 400


def test_busy_returns_429(client, clip):
    assert _busy.acquire(blocking=False)
    try:
        r = post(client, clip())
        assert (r.status_code, r.json()["error"]) == (429, "busy")
    finally:
        _busy.release()


# ---- decoding --------------------------------------------------------------

@pytest.mark.parametrize("fmt", list(FORMATS))
def test_all_supported_formats_decode(client, clip, fmt):
    r = post(client, clip(fmt, 5.0), ctype=FORMATS[fmt][1])
    assert r.status_code == 200, r.text
    body = r.json()
    assert set(body) == {"duration_s", "piece_scores"}
    assert 4.5 < body["duration_s"] < 5.6
    assert len(body["piece_scores"]) == 1


def test_octet_stream_is_accepted(client, clip):
    assert post(client, clip("m4a"), ctype="application/octet-stream").status_code == 200


def test_garbage_is_invalid_audio(client):
    r = post(client, os.urandom(5000))
    assert (r.status_code, r.json()["error"]) == (422, "invalid_audio")


def test_silent_clip_is_rejected(client, clip):
    r = post(client, clip("wav", 5.0, silent=True))
    assert (r.status_code, r.json()["error"]) == (422, "silent")


def test_clip_over_60s_is_too_long(client, clip):
    r = post(client, clip("wav", 70.0))
    assert (r.status_code, r.json()["error"]) == (422, "too_long")


def test_exactly_60s_is_accepted(client, clip):
    r = post(client, clip("wav", 60.0))
    assert r.status_code == 200
    assert len(r.json()["piece_scores"]) == 5


def test_very_short_clip_is_empty(client, clip):
    r = post(client, clip("wav", 0.2))
    assert (r.status_code, r.json()["error"]) == (400, "empty")


def test_playlist_pointing_at_url_is_not_followed(client):
    evil = b"#EXTM3U\n#EXTINF:5,\nhttp://127.0.0.1:9/x.mp3\n"
    r = post(client, evil)
    assert r.status_code == 422


def test_temp_files_are_deleted_on_success_and_failure(client, clip):
    before = set(leftover_temp_files())
    post(client, clip())
    post(client, os.urandom(3000))
    post(client, clip("wav", 5.0, silent=True))
    assert set(leftover_temp_files()) == before


def test_response_has_no_input_echo(client, clip):
    r = post(client, clip(), headers={"x-filename": "secret-name.wav"})
    assert "secret-name" not in r.text


# ---- splitting -------------------------------------------------------------

@pytest.mark.parametrize("seconds,expected", [
    (1, 1), (5, 1), (13, 1), (14, 2), (24, 2), (40, 4), (60, 5),
])
def test_split_piece_counts(seconds, expected):
    samples = np.ones(int(seconds * config.SAMPLE_RATE), dtype=np.float32)
    pieces = audio.split(samples)
    assert len(pieces) == expected
    assert sum(len(p) for p in pieces) == len(samples)
    longest, shortest = max(len(p) for p in pieces), min(len(p) for p in pieces)
    assert longest - shortest <= 1  # even split: no tiny tail piece


def test_40s_clip_reaches_model_as_four_pieces(client, clip, fake):
    r = post(client, clip("wav", 40.0))
    assert r.status_code == 200
    assert len(r.json()["piece_scores"]) == 4
    assert len(fake.calls[-1]) == 4
