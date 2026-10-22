# Voice evaluation results (DESCRIPTIVE, NOT VALIDATION)

Cut-offs (clean arm, tuning only): t_ai 0.0020, t_hum 0.1779, usable gap: False.
Feature state: OFF (every reading in PLAN 8a keeps it OFF; scores are descriptive, not validation).
Trace rule (D7) excludes: ['noise_matched']; PLAN 8 item 2 satisfiable: False.

| Arm | Group | Held-out AUC [95%] | Reading | Real->Leans AI | AI->Leans human | Can't tell (all) | Server-rejected real/AI |
|---|---|---|---|---|---|---|---|
| clean | VieNeu Turbo | 0.832 [0.641, 1.0] | c_inconclusive | 0/24 (0.0-0.138) | 0/12 (0.0-0.242) | 36/36 (0.904-1.0) | 0/0 |
| clean | VieNeu Nano | 0.724 [0.479, 0.941] | c_inconclusive | 0/24 (0.0-0.138) | 0/12 (0.0-0.242) | 36/36 (0.904-1.0) | 0/0 |
| clean | VieNeu (both) | 0.778 [0.627, 0.917] | c_inconclusive | 0/24 (0.0-0.138) | 0/24 (0.0-0.138) | 48/48 (0.926-1.0) | 0/0 |
| noise_matched | VieNeu Turbo | 0.155 [0.023, 0.339] | a_credible_negative | 0/24 (0.0-0.138) | 0/12 (0.0-0.242) | 36/36 (0.904-1.0) | 0/0 |
| noise_matched | VieNeu Nano | 0.304 [0.099, 0.552] | a_credible_negative | 0/24 (0.0-0.138) | 0/12 (0.0-0.242) | 36/36 (0.904-1.0) | 0/0 |
| noise_matched | VieNeu (both) | 0.229 [0.085, 0.387] | a_credible_negative | 0/24 (0.0-0.138) | 0/24 (0.0-0.138) | 48/48 (0.926-1.0) | 0/0 |
| matched_raw | VieNeu Turbo | 0.307 [0.115, 0.521] | a_credible_negative | 0/24 (0.0-0.138) | 0/12 (0.0-0.242) | 36/36 (0.904-1.0) | 0/0 |
| matched_raw | VieNeu Nano | 0.158 [0.024, 0.347] | a_credible_negative | 0/24 (0.0-0.138) | 0/12 (0.0-0.242) | 36/36 (0.904-1.0) | 0/0 |
| matched_raw | VieNeu (both) | 0.233 [0.106, 0.387] | a_credible_negative | 0/24 (0.0-0.138) | 0/24 (0.0-0.138) | 48/48 (0.926-1.0) | 0/0 |
| raw | VieNeu Turbo | 0.792 [0.562, 1.0] | c_inconclusive | 0/24 (0.0-0.138) | 0/12 (0.0-0.242) | 36/36 (0.904-1.0) | 0/0 |
| raw | VieNeu Nano | 0.694 [0.438, 0.927] | c_inconclusive | 0/24 (0.0-0.138) | 0/12 (0.0-0.242) | 36/36 (0.904-1.0) | 0/0 |
| raw | VieNeu (both) | 0.743 [0.573, 0.896] | c_inconclusive | 0/24 (0.0-0.138) | 0/24 (0.0-0.138) | 48/48 (0.926-1.0) | 0/0 |
| phone_aac | VieNeu Turbo | 0.332 [0.161, 0.528] | a_credible_negative | 0/24 (0.0-0.138) | 0/12 (0.0-0.242) | 36/36 (0.904-1.0) | 0/0 |
| phone_aac | VieNeu Nano | 0.323 [0.132, 0.545] | a_credible_negative | 0/24 (0.0-0.138) | 0/12 (0.0-0.242) | 36/36 (0.904-1.0) | 0/0 |
| phone_aac | VieNeu (both) | 0.327 [0.175, 0.49] | a_credible_negative | 0/24 (0.0-0.138) | 0/24 (0.0-0.138) | 48/48 (0.926-1.0) | 0/0 |
| phone_opus | VieNeu Turbo | 0.351 [0.175, 0.544] | a_credible_negative | 0/24 (0.0-0.138) | 0/12 (0.0-0.242) | 36/36 (0.904-1.0) | 0/0 |
| phone_opus | VieNeu Nano | 0.339 [0.135, 0.562] | a_credible_negative | 0/24 (0.0-0.138) | 0/12 (0.0-0.242) | 36/36 (0.904-1.0) | 0/0 |
| phone_opus | VieNeu (both) | 0.345 [0.192, 0.511] | a_credible_negative | 0/24 (0.0-0.138) | 0/24 (0.0-0.138) | 48/48 (0.926-1.0) | 0/0 |
| phone_amr | VieNeu Turbo | 0.396 [0.222, 0.592] | a_credible_negative | 0/24 (0.0-0.138) | 0/12 (0.0-0.242) | 36/36 (0.904-1.0) | 0/0 |
| phone_amr | VieNeu Nano | 0.328 [0.134, 0.549] | a_credible_negative | 0/24 (0.0-0.138) | 0/12 (0.0-0.242) | 36/36 (0.904-1.0) | 0/0 |
| phone_amr | VieNeu (both) | 0.362 [0.203, 0.525] | a_credible_negative | 0/24 (0.0-0.138) | 0/24 (0.0-0.138) | 48/48 (0.926-1.0) | 0/0 |

Tuning AUC per arm (OPTIMISTIC, cut-offs chosen on these clips): clean 0.836; noise_matched 0.609; matched_raw 0.543; raw 0.812; phone_aac 0.334; phone_opus 0.416; phone_amr 0.422

Gender is confounded with recording batch (male real: FLEURS test; female real: FLEURS train). Every number above is descriptive only.
