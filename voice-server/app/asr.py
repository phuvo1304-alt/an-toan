"""Loads the pinned PhoWhisper speech-to-text model from a local directory (no network)."""
import numpy as np
import torch
from transformers import WhisperForConditionalGeneration, WhisperProcessor

from . import config


class SpeechModel:
    def __init__(self, model_dir: str):
        if config.TORCH_THREADS > 0:
            torch.set_num_threads(config.TORCH_THREADS)
        self.processor = WhisperProcessor.from_pretrained(model_dir, local_files_only=True)
        self.model = WhisperForConditionalGeneration.from_pretrained(model_dir, local_files_only=True)
        self.model.eval()

    def transcribe(self, pieces: list[np.ndarray]) -> str:
        """Vietnamese text for each piece, joined with spaces. Never logged by the caller.
        Whisper-style models can invent words on noise or silence: the text is a best effort,
        not a transcript to rely on."""
        texts = []
        with torch.inference_mode():
            for piece in pieces:
                features = self.processor(
                    piece, sampling_rate=config.SAMPLE_RATE, return_tensors="pt",
                ).input_features
                ids = self.model.generate(
                    features, language="vi", task="transcribe",
                    max_new_tokens=config.ASR_MAX_NEW_TOKENS,
                )
                text = self.processor.batch_decode(ids, skip_special_tokens=True)[0].strip()
                if text:
                    texts.append(text)
        return " ".join(texts)
