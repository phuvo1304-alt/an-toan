"""Loads the pinned wav2vec2 classifier from a local directory (no network)."""
import numpy as np
import torch
from transformers import AutoFeatureExtractor, AutoModelForAudioClassification

from . import config

FAKE_LABEL = 1  # config.json: id2label {0: real, 1: fake}


class VoiceModel:
    def __init__(self, model_dir: str):
        if config.TORCH_THREADS > 0:
            torch.set_num_threads(config.TORCH_THREADS)
        self.extractor = AutoFeatureExtractor.from_pretrained(model_dir, local_files_only=True)
        self.model = AutoModelForAudioClassification.from_pretrained(model_dir, local_files_only=True)
        self.model.eval()
        id2label = {int(k): v for k, v in self.model.config.id2label.items()}
        if id2label.get(FAKE_LABEL) != "fake":
            raise RuntimeError("unexpected label mapping; refusing to start")

    def fake_scores(self, pieces: list[np.ndarray]) -> list[float]:
        """Softmax probability of the 'fake' label for each piece.
        NOT a calibrated probability; callers must not threshold at 0.5."""
        scores = []
        with torch.inference_mode():
            for piece in pieces:
                inputs = self.extractor(
                    piece, sampling_rate=config.SAMPLE_RATE, return_tensors="pt",
                )
                logits = self.model(inputs["input_values"]).logits
                scores.append(float(torch.softmax(logits, dim=-1)[0, FAKE_LABEL]))
        return scores
