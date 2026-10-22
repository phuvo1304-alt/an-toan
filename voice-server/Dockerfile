# NOTE: written and reviewed, but NOT built on the dev machine (no Docker there:
# no hardware virtualization). Build it on the host/CI and check the size.
FROM python:3.13-slim

ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 PIP_NO_CACHE_DIR=1

RUN apt-get update \
 && apt-get install -y --no-install-recommends ffmpeg \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /srv

# CPU-only torch (the default Linux wheel drags in ~2 GB of CUDA libraries).
# requirements.txt pins the same version, so the next line is a no-op for torch.
RUN pip install torch==2.14.1 --index-url https://download.pytorch.org/whl/cpu
COPY requirements.txt .
RUN pip install -r requirements.txt

# Bake the pinned model weights into the image so startup never downloads.
COPY app ./app
COPY download_model.py download_asr.py ./
RUN python download_model.py /srv/model && rm -rf /srv/model/.cache
# Speech-to-text weights (PhoWhisper-small, a pickle-format .bin): download_asr.py refuses to continue unless the
# sha256 matches the pinned value, before anything ever loads the file.
RUN python download_asr.py /srv/model-asr && rm -rf /srv/model-asr/.cache

ENV VOICE_MODEL_DIR=/srv/model VOICE_ASR_DIR=/srv/model-asr HF_HUB_OFFLINE=1 TRANSFORMERS_OFFLINE=1

RUN useradd --system --no-create-home appuser
USER appuser

# VOICE_SHARED_SECRET must be provided by the host at runtime (never in the image).
# Hosts such as Cloud Run set $PORT; default 8080.
EXPOSE 8080
CMD ["sh", "-c", "exec uvicorn app.asgi:app --host 0.0.0.0 --port ${PORT:-8080} --workers 1"]
