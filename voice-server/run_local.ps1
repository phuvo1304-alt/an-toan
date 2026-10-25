# Starts the voice server on this laptop. Reads the secret from .voice-secret (git-ignored); never prints it.
# Run from anywhere:  powershell -File voice-server\run_local.ps1
Set-Location $PSScriptRoot
$secretFile = Join-Path $PSScriptRoot ".voice-secret"
if (-not (Test-Path $secretFile)) { Write-Error "Missing .voice-secret (create it with a long random string)."; exit 1 }
$env:VOICE_SHARED_SECRET = (Get-Content $secretFile -Raw).Trim()
& .venv\Scripts\python -m uvicorn app.asgi:app --host 127.0.0.1 --port 8765 --no-access-log --log-level warning
