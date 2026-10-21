Nothing is installed or built. I read the `vieneu` 3.8.3 source and tested phone formats against `audio.py`, and both results are below.

## Findings from today's checks

**`vieneu` 3.8.3** (pure-Python wheel, 2.6 MB, sha256 `7388d166e65746f5bb075bf8094d324f8131a82393680b712260d6f2f983ef06`). I read the code in an empty scratch folder and did not install it.
- **`trust_remote_code=True`** appears in `standard.py` (legacy) and `_v3_turbo_engine/inference_v3_turbo.py` (lines 69 and 81, the PyTorch/GPU path). Those would execute code fetched from HF.
- **CPU path:** `v3turbo.py:169` picks `onnx_runtime_lite` when the device is CPU. That path has no `trust_remote_code`, no pickle and no `torch.load`. We force it with `backend="onnx"`.
- **Other risky calls:** I found no `pickle`, `eval`/`exec`, sockets or telemetry in `vieneu/` or `vieneu_utils/`.
  - `np.load` on the `.npz` files never sets `allow_pickle`, so it is off by default.
  - `subprocess` appears only in `serve.py`, which we never import.
- **Network:** the only network use is `huggingface_hub` downloads by repo name, unpinned. We pre-download by commit hash and run with `HF_HUB_OFFLINE=1`.
- **Dependencies:** METADATA lists unpinned ranges, including `gradio>=5.49.1`, a heavy web framework only the `apps/` folder uses. I read only 5 of the SDK's files for this, so it is not a full audit.
- **Third-party package:** `sea-g2p` (same author) is a dependency I have not read yet. I'll read it the same way before installing.
- **Rewriting the ONNX driver ourselves** (prefill, decode, acoustic, codec, sampling, phonemizer) would be larger and riskier than using the SDK's ONNX-lite path. So the plan is the SDK pinned at `vieneu==3.8.3`, installed `--no-deps` with a hand-pinned subset and no gradio. If `import vieneu` fails without gradio, I report back instead of installing it.

**Phone formats through `audio.decode`.** I made stand-ins with the local ffmpeg 9.0.2 and ran all of them through `voice-server/app/audio.py`:

| Stand-in | Result |
|---|---|
| iPhone AAC `.m4a` and ALAC `.m4a` | Decoded |
| iPhone `.caf` | Decoded |
| Android `.3gp` and `.amr` | Decoded |
| Android AAC `.mp4` and raw `.aac` | Decoded |
| Opus `.ogg` and `.webm` | Decoded |

All nine decoded to the right 5.77 s length. Still unverified:
- real Zalo and iPhone files, which I don't have
- the Debian ffmpeg used in the Docker image, whose AMR decoder may differ

One gap: the server's content-type allow-list has no `amr`, `3gpp` or `caf`. `application/octet-stream` is accepted, so the client can send that.

## 1. Data and split

**Rule.** FLEURS `vi_vn`, seed `20261021`. A sentence is eligible if its clip is 3–13 s, the text is at most 200 characters, **and (deviation D1, see "Deviations" at the end) the text contains only Vietnamese letters, spaces and a fixed punctuation list, with every word a valid Vietnamese syllable** (so digits, currency and other symbols, acronyms and foreign names or words are excluded). **A real clip is also eligible only if the production voice server would not reject it (deviation D3)**: it is decoded by the server's own decoder, with the server's own silence and length limits imported from `voice-server/app`, and must lie in the 3–13 s window. Sentences are ranked by `sha256("20261021|"+sentence_id)`. Each sentence gets exactly one real clip and one AI clip.

| | Tuning | Held-out |
|---|---|---|
| Real | 16 male, from train | 12 male (test) + 12 female (train block, sentences not in tuning) |
| AI | 16: MMS 6, VieNeu Turbo 5, VieNeu Nano 5 | 24: Turbo 12, Nano 12 (each 6 M / 6 F, each voice 2 clips), gender-matched to the real clip |

