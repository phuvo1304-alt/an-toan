"""Runs the real pinned PhoWhisper model on one real FLEURS recording from the evaluation (local, git-ignored).
Skipped when the weights or that recording are not on this machine. Loose check: most of the reference words must
appear (a sanity test that the model, the language setting and the audio path work, not an accuracy claim)."""
import csv
import os
import re
from pathlib import Path

import pytest

from app import audio, config

ROOT = Path(__file__).resolve().parents[2]
EVAL = ROOT / "data" / "voice_eval"
ASR_PRESENT = os.path.exists(os.path.join(config.ASR_DIR, "pytorch_model.bin"))
CLIP = EVAL / "audio" / "clean" / "T01_real.wav"


@pytest.mark.skipif(not (ASR_PRESENT and CLIP.exists()), reason="speech-to-text weights or the evaluation clip are not on this machine")
def test_real_asr_reads_a_real_vietnamese_clip():
    from app.asr import SpeechModel

    ref = next(r for r in csv.DictReader(open(EVAL / "selection.csv", encoding="utf-8", newline="")) if r["pair_id"] == "T01")["raw_transcription"]
    decoded = audio.decode(CLIP.read_bytes())
    text = SpeechModel(config.ASR_DIR).transcribe(audio.split_for_asr(decoded.samples))
    words = lambda t: re.sub(r"[^\w\s]", " ", t.lower()).split()  # noqa: E731
    ref_words, got = words(ref), set(words(text))
    assert text.strip()
    assert sum(w in got for w in ref_words) / len(ref_words) >= 0.7
