"""All tunables in one place. Most can be overridden by env vars, but the model
revision is deliberately a constant: changing the model must be a code change
that shows up in git."""
import os

# Exact commit of garystafford/wav2vec2-deepfake-voice-detector (Apache-2.0),
# looked up on the Hugging Face API on 2026-10-21. Labels: 0 = real, 1 = fake.
MODEL_REPO = "garystafford/wav2vec2-deepfake-voice-detector"
MODEL_REVISION = "c66306024a7ede0be291e9c4558b37634782dc4e"

# Speech-to-text model for the transcription endpoint (BSD-3-Clause). Pinned to an exact commit
# (looked up on the Hugging Face API on 2026-10-22). Weights are a pickle-format pytorch_model.bin:
# download_asr.py checks its sha256 before it is ever loaded.
ASR_REPO = "vinai/PhoWhisper-small"
ASR_REVISION = "a86b604c346caf7148c37512eafe783a16420adb"
ASR_WEIGHTS_SHA256 = "9ec6f07c5bd321fc8f477cf778c43c3fd94b0e33a9f20283fc61cc6d22cbfded"  # sha256 of pytorch_model.bin at the pinned revision (matches the LFS hash on the model page)
ASR_PIECE_SECONDS = 28.0    # Whisper reads 30 s windows; longer clips are split evenly under this
ASR_MAX_NEW_TOKENS = 220    # per piece; a 28 s Vietnamese window is well under this

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
ASR_DIR = os.environ.get("VOICE_ASR_DIR", "model-asr")
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
