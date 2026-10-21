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


def server_samples(data: bytes):
    """Decode with the production server's decoder. Returns (float32 mono 16 kHz samples, seconds).
    Raises the server's own AudioError (silent / empty / too_long / invalid_audio)."""
    _, audio = _load()
    d = audio.decode(data)
    return d.samples, d.duration


def server_samples_unchecked(data: bytes):
    """The production server's ffmpeg conversion (same command, same limits, taken from voice-server/app/config)
    but WITHOUT its silence / length / empty checks. Used only to MEASURE clips the server would reject, so that the
    shortcut check can cover every clip. Returns float32 mono 16 kHz samples."""
    import subprocess
    import tempfile
    import numpy as np
    config, _ = _load()
    fd, path = tempfile.mkstemp(prefix="clip-", suffix=".bin")
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(data)
        cmd = [config.FFMPEG_BIN, "-nostdin", "-hide_banner", "-loglevel", "error", "-protocol_whitelist", "file", "-i", path,
               "-vn", "-sn", "-dn", "-t", str(config.FFMPEG_READ_SECONDS), "-ac", "1", "-ar", str(config.SAMPLE_RATE),
               "-f", "f32le", "pipe:1"]
        out = subprocess.run(cmd, capture_output=True, timeout=config.FFMPEG_TIMEOUT_S, shell=False, check=True).stdout
    finally:
        try:
            os.remove(path)
        except OSError:
            pass
    return np.frombuffer(out[: len(out) - (len(out) % 4)], dtype=np.float32).copy()
