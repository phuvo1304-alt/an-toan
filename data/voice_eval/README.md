# Voice evaluation (Vietnamese) - closed 2026-10-22

**Conclusion:** the AI-voice-detection feature is **not shipped**. For this detector model
(`garystafford/wav2vec2-deepfake-voice-detector` @ `c66306024a7ede0be291e9c4558b37634782dc4e`), these voices
(VieNeu Turbo/Nano, MMS-TTS-vie) and these conditions, the pre-registered cut-offs had no usable gap
(t_hum 0.1779 > t_ai 0.0020), every clip was "Can't tell", and the held-out AUCs read (c) inconclusive on the
clean and plain raw arms and (a) credible negative on the five other arms; none read (b). This says nothing about
AI-voice detection in general. Details: `PLAN.md` (rules, deviations D1-D8, check log C1-C6), `results/`,
`CLAUDE.md` section 14.11. Everything here is descriptive, not validation.

## Honest summary
We paired 40 real Vietnamese recordings (FLEURS, CC BY 4.0) with 40 clips made by local text-to-speech from the
same sentences (VieNeu Turbo and Nano, counted as one family, plus one MMS voice in the tuning set only), and we
wrote the rules, the analysis code and a file manifest before the detector scored anything. We found and logged
several shortcuts that separate the two classes without the voice itself (loudness, silence, noise, roll-off, and
above all the original sample rate, which cannot be removed without altering the voices), repaired what the plan
allowed, and froze the rest. We then ran the real voice server once on 560 clips (7 arms x 80). The cut-offs
chosen on tuning data left no gap between "human" and "AI", so nothing could be labelled, and the held-out AUCs
were either inconclusive (clean, plain raw) or below the pre-registered bar (the other arms, several below 0.5).
With 24 real and 24 AI held-out clips, one detector and these generators, we cannot say more than that this
detector, as tested, is not good enough to ship, and the evaluation could not rule out that it relied on
shortcuts.

## Do not claim
- that An Toan or this evaluation detects deepfakes or AI voices;
- that the detector (or the feature) was validated, or that any number here is an accuracy;
- that it works, or was tested, on phone calls, Zalo, or real recordings of calls (the phone-like arms are
  simulations; the Zalo set was never recorded);
- that three independent generators were tested (Turbo and Nano are one family; MMS was tuning-only);
- that cloned voices, modern commercial generators or old-style generators were tested (none were);
- that AI-voice detection "does not work" in general;
- that the 0 false-positive / 0 false-negative counts mean anything (nothing was labelled).

## Reproduce (pinned hashes)
Nothing large is in git: audio, model weights and virtual environments are git-ignored. Checks that need no audio:
`selection.sha256` (sentence selection), `manifest.sha256` (manifest and the three frozen scripts, verified by
`cutoffs.verify_freeze()` and by `run_eval.py` / `analyze.py` themselves), `models.sha256` (every downloaded model
file; the detector's `model.safetensors` sha256 is `905e330265c40a76955911ce86691fb4c8f2ed9c8085f4f046cac1383592a0ac`).
Python environments are hash-pinned in `requirements-vieneu.lock` and `requirements-mms.lock`; the voice server's
pins are in `voice-server/requirements.txt`. Order (see `PLAN.md` section 11): `select_sentences.py --check`,
`fetch_models.py`, `fetch_fleurs_audio.py`, `make_ai_clips.py`, `prepare_audio.py`, `prepare_phone_arms.py`,
`trace_feature.py`, `shortcut_check.py`, `build_manifest.py`, then start `voice-server` with a fresh random key
and run `run_eval.py` and `analyze.py`. The file hashes in `manifest.csv` identify the exact audio used. Not
verified: that regenerating the TTS clips gives byte-identical audio (the per-clip seeds are recorded in
`ai_clips_record.csv`); if the hashes differ, the run is a new evaluation, not a reproduction. Run
`scan_outputs.py` before any commit. Credits and licences: `SOURCES.md`.
