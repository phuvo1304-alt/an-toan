"""Re-verify data/scam_case_reference.json: fetch every source_url fresh and check it
still loads at the same URL and still contains the entry's headline, publish date and a
distinctive phrase supporting the summary. Exit code 1 if any entry fails.

Run: python data/verify_sources.py   (standard library only; needs internet)
When adding an entry, add its supporting phrase to PHRASE below."""
import html
import json
import re
import sys
import time
import unicodedata
import urllib.request

DATA = __import__("pathlib").Path(__file__).with_name("scam_case_reference.json")
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126 Safari/537.36"
# A distinctive phrase from each article that supports the summary written for it.
PHRASE = {
    "impersonation-001": "chứng minh vô tội",
    "impersonation-002": "không phân công cán bộ liên hệ trực tiếp",
    "impersonation-003": "mua quà tặng vợ",
    "impersonation-004": "Bước 3 - Khống chế",
    "romance-001": "5% tổng số tiền",
    "romance-002": "gỡ bỏ chế độ an toàn",
    "romance-003": "Liên hợp quốc",
    "loan-001": "sai thông tin",
    "loan-002": "ghép ảnh",
    "fake_scholarship-001": "chuộc người",
    "fake_scholarship-002": "sao kê điện tử chứng minh tài chính",
    "fake_scholarship-003": "danh sách chờ",
    "fake_job-001": "thu nhập nghìn đô",
    "fake_job-002": "chốt đơn hàng",
    "fake_job-003": "Telegram",
    "investment-001": "AJB DIRECT",
    "investment-002": "đánh sóng",
    "investment-003": "báo cáo kiểm toán giả",
    "phishing-001": "Vietnam Post",
    "phishing-002": "dữ liệu sinh trắc học",
    "phishing-003": "xóa nợ xấu CIC",
    "other-001": "Giaohangtietkiem",
    "other-002": "20–40%",
    "other-003": "chuyển nhầm",
}


def norm(s):
    s = unicodedata.normalize("NFC", html.unescape(s))
    s = s.replace("\u00a0", " ").replace("’", "'").replace("‘", "'").replace("“", '"').replace("”", '"')
    return re.sub(r"\s+", " ", s)


def fetch(url):
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept-Language": "vi,en;q=0.8",
                                                       "Cache-Control": "no-cache"})
            r = urllib.request.urlopen(req, timeout=90)
            return r.status, r.geturl(), r.read().decode("utf-8", errors="replace")
        except Exception as e:  # retry slow government servers
            last = e
            time.sleep(3)
    raise last


entries = json.load(open(DATA, encoding="utf-8"))
fails = 0
for e in entries:
    try:
        status, final, doc = fetch(e["source_url"])
    except Exception as ex:
        print(f"FAIL {e['id']}: could not load ({type(ex).__name__})")
        fails += 1
        continue
    text = norm(re.sub(r"<[^>]+>", " ", re.sub(r"<(script|style)[^>]*>.*?</\1>", " ", doc, flags=re.S | re.I)))
    raw = norm(doc)  # some sites keep the article text in an inline JSON blob
    y, m, d = e["published_date"].split("-")
    dates = [e["published_date"], f"{d}/{m}/{y}", f"{int(d)}/{int(m)}/{y}", f"{d}-{m}-{y}"]
    checks = {
        "http200": status == 200,
        "same_url": final.rstrip("/") == e["source_url"].rstrip("/"),
        "headline": norm(e["headline"]) in text or norm(e["headline"]) in raw,
        "date": any(x in raw for x in dates),
        "phrase": norm(PHRASE[e["id"]]).lower() in text.lower() or norm(PHRASE[e["id"]]).lower() in raw.lower(),
    }
    ok = all(checks.values())
    fails += not ok
    bad = [k for k, v in checks.items() if not v]
    print(f"{'OK  ' if ok else 'FAIL'} {e['id']:22} {e['published_date']}  {'' if ok else 'failed: ' + ','.join(bad)}")
print(f"\n{len(entries) - fails}/{len(entries)} passed")
sys.exit(1 if fails else 0)
