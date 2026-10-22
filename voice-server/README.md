# An Toàn voice model server

Private Python/FastAPI service behind the Supabase Edge Function `analyze-voice`.
The Flutter app never calls it directly. It runs the pinned model
[`garystafford/wav2vec2-deepfake-voice-detector`](https://huggingface.co/garystafford/wav2vec2-deepfake-voice-detector)
(Apache-2.0, revision `c66306024a7ede0be291e9c4558b37634782dc4e`, label 0 = real,
1 = fake, 16 kHz mono, trained on 2.5–13 s clips) and returns **only** per-piece
"fake" scores and the clip duration. It makes no decision: the cut-offs for
"Leans AI / Leans human / Can't tell" live in the Edge Function config and come
from the Vietnamese evaluation. The scores are **not calibrated probabilities**.

## API

`POST /analyze` — raw audio bytes as the body (no multipart).

| Header | Value |
|---|---|
| `x-voice-secret` | the shared secret (compared in constant time, checked before the body is read) |
| `content-type` | an audio type (`audio/mp4`, `audio/mpeg`, `audio/ogg`, `audio/wav`, `audio/flac`, `audio/webm`, `application/octet-stream`, …) |
| `content-length` | required, at most `VOICE_MAX_BODY_BYTES` (default 10 MiB) |

200: `{"duration_s": 40.0, "piece_scores": [0.98, 0.97, ...]}`
Errors are `{"error": "<code>"}`: `unauthorized` 401, `unsupported_type` 415,
`length_required` 411, `too_large` 413, `empty` 400, `invalid_audio` 422,
`silent` 422, `too_long` 422 (over 60 s), `busy` 429 (another request is running),
`internal` 500.

`POST /transcribe` — same request rules as `/analyze` (secret, audio type, size, 60 s, one at a time with
`/analyze`). 200: `{"duration_s": 40.0, "text": "..."}`: Vietnamese text from the pinned speech-to-text model
(PhoWhisper-small). `503 asr_unavailable` if the model folder is missing (the detector still works). The text is
never logged. Whisper-style models can invent words on noise or silence; treat the text as a best effort.

`GET /healthz` → `{"ok": true}` (no secret; for the host's health check).
`GET /readyz` → `{"ok": true, "detector": true, "asr": true}` (no secret, no data; `ok` is true only when both models
are loaded; the Edge Function's health check uses it).

## Safety properties

- Fails closed: refuses to start without `VOICE_SHARED_SECRET` (16+ chars).
- Audio is held in memory, plus one temp file named by Python (`clip-*.bin`) that
  is deleted in a `finally` block. Never logged, never stored; logs contain only
  error tracebacks, never request content or file names.
- ffmpeg is run as a fixed argument list (no shell), with `-protocol_whitelist file`
  (cannot follow URLs inside playlist-style files), `-t 61` (never decodes more
  than 61 s) and a 30 s process timeout.
- One analysis per instance at a time; a second request gets `busy` (429).
- Weights are baked into the image; `HF_HUB_OFFLINE=1`, so startup downloads nothing.

## Environment variables (names only)

| Name | Required | Default |
|---|---|---|
| `VOICE_SHARED_SECRET` | **yes** | — (set it as a host secret; same value goes in the Supabase secret `VOICE_SHARED_SECRET`) |
| `VOICE_MODEL_DIR` | no | `model` (`/srv/model` in the image) |
| `VOICE_ASR_DIR` | no | `model-asr` (`/srv/model-asr` in the image) |
| `VOICE_FFMPEG_BIN` | no | `ffmpeg` |
| `VOICE_MAX_BODY_BYTES` | no | 10485760 |
| `VOICE_FFMPEG_TIMEOUT_S` | no | 30 |
| `VOICE_TORCH_THREADS` | no | torch default |

## Run locally (Windows)

```
cd voice-server
python -m venv .venv
.venv\Scripts\python -m pip install -r requirements-dev.txt
.venv\Scripts\python download_model.py          # ~1.2 GB into ./model (git-ignored)
.venv\Scripts\python download_asr.py            # ~0.97 GB into ./model-asr (git-ignored), sha256 checked
winget install Gyan.FFmpeg                       # then set VOICE_FFMPEG_BIN if ffmpeg is not on PATH
$env:VOICE_SHARED_SECRET = "some-long-random-string"
.venv\Scripts\python -m uvicorn app.asgi:app --port 8765
.venv\Scripts\python -m pytest -q
```

## Measured on the dev laptop (CPU only, 2026-10-21)

These come from running the real model locally, not from a container:

- model load / cold start (process launch → `/healthz` ok): about 11–12 s
- first request ≈ 2–3 s for a 6 s clip; warm ≈ 1.6–1.9 s for 6 s clips
- 40 s clip (4 pieces): ≈ 13–14 s warm
- peak memory of the server process while serving a 40 s clip: ≈ 1.8 GB
- an on-host cold start will also include starting the container and pulling the image

## Speech-to-text (added 2026-10-22)

`vinai/PhoWhisper-small` (BSD-3-Clause; 244 M parameters; revision `a86b604c346caf7148c37512eafe783a16420adb`;
`pytorch_model.bin` 967 MB, sha256 `9ec6f07c...6cc6d22cbfded`, a pickle-format file: `download_asr.py` checks the hash
before anything loads it). Published word error rates (PhoWhisper GitHub page, Vietnamese test sets): Common Voice
11.08 %, VIVOS 6.33 %, VLSP 2020 task 1 15.93 %, task 2 32.96 %. Speed and accuracy on this dev laptop are in the
voice scam report (about 0.7 s of CPU per second of audio, indicative only).

## Deploy (host-agnostic; Google Cloud Run is the candidate)

Recommended limits. Check them against the host's current docs/pricing before use:

- **Memory 4 GiB**, 2 vCPU (measured peak is ≈ 1.8 GB; leave headroom).
- **Concurrency 1** (one request per instance) and **max instances 2** (a hard cap on cost and abuse).
- **Min instances 0** (pay nothing when idle; the app already shows "waking up the voice checker, about a minute").
- **Request timeout 120 s** (the Supabase Edge Function limit is 150 s; keep the server's below it).
- Private ingress: require authentication or at least keep the URL secret; the shared secret header is the only app-level gate.
- **Budget alert:** create a monthly budget alert on the host account (e.g. at 50 % / 90 % / 100 % of a small cap you choose) before turning the feature on. The Supabase side rate limit is 10 requests/hour/IP.

Build and run (on a machine with Docker; **not built or run on the dev machine**):

```
docker build -t an-toan-voice .
docker run --rm -p 8080:8080 -e VOICE_SHARED_SECRET=... an-toan-voice
```

## Rollback

Set `VOICE_ENABLED` to anything other than `true` in the Supabase secrets (the Edge
Function then returns `disabled`), and/or scale the host service to zero.

## Credits and licences

Speech-to-text: vinai/PhoWhisper-small (BSD-3-Clause), Le, Nguyen and Nguyen, "PhoWhisper: Automatic Speech Recognition for
Vietnamese" (the authors ask that the paper be cited when the model is used in published results); fine-tuned from OpenAI
Whisper (MIT).


Model: garystafford/wav2vec2-deepfake-voice-detector (Apache-2.0), fine-tuned from
Gustking/wav2vec2-large-xlsr-deepfake-audio-classification (per the model card), on
garystafford/deepfake-audio-detection (CC BY 4.0, per the model card).
