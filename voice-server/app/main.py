import hmac
import logging
import threading

from fastapi import FastAPI, Request
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import JSONResponse

from . import audio, config
from .model import VoiceModel

# Never log request bodies, file names or audio. Only codes and counts.
log = logging.getLogger("voice-server")

_busy = threading.Lock()  # one analysis at a time per instance


def create_app(model=None) -> FastAPI:
    """`model` is injectable so tests can pass a fake; production loads the real one."""
    secret = config.shared_secret()
    app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)
    state = {"model": model}

    if model is None:
        state["model"] = VoiceModel(config.MODEL_DIR)  # load at startup, not on first request

    def err(code: str, status: int) -> JSONResponse:
        return JSONResponse({"error": code}, status_code=status)

    @app.get("/healthz")
    def healthz():
        return {"ok": True}

    @app.post("/analyze")
    async def analyze(request: Request):
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
                pieces = audio.split(decoded.samples)
                scores = await run_in_threadpool(state["model"].fake_scores, pieces)
            except audio.AudioError as e:
                return err(e.code, e.status)
            except Exception:
                log.exception("analyze failed")  # traceback only, no content
                return err("internal", 500)
            return {
                "duration_s": round(decoded.duration, 2),
                "piece_scores": [round(s, 4) for s in scores],
            }
        finally:
            _busy.release()

    return app