**Voices (names from the cards; the pinned SDK's `list_preset_voices()` is authoritative and gets recorded).** No voice appears in both splits, and same-named Turbo/Nano voices count as one speaker.
- **Tuning, Turbo:** Thanh Bình and Xuân Vĩnh (M); Quỳnh Anh, Ngọc Trân and Kim Thanh (F).
- **Tuning, Nano:** Anh Khôi, Minh Quân and Mạnh Dũng (M); Mai Anh and Trúc Ly (F).
- **Tuning, MMS:** its one voice.
- **Held-out, Turbo:** Minh Đức, Phạm Tuyên and Quang Sơn (M); Ngọc Linh, Đoan Trang and Thục Đoan (F).
- **Held-out, Nano:** Hữu Quân, Adam and Đức Trí (M); Ái Hân, Xuân Tiên and Mỹ Duyên (F).

**Plain consequence:** MMS is in tuning only, so the held-out set has **no old-style generator**. We have no held-out evidence about old-style generators. MMS also scores into the tuning cut-offs.

**Confirming gender by listening.** The card's gender labels are unverified, so you'd do a blind check.
- I generate one 3–4 s clip per voice, with shuffled filenames and no key. You write M, F or unsure for each.
- **Required:** the 12 held-out voices (about 1 minute).
- **Optional:** the 10 tuning voices and MMS (about 1 more minute).
- **The blind human listening check decides** (deviation D2). A voice whose label you contradict by ear is marked "contradicted" and dropped from the gender breakdown; the replacement follows the same hash order and happens before any score. I also run a pitch check, but it is **advisory only**: it is recorded, and it neither confirms nor contradicts a label (male and female voices overlap around 165-180 Hz).
- **Real speakers:** I'd have you listen to 6 real clips (3 M / 3 F) as a spot-check on FLEURS' labels.

## 2. Fairness controls

Every clip, real and AI, goes through one chain:
1. Decode and resample to 16 kHz mono.
2. Trim leading and trailing silence with a fixed rule (20 ms frames below −45 dBFS, keeping 0.2 s padding each end).
3. RMS-normalize to −23 dBFS with a −1 dBFS peak cap.
4. Write 16-bit PCM WAV.

This is the "clean" condition.

**Implementation details, fixed on 2026-10-22 before any statistic was computed** (the plan left these open; `prepare_audio.py` and `shortcut_check.py` hold them as named constants):
- **Decode:** the production voice server's own decoder (`audio.decode`, ffmpeg) applied to the original 32-bit float files (never to a 16-bit copy); the result is 16 kHz mono float32.
- **Silence rule:** 20 ms non-overlapping frames (320 samples); a frame is silent if its RMS is below -45 dBFS (absolute, full scale = 1.0). The leading and trailing runs of silent frames are removed while keeping 10 frames (0.2 s) of padding on each side (never more than exists). A clip with no active frame is left untrimmed and reported.
- **Order and normalization (changed by deviation D5, 2026-10-22):** *gain 1* brings the whole decoded clip to **-28 dBFS RMS** (no peak limit at this intermediate float stage); then the silence rule above trims it, so the same -45 dBFS threshold behaves the same on quiet and loud recordings; then *gain 2* brings the trimmed clip to exactly **-28 dBFS RMS**. The -1 dBFS peak cap is checked on the final clip only and must never bind (the largest crest factor is 27.7 dB). Every clean-arm clip must end at -28.00 dBFS RMS within 0.05 dB. (The earlier version of this bullet trimmed at -45 dBFS before normalizing to -23 dBFS; it cut 8% to 91% of the energy of four quiet real clips and left 15 real clips quieter than every AI clip.)
- **16-bit write:** `round(x * 32767)`, clipped to the int16 range, no dither.
- **Raw arm:** the original files with ONLY the sample format converted to 16-bit PCM by the same rounding. Sample rate, channels and content are untouched (no resampling, trimming or gain).
- **Noise-matched arm (simulated; deviation D5):** the clean-arm files, except that every AI clip gets seeded **pink Gaussian noise** (power proportional to 1/f, made by shaping white Gaussian noise in the frequency domain; an independent draw for each clip) over its whole length. The target noise floor of each AI clip is drawn, with replacement and seeded, from the measured noise floors of the **real clips of the same split** in the clean arm. The noise level is adjusted (at most 8 iterations, tolerance 0.25 dB) until the AI clip's measured noise floor equals its draw; an AI clip whose own floor is already at or above its draw gets no noise; the mixture is re-normalized to -28 dBFS RMS. Real clips are unchanged. Seed 20261022. Before/after noise-floor statistics are reported per class.
- **Level-randomized raw arm (simulated; deviation D5):** the raw arm (original sample rate, mono), but every clip of BOTH classes gets one seeded random gain drawn uniformly between -20 dB and 0 dB, applied to the original float samples before the single 16-bit rounding, so loudness cannot separate the classes. Seed 20261023. After this gain the production server may reject some very quiet clips as silent; they are counted and reported by class, and their features are still measured (with the server's conversion but without its checks) so that the shortcut check covers all 80 clips.
- **Statistics:** duration, leading and trailing silence (same -45 dBFS rule), noise floor (10th percentile of the 20 ms frame levels), RMS and peak (dBFS), original sample rate and format, and the 95% spectral roll-off (frequency below which 95% of the average power spectrum lies; 1024-sample Hann frames, hop 512).
- **Shortcut check (features, classifier and threshold fixed before running; run on four arms since D5: clean, noise-matched, raw, level-randomized raw):** seven features measured on the arm's files as the production server converts them, which is what the detector will see: `duration_s`, `lead_silence_s`, `trail_silence_s`, `noise_floor_dbfs`, `rms_dbfs`, `peak_dbfs`, `rolloff95_hz`. Classifier: ridge logistic regression (L2 = 1.0, features standardized on the tuning set), trained on the tuning clips (16 real + 16 AI), scored on the held-out clips (24 real + 24 AI), AI = positive class. The set is flagged "confounded" if the held-out AUC is at least 0.75. Interval: stratified bootstrap of the held-out clips, 2,000 resamples, seed 20261021, percentile 95%. Also reported, descriptively: the AUC of each single feature (direction chosen on the tuning set). The same feature list, classifier, 0.75 threshold and bootstrap are used on every arm. **Gate arms (D5): clean, noise-matched and level-randomized raw.** The plain raw arm is still scored and reported, but it is descriptive only because loudness alone separates its classes (shortcut AUC 0.911).

**Statistics reported per class and per tool:** duration (min/median/max), silence before trimming, RMS/peak before normalization, original sample rate, and 95% spectral roll-off.

**Shortcut check:** a tiny classifier on those features alone, scored on held-out. If its AUC is 0.75 or higher, the set is flagged "confounded", and no detector claim is made.

**Raw arm:** the raw, unprocessed clips are also scored (WAV container only: no trimming, no normalization, same selected clips). The raw arm is not used to choose the cut-offs, which come from the clean tuning clips, and the same cut-offs are applied to it. It is a **required gate in §8**, because the production path has no trimming or normalization. Since D5 the shortcut check is computed on the clean, noise-matched and level-randomized raw arms (the gate arms); on the plain raw arm it is descriptive, since loudness and silence differences are expected there.

## 3. Phone-like and Zalo phone-path

**Simulated, labelled `simulated`.** Each simulated clip starts from the clean clip, is band-limited to 300–3400 Hz, gets a little seeded noise (about 30 dB SNR), then is encoded as:
- AAC 24 kbps `.m4a`
- Opus 12 kbps `.ogg`
- AMR-NB 12.2 kbps `.amr`

They follow their original into the same split and don't add to n.

**Zalo phone-path (separate, your voice only, local, never committed).**
- You read 12 held-out male-test sentences on your phone, and send them through Zalo as voice messages.
- You also send 5 held-out TTS files through Zalo.
- I compare each received file's container, codec and size (via ffprobe) with what you sent.
- **Shows:** whether the decoders handle real Zalo/phone files, whether one real voice survives phone capture and Zalo without being called "Leans AI", and paired scores before and after Zalo for the 5 TTS files.
- **Cannot show:** any rate, since one speaker, one phone and one Zalo version give no rates. It is also not a phone call. I report raw counts only.

## 4. Folder layout

```
data/voice_eval/
  README.md  CONSENT.md  SOURCES.md     committed
  select_sentences.py  make_tts.py  prepare_audio.py  phone_sim.py  run_eval.py  analyze.py  scan_outputs.py   committed
  selection.csv  manifest.csv  manifest.sha256   committed
  results/metrics.json  results/report.md        committed
  audio/  models/  .venv-tts/                    git-ignored
```

- `.gitignore` also blocks all audio extensions under `data/voice_eval/`.
- `scan_outputs.py` runs before every commit. It rejects backend and model-server host names, the names of the backend-URL, anon-key, shared-secret and AI-key environment variables (in files under `data/voice_eval/`), JWT-like tokens and API-key prefixes, and any web link outside a short allow-list of public source and licence links.
- The harness reads the server address from the environment and never writes it to a file.
- Results record only the model revision hash and the voice-server git commit.
- `CONSENT.md` covers only your own voice. No one else's voice is recorded.

## 5. Manifest

**Fields.** clip_id (opaque), role, split, source, source_split, sentence_id, speaker_label (FLEURS: `unknown-<gender>`; TTS: voice name), tool, voice, gender, gender_check (for the 12 held-out TTS voices: `human-blind-confirmed`, with the pitch result stored as an advisory flag; other voices: `declared-unverified`; MMS: `unknown`), condition, derived_from, duration_s, orig_sample_rate, silence stats, sha256, model/SDK versions, seed.

**Hashing order.**
1. `selection.csv` is frozen and its sha256 committed **before any TTS or audio is generated**.
2. Audio is generated and prepared with no scoring.
3. The full `manifest.csv` sha256 is committed **before the first score**.

Any later change is a deviation logged in CLAUDE.md §14.

## 6. Run path

`run_eval.py` POSTs each file to the real voice-server (`app.asgi:app`) over HTTP. That goes through the real `main.py`, `audio.decode`, `split` and `VoiceModel`. It aborts if `MODEL_REVISION` differs from the one in the manifest header, and no separate scoring code exists.

Pre-registered clip score:
- The clip score is the mean of the piece scores.
- A "Leans" label also requires that no piece sits on the opposite side.
- A clip under 3 s is "Can't tell".

## 7. Analysis

**Tuning, cut-offs only.**
- `t_ai` is the lowest value at which at most 1 of the 16 tuning real clips would be called "Leans AI".
- `t_hum` is the highest value at which at most 1 of the 16 tuning AI clips would be called "Leans human".
- If `t_hum ≥ t_ai`, there is no usable gap.

**Held-out.**
- False-positive rate: real called "Leans AI".
- False-negative rate: AI called "Leans human".
- "Can't tell" share per class.
- Each with a Wilson 95% interval.

**Breakdowns.** By tool (Turbo and Nano, and VieNeu combined), by gender, and by condition (clean, three phone-like, raw). I also report threshold-free AUC per model. Tuning numbers are shown only for transparency and labelled optimistic. Gender is confounded with batch (male from test, female from train), so a male/female gap isn't attributable to gender.

## 8. Decision rule (frozen at your "go")

Checked in order. The first match wins.

1. **Stays OFF** if any of these hold:
   - There is no tuning gap.
   - Held-out clean AUC is below 0.70 for either VieNeu model (near chance).
   - **A gate arm (clean, noise-matched, level-randomized raw) is shortcut-flagged (held-out shortcut AUC 0.75 or higher).** A flagged arm cannot be used for the ON gate, so the feature stays OFF.
   - Real clips are called "Leans AI" in 3 or more of 24 (clean or any phone-like condition).
   - 2 or more of your 12 Zalo clips are called "Leans AI".
   - **The clean arm passes but the noise-matched arm or the level-randomized raw arm fails any ON-limited condition below.** Production receives raw audio, so a clean-only pass is **OFF**. (The plain raw arm is reported but no longer a gate arm; see section 2.)
2. **ON, limited** only if all hold, **on the clean arm AND on the noise-matched arm AND on the level-randomized raw arm** (none of them shortcut-flagged), using the same cut-offs:
   - AUC is at least 0.80 for both VieNeu models.
   - At most 1 of 24 real clips is called "Leans AI" (in each of the three gate arms), and at most 2 of 24 in each phone-like condition.
   - At most 1 of your 12 Zalo clips is called "Leans AI".
   - "Can't tell" is at most 60% of held-out clips (in each of the three gate arms).
   - Wording is the §9 text, with no percentages and the flag labelled experimental.
3. **Can't-tell-only** is everything else: no verdict, only the "call back on a number you know" advice. I'd treat this as OFF unless you want the advice-only screen.

This rule says nothing about old-style generators, since none are in held-out.

## 9. What results can and cannot claim, and in-app wording

- **Can claim:** the observed error counts and intervals for these specific VieNeu voices versus FLEURS clean read speech, in these simulated conditions.
- **Cannot claim:** old-style generators, cloned voices, paid tools, newer generators, real phone calls, other speakers or phones, or that a voice is real or safe. Very quiet recordings that the server rejects as silent are not covered by this evaluation.

**English.** "Voice check (experimental). It estimates whether a voice sounds more like a recording of a person or like computer-generated speech. It was tested on a small number of clean read-aloud clips and on voices from a few free computer-voice tools. It was not tested on cloned voices, paid voice tools or real phone calls, so it can be wrong either way. It is not proof that a voice is real or fake, or of who is speaking. 'Leans human' does not mean safe. Never send money because of a voice. Hang up and call back on a number you already know."

**Vietnamese.** "Kiểm tra giọng nói (thử nghiệm). Công cụ ước lượng giọng nói nghe giống bản ghi âm người thật hay giống giọng do máy tạo ra. Công cụ chỉ được thử trên một số ít đoạn đọc sạch và giọng của vài công cụ giọng máy miễn phí. Chưa thử với giọng nhân bản, công cụ giọng nói trả phí hay cuộc gọi thật, nên có thể sai theo cả hai hướng. Kết quả không phải bằng chứng một giọng là thật hay giả, hay ai đang nói. 'Nghiêng về giọng người' không có nghĩa là an toàn. Đừng chuyển tiền chỉ vì một giọng nói — hãy cúp máy và gọi lại số bạn đã biết."

**Labels.** "Leans human" = "Nghiêng về giọng người". "Leans AI" = "Nghiêng về giọng do máy tạo". "Can't tell" = "Chưa thể xác định".

## 10. Credits

They go in `CREDITS.md` at the repo root and in Settings → About. They credit authors and licenses only, with no statement about preset-speaker consent:
- the detector model and its dataset, as already specified
- FLEURS (Google, CC BY 4.0), with the exact citation text copied from the dataset card (unverified until I copy it)
- VieNeu-TTS v3 Turbo/Nano by Phạm Nguyễn Ngọc Bảo (Apache-2.0, repo and HF links), plus sea-g2p
- MOSS-Audio-Tokenizer-Nano (OpenMOSS-Team, Apache-2.0): the ONNX audio codec Turbo uses on CPU, a fourth download source approved by the owner on 2026-10-21 (pinned commit in `SOURCES.md`)
- MMS-TTS-vie, Meta AI, Vineel Pratap et al., CC BY-NC 4.0, used unmodified

## 11. Build order and time

| Step | Who | Estimate |
|---|---|---|
| Safe environment, `sea-g2p` review, hash-pinned install, offline import test | Me | 0.5–1 h |
| `select_sentences.py`, frozen `selection.csv`, hash committed | Me | 0.5 h |
| FLEURS download | Me | Best case a few hundred MB if row-range reads work (unverified). Worst case about 2.1 GB (test 544 MB + train 1.6 GB tarballs). |
| TTS generation (40 clips + 23 voice-check clips) | Me | About 15 min of machine time |
| Blind voice check and the 6-clip real-voice spot-check | You | 3–5 min |
| Prepare pipeline, statistics, shortcut check, phone simulation | Me | 1.5 h |
| Record 12 sentences, send 12 + 5 files through Zalo, return them | You | About 30 min |
| Manifest v1 hash committed, then the scoring run (about 340 clips) | Me | 30–60 min of machine time |
| Analysis, report, CLAUDE.md §14 entry | Me | 1–1.5 h |

My total is about 5–6 h across 3–4 sessions, and yours is about 1 h. Cost is zero: no accounts and no paid APIs. Bandwidth is about 1–3 GB.

## 12. Decisions for you

| Decision | My default |
|---|---|
| Approve the §8 numbers (editable until "go") | As written |
| Install `vieneu==3.8.3 --no-deps` with the pinned subset, after reviewing `sea-g2p` | Yes |
| FLEURS download up to about 2.1 GB, and stop and ask if streaming fails | Yes |
| Raw arm (now a required gate in §8, no longer optional) | Included |
| Your own-voice gender label | Leave blank |
| Is "Can't-tell-only" a real ship option? | Treat as OFF |
| Server content types (`amr`/`3gpp`/`caf`) | Client sends `octet-stream`; decide in Stage 3/4 |
| Test AMR decoding in the Docker image later | Yes |

## Deviations

Any change to a rule above after "go" is logged here and in CLAUDE.md §14.

**D1, 2026-10-21, before any audio, TTS or score existed (owner decision).** The first `selection.csv` (sha256 `c06a54e60c5b00497653e82eebd0e4138a6ac16cfd75cef0a3ccdc280347c12d`, commit `2508912`) contained sentences with digits (9 of 40), symbols and foreign names or acronyms. TTS tools and human readers say these differently, which would confound real versus AI. One general text rule was added to `select_sentences.py` (see §1) and the selection was regenerated: new sha256 `bb8b51b24c2f8208bfc52a038d983fb2878cff0ef36bc2685393fa34c84cf640`. No sentence was chosen or rejected by hand or by listening. Eligible sentences after the rule: train male 251 of 503, train female 527 of 1,053, test male 130 of 238. The 16 tuning, 24 held-out and 12 owner-reads sentences are all still filled.

**D2, 2026-10-21, before any score existed (owner decision).** Rule changed from "a pitch contradiction drops a voice" to "**a blind human listening check decides; pitch is advisory**". Reason: the blind listening check of the 12 held-out voices matched the declared gender on **12 of 12**. A simple pitch estimate (median over voiced frames, line at 165 Hz) flagged two declared-male voices, Turbo / Quang Sơn (median 170 Hz, range 129-229 Hz) and Nano / Hữu Quân (median 173 Hz, range 125-206 Hz), but that is the overlap zone between male and female voices, so pitch cannot contradict a male label there. Both voices are kept. **`selection.csv` is unchanged** (sha256 `bb8b51b24c2f8208bfc52a038d983fb2878cff0ef36bc2685393fa34c84cf640`); no voice was replaced. `gender_check` is `human-blind-confirmed` for all 12 held-out voices, with the pitch flag recorded as advisory. Measured pitch (10th to 90th percentile of voiced frames; declared-male medians 93-173 Hz, declared-female medians 188-254 Hz, no overlap between the medians):

| Tool | Voice | Declared | Human blind answer | Pitch median (Hz) | Pitch range p10-p90 (Hz) | Pitch vs 165 Hz line |
|---|---|---|---|---|---|---|
| nano | Ái Hân | female | female | 188 | 135-278 | agrees |
| turbo | Ngọc Linh | female | female | 199 | 170-320 | agrees |
| nano | Mỹ Duyên | female | female | 240 | 189-312 | agrees |
| nano | Xuân Tiên | female | female | 240 | 179-294 | agrees |
| turbo | Thục Đoan | female | female | 250 | 182-325 | agrees |
| turbo | Đoan Trang | female | female | 254 | 170-276 | agrees |
| nano | Đức Trí | male | male | 93 | 76-104 | agrees |
| nano | Adam | male | male | 114 | 93-127 | agrees |
| turbo | Phạm Tuyên | male | male | 115 | 80-158 | agrees |
| turbo | Minh Đức | male | male | 165 | 102-213 | agrees |
| turbo | Quang Sơn | male | male | 170 | 129-229 | advisory flag (borderline) |
| nano | Hữu Quân | male | male | 173 | 125-206 | advisory flag (borderline) |

Limits: the listening check used one short neutral sentence per voice, one listener, and the voices' own declared labels as the reference; "human-blind-confirmed" means this listener heard the declared gender, not an independent proof. The tuning voices and MMS were not checked.

**D3, 2026-10-21, before any TTS clip or score existed (owner decision).** Five of the 40 selected real clips were real but very quiet recordings (clip RMS 0.0014 to 0.0019, below the production voice server's silence threshold of 0.002), so the production server rejects them as `silent`. A real clip is now eligible only if the production voice server would not reject it. This is ONE general rule written in code (`select_sentences.py` with `server_accepts.py`): the clip is decoded by the server's own decoder and checked against the server's own silence and length limits, all imported from `voice-server/app` with no copied constants, plus the existing 3 to 13 s window. Every real clip, including the 35 that passed, goes through it. Replacement order, fixed in code: (1) another clip of the SAME sentence in the same FLEURS split and gender slot, in hash order of the clip file name; (2) only if none is eligible, the next unused sentence in that slot's existing sentence hash order (its clips again in clip hash order). Slots are handled in pair_id order, and tuning and held-out stay sentence-disjoint. Every clip examined, accepted or rejected, with its RMS, is in the committed `d3_candidates.csv` (46 rows), which also lets `select_sentences.py --check` reproduce the selection without any audio.

`selection.csv` sha256: **old (D1)** `bb8b51b24c2f8208bfc52a038d983fb2878cff0ef36bc2685393fa34c84cf640` → **new (D3)** `d1139ecce4c1ec1288f34171a2a2d17c671537800923e7c3ce2346ccef3020ad`.

| Slot | Rejected clip (sentence, RMS) | Replacement route | Replacement clip (sentence, RMS) |
|---|---|---|---|
| HM02 | 9088029412031891891.wav (1731, 0.00162) | same sentence | 9672827979950260572.wav (1731, 0.02853) |
| HF03 | 6533195788186937056.wav (535, 0.00162) | next sentence (the same-sentence alternative 7645183277623857507.wav, RMS 0.00195, was also rejected as silent) | 17592022833946101415.wav (692, 0.01023) |
| HF06 | 1400109587702781292.wav (1462, 0.00178) | same sentence | 16769593023567067772.wav (1462, 0.06736) |
| HF07 | 9652404536445760873.wav (514, 0.00140) | next sentence (no other eligible clip of sentence 514) | 15565711173617988781.wav (761, 0.00278) |
| HF09 | 5127889560336273519.wav (1387, 0.00190) | same sentence | 14316448862120873437.wav (1387, 0.03732) |

Effects: the 12 owner-read sentences are unchanged (HM02 kept sentence 1731; only its clip changed). The tuning pairs and the male held-out pairs are unchanged. Because the AI voice and tool assignment is a hash function of the held-out female sentence set, five unaffected female pairs got different AI voices (HF02, HF04, HF05, HF10, HF12) and the Zalo TTS pick moved from HF07 to HF03; counts per tool, voice and gender are unchanged, and no TTS existed yet. Download: 2,052 MB read (537 MB test, 1,515 MB train, streamed; no archive stored); the 5 rejected originals and 27 unused candidates were deleted; 40 clips kept. All 40 final clips pass the production server's own decoder (RMS lowest 0.0020, still above the 0.002 threshold). Limit: very quiet recordings that the server rejects as silent are not covered by this evaluation.

## Check log (checks that are not deviations)

**C1, 2026-10-21, completeness check of the AI clips by listening (owner).** Rule written in code before any result was looked at (`completeness_check.py`): flag an AI clip if its speed (characters of text per second) is below 0.6x or above 1.6x of the median speed of the same tool; HM02 is always included. The rule flagged **0** clips on its own (every clip lay between 0.69x and 1.31x of its tool's median); HM02 was included by instruction. 4 unflagged clips were drawn as controls with `random.Random(20261021).sample(...)`. The 5 clips were copied with opaque shuffled names and the owner listened with the criterion "the audio stops before the sentence ends or skips words". **Result: all 5 OK (HM02 and the 4 controls); no defect, no regeneration, no D4.** Limits: 5 of 40 clips were listened to, so this is a sample check; the speed rule has little power at these thresholds; the owner identified the files by their order in a screenshot.

**C2, 2026-10-22, audio preparation and shortcut check (no scoring; nothing changed, findings only).** The clean and raw arms of all 80 clips were prepared exactly as section 2 says (implementation details above). Findings, all awaiting the owner's decision:
- **Shortcut check, clean arm (rule fixed before running):** held-out AUC **0.733**, stratified bootstrap 95% interval **[0.590, 0.866]**. By the letter of the rule (flag at 0.75 or higher) the set is **not flagged**, but it is borderline: the interval contains 0.75, and three single features separate the held-out classes on their own (noise floor AUC 0.861, peak 0.806, roll-off 0.742; AI clips have a quieter background, lower peaks and a lower roll-off). Raw arm (descriptive only): AUC 0.911 [0.819, 0.979], driven by loudness (RMS AUC 1.000), peak, duration and silences, as expected.
- **The fixed -45 dBFS absolute silence rule damages quiet real recordings.** Removed parts never reach -45 dBFS (the stated test passes by construction), but 4 real clips lose a large share of their energy: HM05 91% (7.44 s becomes 0.42 s), HM12 40%, HF07 16%, HM03 8%. 8 real clips have a whole-clip RMS below -45 dBFS. No AI clip loses even 1%. Largest trim: real 7.86 s in total (HM12), AI 0.37 s (T12).
- **The -1 dBFS peak cap lowered the gain of 15 real clips and no AI clip**, so those real clips end between -23.15 and -28.03 dBFS RMS while every AI clip is at -23.00. Real clips have a higher crest factor (median 19.4 dB against 16.5 dB for AI).
- **Clips below 3 s after trimming:** 2 of 80 (HM02 AI, 2.92 s; HM05 real, 0.42 s); under section 6 these would be "Can't tell".

**D5, 2026-10-22, before any score existed (owner decision).** Four changes to the audio preparation, all written down before the new statistics were computed (details in section 2 and section 8):
1. **Clean arm: normalize first, then trim.** The first clean arm trimmed at an absolute -45 dBFS before normalizing. That cut 8% to 91% of the energy of four quiet real clips (HM05 91%, 7.44 s became 0.42 s; HM12 40%; HF07 16%; HM03 8%) and 8 real clips lie below -45 dBFS overall. No AI clip lost even 1%.
2. **Clean arm: -28 dBFS RMS target** (was -23). The -1 dBFS peak cap lowered the gain of 15 real clips and no AI clip, leaving those real clips between -23.15 and -28.03 dBFS while every AI clip was at -23.00 (real crest factor median 19.4 dB against 16.5 dB for AI). The target is applied in two gains (before and after trimming) so that every clip ends at the same RMS; the cap is applied to the final clip only.
3. **New simulated noise-matched arm:** seeded pink Gaussian noise added to the AI clips only, so each AI clip's noise floor follows the distribution of the real clips' noise floors of the same split.
4. **New simulated level-randomized raw arm:** a seeded random gain, uniform between -20 and 0 dB, on every raw clip of both classes.

Old shortcut numbers (before D5; features measured on the first clean arm and on the raw arm; AI = positive; held-out 24 + 24): **clean arm AUC 0.733, bootstrap 95% interval [0.590, 0.866]** (not flagged by the 0.75 rule but borderline); single features noise floor 0.861, peak 0.806, roll-off 0.742, RMS 0.521, leading silence 0.477, duration 0.367, trailing silence 0.341. **Raw arm AUC 0.911 [0.819, 0.979]** (RMS 1.000, peak 0.962, duration 0.823, leading silence 0.783, roll-off 0.767, trailing silence 0.732, noise floor 0.477). Section 8 now uses the clean, noise-matched and level-randomized raw arms as the gate arms, and a shortcut-flagged gate arm (AUC 0.75 or higher) keeps the feature OFF. The plain raw arm is still prepared and will be reported, but it is no longer a gate arm.

**C3, 2026-10-22, results of the D5 preparation (no scoring; nothing further changed).**
- **Normalize-first trimming:** HM05 real is no longer cut to 0.42 s; it keeps 7.14 s (0.30 s trimmed, 0.03% of its energy). No real clip loses more than 0.15% of its energy (before D5: four clips lost 8% to 91%). Cost: 6 real clips (HM01, HM02, HM04, HM07, HM08, HM09) have a noise floor at or above -45 dBFS once raised to -28 dBFS, so their leading and trailing noise cannot be trimmed by this rule.
- **-28 dBFS target:** all 80 clean clips end at -28.00 dBFS RMS within 0.05 dB (lowest -28.03). The -1 dBFS peak cap still bound on one clip, HF02 real, by 0.03 dB (its trimmed crest factor is 28.0 dB); at the intermediate gain-1 stage two clips reach -0.75 and -0.26 dBFS in floating point, which is harmless. Only 1 of 80 clips is below 3 s after trimming (HM02 AI, 2.92 s).
- **Noise-matched arm (simulated):** pink Gaussian noise was added to 33 AI clips and matched their drawn target floor within 0.26 dB; 7 AI clips (T06, T10, T12, T13, T14, T15, HM07) already had a floor above their draw and got no noise (by 1.3 to 26.7 dB). The distance between the real and AI floor distributions fell from 0.50 to 0.31 (tuning) and from 0.58 to 0.29 (held-out) (two-sample KS), so the match is closer but not identical.
- **Level-randomized raw arm (simulated):** the gain U(-20, 0) dB leaves a loudness gap (median whole-clip RMS: real -43.5, AI -29.0 dBFS), and the production server rejects **8 real clips and 0 AI clips as silent** in this arm.
- **Shortcut check (rule unchanged: 7 features, 0.75, bootstrap seed 20261021), held-out AUC and 95% interval:** clean **0.684** [0.524, 0.835], not flagged; noise-matched **0.701** [0.542, 0.849], not flagged; level-randomized raw **0.918** [0.814, 0.993], **FLAGGED**; plain raw (descriptive) 0.911 [0.819, 0.979]. Single features on the clean arm: noise floor 0.870, peak 0.863, roll-off 0.762; after noise matching the noise-floor feature drops to 0.592 while peak (0.854) and roll-off (0.741) remain. In the level-randomized raw arm the drivers are leading silence (1.000), RMS (0.950), peak (0.903), trailing silence (0.832) and duration (0.823).
- **Consequence under the section 8 rule fixed in D5:** a gate arm (level-randomized raw) is shortcut-flagged, so it cannot be used for the ON gate and the feature stays OFF unless the owner approves a changed design. Options are in the report; none has been applied.
