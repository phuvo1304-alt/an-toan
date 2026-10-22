import hmac
import logging
import os
import threading

from fastapi import FastAPI, Request
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import JSONResponse

from . import audio, config
from .model import VoiceModel

# Never log request bodies, file names, audio or transcripts. Only codes and counts.
log = logging.getLogger("voice-server")

_busy = threading.Lock()  # one analysis at a time per instance


def _load_asr():
    """The speech-to-text model is optional at startup: without its folder the detector still works and
    /transcribe answers 503 (asr_unavailable). Imported lazily so tests need no torch/transformers."""
    if not os.path.exists(os.path.join(config.ASR_DIR, "config.json")):
        log.warning("speech-to-text model folder not found; /transcribe is disabled")
        return None
    from .asr import SpeechModel
    return SpeechModel(config.ASR_DIR)


def create_app(model=None, asr=None) -> FastAPI:
    """`model` and `asr` are injectable so tests can pass fakes; production loads the real ones."""
    secret = config.shared_secret()
    app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)
    state = {"model": model, "asr": asr}

    if model is None:
        state["model"] = VoiceModel(config.MODEL_DIR)  # load at startup, not on first request
        if asr is None:
            state["asr"] = _load_asr()

    def err(code: str, status: int) -> JSONResponse:
        return JSONResponse({"error": code}, status_code=status)

    @app.get("/healthz")
    def healthz():
        return {"ok": True}

    @app.get("/readyz")
    def readyz():
        """No secret, no data: which models are loaded. The Edge Function's health check relies on it."""
        detector, speech = state["model"] is not None, state["asr"] is not None
        return {"ok": detector and speech, "detector": detector, "asr": speech}

    async def handle(request: Request, work):
        # 1. auth first, before touching the body
        given = request.headers.get("x-voice-secret", "")
        if not hmac.compare_digest(given.encode(), secret.encode()):
            return err("unauthorized", 401)

        # 2. type + declared size, before reading the body
        ctype = request.headers.get("content-type", "").split(";")[0].strip().lower()
        if ctype not in config.ALLOWED_CONTENT_TYPES:
            return err("unsupported_type", 415)
        declared = request.headers.get("content-length")
        if declared is None or not declared.isdigit():
            return err("length_required", 411)
        if int(declared) == 0:
            return err("empty", 400)
        if int(declared) > config.MAX_BODY_BYTES:
            return err("too_large", 413)

        if not _busy.acquire(blocking=False):
            return err("busy", 429)
        try:
            # 3. read the body with a hard cap even if the header lied
            chunks, size = [], 0
            async for chunk in request.stream():
                size += len(chunk)
                if size > config.MAX_BODY_BYTES:
                    return err("too_large", 413)
                chunks.append(chunk)
            body = b"".join(chunks)
            del chunks

            try:
                decoded = await run_in_threadpool(audio.decode, body)
                del body
                return await run_in_threadpool(work, decoded)
            except audio.AudioError as e:
                return err(e.code, e.status)
            except Exception:
                log.exception("analyze failed")  # traceback only, no content
                return err("internal", 500)
        finally:
            _busy.release()

    @app.post("/analyze")
    async def analyze(request: Request):
        def work(decoded):
            pieces = audio.split(decoded.samples)
            scores = state["model"].fake_scores(pieces)
            return {
                "duration_s": round(decoded.duration, 2),
                "piece_scores": [round(s, 4) for s in scores],
            }
        return await handle(request, work)

    @app.post("/transcribe")
    async def transcribe(request: Request):
        # Refuse before reading any audio when the model is not loaded (auth still comes first).
        if state["asr"] is not None:
            def work(decoded):
                text = state["asr"].transcribe(audio.split_for_asr(decoded.samples))
                return {"duration_s": round(decoded.duration, 2), "text": text}
            return await handle(request, work)
        given = request.headers.get("x-voice-secret", "")
        if not hmac.compare_digest(given.encode(), secret.encode()):
            return err("unauthorized", 401)
        return err("asr_unavailable", 503)

    return app
