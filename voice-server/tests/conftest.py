import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

os.environ.setdefault("VOICE_SHARED_SECRET", "test-secret-0123456789abcdef")


FFMPEG = os.environ.get("VOICE_FFMPEG_BIN") or shutil.which("ffmpeg") or "ffmpeg"
os.environ["VOICE_FFMPEG_BIN"] = FFMPEG

# format name -> (ffmpeg output args, content type)
FORMATS = {
    "wav": (["-c:a", "pcm_s16le", "-f", "wav"], "audio/wav"),
    "m4a": (["-c:a", "aac", "-f", "ipod"], "audio/mp4"),
    "aac": (["-c:a", "aac", "-f", "adts"], "audio/aac"),
    "mp3": (["-c:a", "libmp3lame", "-f", "mp3"], "audio/mpeg"),
    "ogg": (["-c:a", "libopus", "-f", "ogg"], "audio/ogg"),
    "flac": (["-c:a", "flac", "-f", "flac"], "audio/flac"),
    "webm": (["-c:a", "libopus", "-f", "webm"], "audio/webm"),
}


def make_clip(tmp_path: Path, fmt: str, seconds: float, silent: bool = False) -> bytes:
    """Synthesise a speech-like test signal (modulated tones + noise) with ffmpeg.
    It is NOT speech: scores on it mean nothing, it only exercises the pipeline."""
    out_args, _ = FORMATS[fmt]
    if silent:
        src = f"anullsrc=r=16000:cl=mono,atrim=duration={seconds}"
    else:
        src = (
            f"aevalsrc='0.3*sin(2*PI*180*t)*(0.6+0.4*sin(2*PI*3*t))"
            f"+0.15*sin(2*PI*540*t)':s=16000:d={seconds}"
        )
    out = tmp_path / f"clip.{fmt}"
    subprocess.run(
        [FFMPEG, "-y", "-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", src,
         *out_args, str(out)],
        check=True, timeout=60,
    )
    return out.read_bytes()


@pytest.fixture
def clip(tmp_path):
    def _make(fmt="wav", seconds=5.0, silent=False):
        return make_clip(tmp_path, fmt, seconds, silent)
    return _make
