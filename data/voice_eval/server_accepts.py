"""The ONE place that asks the production voice server whether it would accept a clip.

Nothing is copied: the limits (silence RMS, minimum and maximum length) and the decoder come
from voice-server/app itself, so if the server's rules change, this follows them.

    from server_accepts import server_limits, server_decode
    ok, code, seconds = server_decode(open(path, "rb").read())

`code` is "ok" or the server's own error code ("silent", "empty", "too_long", "invalid_audio").
Needs numpy and ffmpeg (set VOICE_FFMPEG_BIN, or have ffmpeg on PATH / installed with winget).
"""
import glob
import os
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SERVER_DIR = HERE.parent.parent / "voice-server"
_mods = None


def _find_ffmpeg():
    if os.environ.get("VOICE_FFMPEG_BIN"):
        return os.environ["VOICE_FFMPEG_BIN"]
    found = shutil.which("ffmpeg")
    if found:
        return found
    local = os.environ.get("LOCALAPPDATA", "")
    hits = glob.glob(os.path.join(local, "Microsoft", "WinGet", "Packages", "Gyan.FFmpeg*", "ffmpeg-*", "bin", "ffmpeg.exe"))
    return hits[0] if hits else "ffmpeg"


def _load():
    global _mods
    if _mods is None:
        os.environ["VOICE_FFMPEG_BIN"] = _find_ffmpeg()     # read by app.config at import time
        sys.path.insert(0, str(SERVER_DIR))
        try:
            from app import audio, config
        finally:
            sys.path.remove(str(SERVER_DIR))
        _mods = (config, audio)
    return _mods


def server_limits():
    config, _ = _load()
    return {"silence_rms": config.SILENCE_RMS, "min_seconds": config.MIN_SECONDS, "max_seconds": config.MAX_SECONDS}


def server_decode(data: bytes):
    """Run the real server decoder. Returns (accepted, code, duration_seconds_or_None)."""
    _, audio = _load()
    try:
        d = audio.decode(data)
        return True, "ok", d.duration
    except audio.AudioError as e:
        return False, e.code, None
