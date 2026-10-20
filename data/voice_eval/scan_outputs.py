"""Pre-commit scan: nothing secret or environment-specific may be committed.

Netlify's secret scanner once failed a deploy on committed files, so this runs before every
commit that touches data/voice_eval or voice-server (PLAN.md section 4).

    python -I -X utf8 data/voice_eval/scan_outputs.py            # scan the lines ADDED in the staged diff
    python -I -X utf8 data/voice_eval/scan_outputs.py --files a b # scan whole files

Rejects, in every file: JWT-like tokens, common API-key prefixes, private-key blocks, and any
http(s) URL outside a short allow-list of public source / licence links (so local and private
server addresses are rejected too). Additionally, for files under data/voice_eval/ (data, manifests,
results, notes, scripts) it rejects backend / model-server host names and the names of the
backend-URL, anon-key, shared-secret and AI-key environment variables. Those names are legitimate
in voice-server's own code (it reads its secret from the environment), so the name rule is not
applied there. Matches are shown truncated, never in full.

The forbidden words are assembled from fragments below so that this file does not itself contain
the strings it forbids.
"""
import re
import subprocess
import sys
from pathlib import Path

_B = "supa" + "base"
FORBIDDEN_SUBSTRINGS = [
    _B,                       # backend vendor name (also covers its host names)
    "ANON" + "_KEY",
    "SHARED" + "_SECRET",
    "GEMINI" + "_API",
    "ANTHROPIC" + "_API",
    "service" + "_role",
    ".run" + ".app",          # managed-container host names
]
PATTERNS = {
    "jwt-like token": re.compile(r"eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}"),
    "google-style key": re.compile(r"AIza[0-9A-Za-z_-]{20,}"),
    "sk- style key": re.compile(r"\bsk-[A-Za-z0-9_-]{20,}"),
    "github token": re.compile(r"\bgh[pousr]_[A-Za-z0-9]{20,}"),
    "slack token": re.compile(r"\bxox[abprs]-[A-Za-z0-9-]{10,}"),
    "aws key id": re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    "private key block": re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
}
URL = re.compile(r"https?://[^\s\"'<>)\]\\]+", re.I)
# Matched after removing the scheme. Only public source / licence links.
ALLOWED_URL_PREFIXES = (
    "huggingface.co/datasets/google/fleurs",
    "huggingface.co/pnnbao-ump/",
    "huggingface.co/facebook/mms-tts-vie",
    "huggingface.co/garystafford/",
    "huggingface.co/OpenMOSS-Team/",
    "github.com/pnnbao97/",
    "github.com/facebookresearch/fairseq",
    "creativecommons.org/licenses/",
    "www.apache.org/licenses/",
    "pypi.org/project/",
    "arxiv.org/abs/",
    "download.pytorch.org/whl/cpu",
)
MAX_FILE_BYTES = 2_000_000


def short(s):
    return (s[:6] + "...") if len(s) > 6 else s


NAME_RULE_PREFIX = "data/voice_eval/"


def scan_line(text, path=NAME_RULE_PREFIX):
    """Yield (rule, snippet) for each problem in one line of text."""
    low = text.lower()
    if path.replace("\\", "/").startswith(NAME_RULE_PREFIX):
        for frag in FORBIDDEN_SUBSTRINGS:
            if frag.lower() in low:
                yield "forbidden name/host", short(frag[:4] + "***")
    for rule, rx in PATTERNS.items():
        m = rx.search(text)
        if m:
            yield rule, short(m.group(0))
    for m in URL.finditer(text):
        bare = re.sub(r"^https?://", "", m.group(0), flags=re.I)
        if not bare.startswith(ALLOWED_URL_PREFIXES):
            yield "url not in allow-list", short(bare)


def staged_added_lines():
    out = subprocess.run(["git", "diff", "--cached", "-U0", "--no-color", "--no-ext-diff"],
                         capture_output=True, text=True, encoding="utf-8", errors="replace", check=True).stdout
    path, lineno = None, 0
    for raw in out.splitlines():
        if raw.startswith("+++ "):
            path = raw[6:] if raw.startswith("+++ b/") else None
        elif raw.startswith("@@"):
            m = re.search(r"\+(\d+)", raw)
            lineno = int(m.group(1)) - 1 if m else 0
        elif raw.startswith("+") and not raw.startswith("+++"):
            lineno += 1
            if path:
                yield path, lineno, raw[1:]


def file_lines(paths):
    for p in paths:
        path = Path(p)
        if not path.is_file() or path.stat().st_size > MAX_FILE_BYTES:
            continue
        data = path.read_bytes()
        if b"\0" in data[:4096]:
            continue
        for i, line in enumerate(data.decode("utf-8", errors="replace").splitlines(), 1):
            yield str(p), i, line


def main():
    if "--files" in sys.argv:
        source = file_lines(sys.argv[sys.argv.index("--files") + 1:])
        mode = "whole files"
    else:
        source = staged_added_lines()
        mode = "staged added lines"
    n_lines, findings = 0, []
    for path, lineno, text in source:
        n_lines += 1
        for rule, snippet in scan_line(text, path):
            findings.append(f"{path}:{lineno}: {rule}: {snippet}")
    print(f"scan_outputs: scanned {n_lines} lines ({mode})")
    for f in findings:
        print("  FOUND", f)
    print("scan_outputs:", "FAILED" if findings else "clean")
    sys.exit(1 if findings else 0)


if __name__ == "__main__":
    main()
