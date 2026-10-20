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

**Rule.** FLEURS `vi_vn`, seed `20261021`. A sentence is eligible if its clip is 3–13 s and the text is at most 200 characters. Sentences are ranked by `sha256("20261021|"+sentence_id)`. Each sentence gets exactly one real clip and one AI clip.

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
- I also run a pitch check, which can contradict a label but can't confirm one. A voice that disagrees is marked "contradicted" and dropped from the gender breakdown. Replacement follows the same hash order and happens before any score.
- **Real speakers:** I'd have you listen to 6 real clips (3 M / 3 F) as a spot-check on FLEURS' labels.

## 2. Fairness controls

Every clip, real and AI, goes through one chain:
1. Decode and resample to 16 kHz mono.
2. Trim leading and trailing silence with a fixed rule (20 ms frames below −45 dBFS, keeping 0.2 s padding each end).
3. RMS-normalize to −23 dBFS with a −1 dBFS peak cap.
4. Write 16-bit PCM WAV.

This is the "clean" condition.

**Statistics reported per class and per tool:** duration (min/median/max), silence before trimming, RMS/peak before normalization, original sample rate, and 95% spectral roll-off.

**Shortcut check:** a tiny classifier on those features alone, scored on held-out. If its AUC is 0.75 or higher, the set is flagged "confounded", and no detector claim is made.

**Raw arm:** the raw, unprocessed clips are also scored (WAV container only: no trimming, no normalization, same selected clips). The raw arm is not used to choose the cut-offs, which come from the clean tuning clips, and the same cut-offs are applied to it. It is a **required gate in §8**, because the production path has no trimming or normalization. The shortcut check is computed on the clean arm only; on the raw arm it is reported descriptively, since length and silence differences are expected there.

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
- `scan_outputs.py` runs before every commit. It rejects `supabase`, `.supabase.co`, `.run.app`, `eyJ…`, `VOICE_SHARED_SECRET`, and any `http(s)://` outside a short allow-list of public source links.
- The harness reads the server address from the environment and never writes it to a file.
- Results record only the model revision hash and the voice-server git commit.
- `CONSENT.md` covers only your own voice. No one else's voice is recorded.

## 5. Manifest

**Fields.** clip_id (opaque), role, split, source, source_split, sentence_id, speaker_label (FLEURS: `unknown-<gender>`; TTS: voice name), tool, voice, gender, gender_check, condition, derived_from, duration_s, orig_sample_rate, silence stats, sha256, model/SDK versions, seed.

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
   - The shortcut check flags the set as confounded.
   - Real clips are called "Leans AI" in 3 or more of 24 (clean or any phone-like condition).
   - 2 or more of your 12 Zalo clips are called "Leans AI".
   - **The clean arm passes but the raw arm fails any ON-limited condition below.** Production receives raw audio, so a clean-only pass is **OFF**.
2. **ON, limited** only if all hold, **on the clean arm AND on the raw (unprocessed) arm**, using the same cut-offs:
   - AUC is at least 0.80 for both VieNeu models.
   - At most 1 of 24 real clips is called "Leans AI" (in clean, and in raw), and at most 2 of 24 in each phone-like condition.
   - At most 1 of your 12 Zalo clips is called "Leans AI".
   - "Can't tell" is at most 60% of held-out clips (in clean, and in raw).
   - Wording is the §9 text, with no percentages and the flag labelled experimental.
3. **Can't-tell-only** is everything else: no verdict, only the "call back on a number you know" advice. I'd treat this as OFF unless you want the advice-only screen.

This rule says nothing about old-style generators, since none are in held-out.

## 9. What results can and cannot claim, and in-app wording

- **Can claim:** the observed error counts and intervals for these specific VieNeu voices versus FLEURS clean read speech, in these simulated conditions.
- **Cannot claim:** old-style generators, cloned voices, paid tools, newer generators, real phone calls, other speakers or phones, or that a voice is real or safe.

**English.** "Voice check (experimental). It estimates whether a voice sounds more like a recording of a person or like computer-generated speech. It was tested on a small number of clean read-aloud clips and on voices from a few free computer-voice tools. It was not tested on cloned voices, paid voice tools or real phone calls, so it can be wrong either way. It is not proof that a voice is real or fake, or of who is speaking. 'Leans human' does not mean safe. Never send money because of a voice. Hang up and call back on a number you already know."

**Vietnamese.** "Kiểm tra giọng nói (thử nghiệm). Công cụ ước lượng giọng nói nghe giống bản ghi âm người thật hay giống giọng do máy tạo ra. Công cụ chỉ được thử trên một số ít đoạn đọc sạch và giọng của vài công cụ giọng máy miễn phí. Chưa thử với giọng nhân bản, công cụ giọng nói trả phí hay cuộc gọi thật, nên có thể sai theo cả hai hướng. Kết quả không phải bằng chứng một giọng là thật hay giả, hay ai đang nói. 'Nghiêng về giọng người' không có nghĩa là an toàn. Đừng chuyển tiền chỉ vì một giọng nói — hãy cúp máy và gọi lại số bạn đã biết."

**Labels.** "Leans human" = "Nghiêng về giọng người". "Leans AI" = "Nghiêng về giọng do máy tạo". "Can't tell" = "Chưa thể xác định".

## 10. Credits

They go in `CREDITS.md` at the repo root and in Settings → About. They credit authors and licenses only, with no statement about preset-speaker consent:
- the detector model and its dataset, as already specified
- FLEURS (Google, CC BY 4.0), with the exact citation text copied from the dataset card (unverified until I copy it)
- VieNeu-TTS v3 Turbo/Nano by Phạm Nguyễn Ngọc Bảo (Apache-2.0, repo and HF links), plus MOSS-Audio-Tokenizer-Nano (OpenMOSS-Team) and sea-g2p
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
