"""All tunables in one place. Most can be overridden by env vars, but the model
revision is deliberately a constant: changing the model must be a code change
that shows up in git."""
import os

# Exact commit of garystafford/wav2vec2-deepfake-voice-detector (Apache-2.0),
# looked up on the Hugging Face API on 2026-10-21. Labels: 0 = real, 1 = fake.
MODEL_REPO = "garystafford/wav2vec2-deepfake-voice-detector"
MODEL_REVISION = "c66306024a7ede0be291e9c4558b37634782dc4e"

SAMPLE_RATE = 16_000
MAX_SECONDS = 60.0          # clips longer than this are rejected (too_long)
FFMPEG_READ_SECONDS = 61    # ffmpeg never decodes more than this
MIN_SECONDS = 0.5           # shorter than this is treated as empty
MAX_PIECE_SECONDS = 13.0    # model was trained on 2.5-13 s; clip is split evenly under this
SILENCE_RMS = 0.002         # RMS (full scale = 1.0) under this = silent


def _int(name: str, default: int) -> int:
    try:
        return int(os.environ.get(name, default))
    except ValueError:
        return default


MAX_BODY_BYTES = _int("VOICE_MAX_BODY_BYTES", 10 * 1024 * 1024)
FFMPEG_TIMEOUT_S = _int("VOICE_FFMPEG_TIMEOUT_S", 30)
FFMPEG_BIN = os.environ.get("VOICE_FFMPEG_BIN", "ffmpeg")
MODEL_DIR = os.environ.get("VOICE_MODEL_DIR", "model")
TORCH_THREADS = _int("VOICE_TORCH_THREADS", 0)  # 0 = torch default

ALLOWED_CONTENT_TYPES = {
    "audio/mp4", "audio/x-m4a", "audio/m4a", "audio/aac", "audio/mpeg",
    "audio/mp3", "audio/ogg", "audio/opus", "audio/wav", "audio/x-wav",
    "audio/wave", "audio/flac", "audio/x-flac", "audio/webm",
    "video/webm",  # some browsers label audio-only webm recordings this way
    "application/octet-stream",
}


def shared_secret() -> str:
    """Required. The server refuses to start without it (fail closed)."""
    secret = os.environ.get("VOICE_SHARED_SECRET", "")
    if len(secret) < 16:
        raise RuntimeError("VOICE_SHARED_SECRET must be set (>= 16 chars)")
    return secret
