# Sources used by the voice evaluation (data/voice_eval)

Exact versions, licences and where each was read. Nothing here is shipped in the app. The evaluation audio and all model weights are local only and git-ignored; only hashes are committed. Credits shown to users are listed in `PLAN.md` section 10 and go in `CREDITS.md` and Settings -> About; they name authors and licences only.

Read on 2026-10-21 unless noted. `models.sha256` lists the sha256 of every downloaded model file (24 files).

## Evaluation data (metadata only so far; no audio downloaded yet)

| Source | Pin | Licence | Notes |
|---|---|---|---|
| FLEURS Vietnamese (`google/fleurs`, config `vi_vn`) | dataset revision `70bb2e84b976b7e960aa89f1c648e09c59f894dd` | CC BY 4.0 (dataset card) | `train.tsv` sha256 `c714df11001942e0d1b3a00c0928828b30beb2e6331786032f7bf75d8ff88563`, `dev.tsv` (unused reserve) `c9bc17cede9765b1c75cb7a608f7066cb6bb6f8245cc75d721a5217a5dffb414`, `test.tsv` `eb744c2be5f677b49c35527d428a4f647294bd0f67abd790c296e91efaaffb93`. Credit required. |

## Text-to-speech systems (used offline, to make the AI-voice test clips)

| System | Source and pinned commit | Licence | Files fetched |
|---|---|---|---|
| VieNeu-TTS v3 Turbo | `pnnbao-ump/VieNeu-TTS-v3-Turbo` @ `61b85e3d937fbbacb387714180e8182823512523` | Apache-2.0 (model card) | `onnx_update/`: config.json, tokenizer.json, vieneu_prefill.onnx, vieneu_decode_step.onnx, vieneu_acoustic_cached.onnx, vieneu_backbone_shared.data, vieneu_v3_heads.npz |
| VieNeu-TTS v3 Nano (preview) | `pnnbao-ump/VieNeu-TTS-v3-Nano` @ `aba295eb96a6fa6003ebe417cc1f2802a7adc1dc` | Apache-2.0 (model card) | text_encoder.onnx, duration_predictor.onnx, vector_estimator.onnx, codec_decoder.onnx, config.json, constants.npz |
| **MOSS-Audio-Tokenizer-Nano ONNX codec** (fourth source, used by Turbo on CPU) | `OpenMOSS-Team/MOSS-Audio-Tokenizer-Nano-ONNX` @ **`ceff0d0749bfb3fa2d61149794ec6feef0d1e1ae`** (repository modified 2026-04-17) | Apache-2.0 (licence field of the model card, read through the Hugging Face API; the licence file text itself was not separately read) | moss_audio_tokenizer_decode_full.onnx, moss_audio_tokenizer_decode_shared.data, moss_audio_tokenizer_decode_step.onnx, codec_browser_onnx_meta.json, plus moss_audio_tokenizer_encode.onnx and moss_audio_tokenizer_encode.data (fetched only because the SDK loader requires them; the voice-cloning encoder is never called). **Approved by the owner on 2026-10-21 as a fourth download source.** |
| MMS-TTS-vie (Meta) | `facebook/mms-tts-vie` @ `b58928d033932a49aa8e3d6cf11625b25fe928d2` | CC BY-NC 4.0 (model card; also stated in the official fairseq MMS README) | config.json, tokenizer_config.json, vocab.json, special_tokens_map.json, model.safetensors. `pytorch_model.bin` (a pickle) is never fetched. |

Where the files are: `data/voice_eval/models/` (VieNeu and codec; the codec sits in a Hugging Face cache layout so the SDK finds it offline) and `data/voice_eval/.venv-mms/models/mms-tts-vie/`. **Deleting `.venv-mms` deletes the MMS weights.** Everything is git-ignored and can be re-fetched and re-verified with `fetch_models.py`.

## Software (isolated environments, hash-pinned)

| Package | Pin | Where |
|---|---|---|
| `vieneu` | 3.8.3, sha256 `7388d166e65746f5bb075bf8094d324f8131a82393680b712260d6f2f983ef06` (Apache-2.0) | `requirements-vieneu.lock` (28 packages) |
| `sea-g2p` | 0.9.1, sha256 `b6d7c09afb83750abe61735ad2e60f5c20b4cdfac30b1b9b1904de9f64f10c32`; contains compiled code that could not be read, so it runs only offline, never as administrator, and with no secrets in the environment | `requirements-vieneu.lock` |
| torch (CPU), transformers, safetensors | 2.14.1, 5.20.2, 0.8.0 | `requirements-mms.lock` (35 packages) |

The detector model (`garystafford/wav2vec2-deepfake-voice-detector`, Apache-2.0, revision `c66306024a7ede0be291e9c4558b37634782dc4e`) and its dataset (CC BY 4.0) are recorded in `voice-server/`.
