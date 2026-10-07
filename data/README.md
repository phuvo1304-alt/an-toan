# Scam case reference dataset

`scam_case_reference.json` holds **24 real, publicly reported Vietnamese scam cases and
official warnings**. Each one is tied to the page it came from, so anyone can open the link
and check the entry against the source.

It is reference material only. **Nothing in the app reads it yet.** Connecting it to
`analyze-scam` (the AI's context) is a separate task that needs its own review.

- Built and verified: **2026-10-07**
- Articles published: **2022-02-08 to 2026-09-04**
- Languages: summaries in Vietnamese and English; red flags in English; sources in Vietnamese

## Format

A single JSON array, UTF-8, pretty-printed. JSON rather than JSONL because the file is small
(24 entries), meant to be read and spot-checked by people, and loaded whole. JSONL would only
pay off if the set grew large or were appended to by a pipeline.

| Field | Meaning |
|---|---|
| `id` | `<scam_type>-NNN`, stable |
| `scam_type` | Same taxonomy as `supabase/functions/analyze-scam/index.ts`, minus `none`: `fake_job`, `fake_scholarship`, `phishing`, `impersonation`, `investment`, `romance`, `loan`, `other` |
| `entry_kind` | `incident_report` (a specific reported case or arrest) or `official_warning` (an authority describing a currently active method). Added beyond the requested fields so the two are never confused. |
| `source_name` | Outlet or agency that published the page |
| `source_url` | The exact URL fetched and read (after redirects) |
| `published_date` | Publication date taken **from the page itself**, not the retrieval date |
| `headline` | The page's headline, verbatim, so the source can be recognised |
| `summary_vi`, `summary_en` | Our own 2–3 sentence paraphrase of the **scammer's tactic** |
| `red_flags` | Short strings: the specific warning signs in that case |
| `retrieved_at` | When the page was fetched and verified (2026-10-07) |

Category counts: impersonation 4, romance 3, fake_scholarship 3, fake_job 3, investment 3,
phishing 3, other 3, loan 2.

Sources: VnExpress 6, Tuổi Trẻ 5, Bộ Công an (bocongan.gov.vn) 5, VietnamNet 3, Dân Trí 2,
Thanh Niên 1, Pháp Luật TP.HCM (PLO, served on tuoitre.vn) 1, Ngân hàng Nhà nước
(sbv.gov.vn) 1.

## Methodology

1. **Finding sources.** Web search, run separately for each category so the set would not
   skew toward the easiest one to find. Official sources were searched first (the Ministry
   of Public Security, the State Bank, the National Cyber Security Center). Their domains
   (`bocongan.gov.vn`, `sbv.gov.vn`) were confirmed from search results and from the pages
   themselves, not guessed. After that, VnExpress, Tuổi Trẻ, Thanh Niên, Dân Trí and
   VietnamNet were searched for articles about specific incidents, not general advice.
2. **Reading.** Every page was downloaded directly (raw HTML). Its headline and publish date
   were taken from the page's own metadata or byline, and its article text was read in full
   before any entry was written. No entry was written from search-result snippets or from
   general knowledge.
3. **Writing.** Summaries are paraphrased in our own words and describe only the tactic (see
   the privacy rule). Each summary and red flag was then compared sentence by sentence with
   the page. Claims the page did not support were corrected or removed. For example, an early
   draft said "one percent" where the article said 5%, and four red flags that were our
   inference rather than the article's were replaced.
4. **Final re-check.** Just before finishing, every URL was fetched again, not from cache, by
   `verify_sources.py`. It checks that the page:
   - returns HTTP 200 at the same URL;
   - contains the entry's headline;
   - contains the entry's publish date;
   - contains a distinctive phrase supporting the summary (for example "5% tổng số tiền"
     or "AJB DIRECT").

   **Result: 24/24 passed** on 2026-10-07. A first run failed one entry only because the page
   writes "KHÔNG" in capitals; the phrase check was made case-insensitive and all 24 were
   re-run.

Special cases:
- `impersonation-002` (sbv.gov.vn) has no date in its metadata; its date is the byline
  timestamp on the page (19/07/2024 17:29).
- `phishing-002` is a Bộ Công an Q&A page; its date is the answer date shown on the page
  (07/08/2025). The citizen who asked the question is named on the page but not in the dataset.
- `fake_scholarship-001` was found at plo.vn, which now redirects to `tuoitre.vn/plo/…`. The
  final URL is stored.

## Privacy rule (applied to every entry)

These are real people's cases. Summaries describe **the scammer's methods only**:
- No victim names, initials, ages, birth years, jobs, hometowns, districts or account details,
  even where the article prints them. Articles in this set did print victims' initials, birth
  years, districts, a pseudonym and an account holder's name; none of it was carried over.
- No exact personal loss figures; only ranges ("hàng chục triệu", "hundreds of millions").
- Suspects' names are also left out. They add nothing to the tactic, and news reports
  describe arrests and charges, not convictions.
- The one age figure that remains ("17–20 tuổi" in `impersonation-004`) is the Ministry's
  statistic about the most-targeted age group, not a detail about any person.

An automated scan of all summaries for initials, kinship titles followed by a name, birth
years, ages and exact sums found only that statistic.

Note: `headline` is kept verbatim so the source stays recognisable. Some Vietnamese headlines
mention a loss amount (e.g. "Mất 9 tỷ đồng…"), but none names or identifies a person.

## Duplicate check

Vietnamese outlets often republish the same police bulletin. Entries were compared on
incident details (place, date, amounts, sequence of events, issuing police unit):

- **Found and resolved:** a single Hanoi police bulletin of 2/4/2025 (an online "boyfriend",
  crypto, a 5% withdrawal fee) appeared in VnExpress, Tuổi Trẻ and Thanh Niên. Only VnExpress
  was kept (`romance-001`), because it was published first and does not name the victim. The
  other two URLs were dropped.
- **Reprint replaced by the original:** a Tuổi Trẻ/TTXVN article about fake VNeID apps
  repeated a Bộ Công an warning. The Ministry's own page is used instead (`phishing-002`).
- **Similar but separate, so both kept:**
  - `fake_scholarship-002` (Hanoi universities, Feb 2025) and `fake_scholarship-003`
    (Da Nang, May 2025): different schools, cities and dates.
  - `investment-002` and `investment-003`: both Da Nang police, but different rings (a fake
    "Nasdaq" exchange in Jan 2026; the BIT99 multi-level scheme in Jul 2026).
  - `impersonation-001` (a May 2025 report on Bắc Ninh cases) and `impersonation-004` (a
    November 2025 Ministry explainer of the method): the same tactic family, but not the same
    incident.
- A Bộ Công an list of fake-shipper methods (2025-04-12) was left out so that `other` would not
  be mostly shipper scams; `other-001` already covers that pattern.

## Sources tried but not used

| Source | Why |
|---|---|
| NCSC, `khonggianmang.vn` | The connection failed every time from the machine used (no HTTP response), so nothing from it was used |
| Bộ Giáo dục và Đào tạo, `moet.gov.vn` | No scholarship-scam warning was found on the official domain itself; the warnings exist only as reprints on other sites |
| Ngân hàng Nhà nước biometric phishing email (`sbvgov.site`) | No page about it was found on `sbv.gov.vn`; only secondary reprints |
| Bộ Công an "25 kịch bản lừa đảo 2026" | General list, not a specific case or method notice |
| VietnamNet 2022-04-26 "chuyển nhầm tiền" | General how-to guide, no incident (`other-003` covers the scam) |
| VnExpress 2025-01-08 (fanpages impersonating the education ministry) | No clear money-taking tactic described |

## Known limitations

- **Link rot.** A URL that works today may move or disappear. This file does not prove
  itself forever; re-run `python data/verify_sources.py` periodically (for example before
  each release) and fix or drop entries that fail.
- **Vietnamese-language sources only.** The set reflects what Vietnamese government sites
  and five large national outlets reported and what web search surfaced; it is not
  exhaustive and not a statistical sample of how often each scam happens.
- **Selection bias.** News covers dramatic or large cases. Small, common scams such as
  cheap fake-shop deposits are under-reported compared with how often they happen.
- **Uneven depth.** `loan` has 2 entries, the fewest. Some official warnings are short; for
  example the fake-VNeID warning describes the method but not a specific incident.
- **Not adjudicated.** Incident reports describe what police or journalists said at the
  time: complaints, arrests and charges, not court findings.
- **Tactics change.** Scripts evolve quickly; the dates show how recent each pattern is.
- **Paraphrases, not quotes.** Summaries are our wording. The page at `source_url` is the
  authority if they ever disagree.
