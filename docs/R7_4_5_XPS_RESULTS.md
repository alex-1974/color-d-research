# R7.4.5 — XPS results, 2026-10-01

The consumer replay completed and the returned archive passed independent structural, hash and raw-report inspection. Large Brettel/Viénot improvements replicate, but these results do not select one implementation for every compiler or close the production performance gate.

## Identity and inspection

- Source: `f5b4428af90b02f38902776d87259e5096155e0a`; all nine tracked source Git blob hashes match that revision.
- Intel Core i7-9750H, 6 cores / 12 threads; Linux 6.17.0-22-generic; affinity CPU 0.
- DMD 2.111.0; LDC 1.41.0, frontend 2.111.0, LLVM 19.1.7; GCC 15.2.0.
- Eight variants, sizes 1024 / 8191 / 65536, three balanced blocks, 54 rounds per language/case.
- All 1,827 manifest entries verified. All 743 recorded commands returned success. All 145,152 raw sample rows are finite and the complete matrix is present.
- Recomputed all 4,032 block medians and all 1,344 pooled min/median/max values and D/C++ ratios exactly from raw rounds. Matched D/C++ checksum differences are zero for float and double.
- Debug preflight and release component checks passed in the recorded run; uploaded binaries were not executed during inspection.

Returned archive: `color-cvd-xps-b5ftptcx.tar.gz`, 14,402,051 bytes.

SHA-256: `9576c118cc22ae60994451202ca492bd4b746bb6e600c43984c782243e9239b1`.

## Large improvements and residual gaps

Tables cover every deficiency and all three sizes, rather than one selected case. Speedup is default D median divided by candidate D median; values above 1 indicate improvement. Block ranges compare medians within the same block, compiler, scalar, deficiency and size, but variants are separate timed processes. These are descriptive ranges, not confidence intervals. D/C++ is each candidate paired with its fresh C++ baseline.

### DMD 2.111.0

| Scalar / kernel | Candidate | Speedup 1024 | Speedup 8191 | Speedup 65536 | All block speedups | Paired D/C++ |
|---|---|---:|---:|---:|---:|---:|
| float / brettel | bv_split | 27.54–27.83 | 18.78–18.86 | 16.02–16.33 | 15.24–28.49 | 2.61–4.68 |
| double / brettel | bv_split | 4.03–4.40 | 2.95–3.07 | 2.71–2.87 | 2.60–4.67 | 1.25–2.07 |
| float / vienot | bv_direct | 4.27–4.37 | 4.36–4.49 | 4.32–4.38 | 4.07–4.59 | 5.77–6.11 |
| double / vienot | bv_direct | 4.38–4.42 | 4.33–4.43 | 4.32–4.44 | 4.15–4.88 | 3.84–4.06 |
| float / lookup | ma_bounded | 0.98–1.03 | 0.99–1.00 | 1.00–1.02 | 0.96–1.06 | 4.86–5.19 |
| double / lookup | ma_bounded | 0.96–0.99 | 0.95–0.97 | 0.97–0.99 | 0.93–1.06 | 5.20–5.87 |
| float / lookupApply | ma_bounded | 0.82–0.83 | 0.81–0.82 | 0.82–0.84 | 0.77–0.86 | 3.58–3.82 |
| double / lookupApply | ma_bounded | 0.82–0.83 | 0.79–0.81 | 0.81–0.82 | 0.80–0.85 | 5.26–5.52 |
| float / lookup | ma_direct | 1.27–1.29 | 1.26–1.31 | 1.25–1.28 | 1.11–1.35 | 3.77–3.97 |
| double / lookup | ma_direct | 1.78–1.82 | 1.73–1.77 | 1.76–1.78 | 1.70–1.87 | 2.99–3.09 |
| float / lookupApply | ma_direct | 0.93–0.96 | 0.94–0.97 | 0.93–0.95 | 0.86–0.99 | 3.05–3.22 |
| double / lookupApply | ma_direct | 1.16–1.18 | 1.12–1.14 | 1.16–1.16 | 1.07–1.23 | 3.73–4.03 |

### LDC 1.41.0

| Scalar / kernel | Candidate | Speedup 1024 | Speedup 8191 | Speedup 65536 | All block speedups | Paired D/C++ |
|---|---|---:|---:|---:|---:|---:|
| float / brettel | bv_split | 2.04–3.29 | 3.47–3.60 | 3.54–3.67 | 1.98–4.01 | 0.96–1.02 |
| double / brettel | bv_split | 1.58–2.28 | 2.40–2.48 | 2.48–2.67 | 1.42–2.78 | 0.84–0.87 |
| float / vienot | bv_direct | 5.46–5.49 | 5.93–5.93 | 5.77–5.92 | 4.92–6.07 | 1.03–1.15 |
| double / vienot | bv_direct | 0.98–0.99 | 0.99–1.02 | 0.99–1.01 | 0.76–1.03 | 0.73–0.84 |
| float / lookup | ma_bounded | 1.27–1.30 | 1.29–1.30 | 1.25–1.31 | 0.89–1.37 | 1.03–1.09 |
| double / lookup | ma_bounded | 1.15–1.16 | 1.16–1.17 | 1.17–1.25 | 1.12–1.29 | 1.02–1.10 |
| float / lookupApply | ma_bounded | 1.15–1.15 | 1.15–1.17 | 1.14–1.16 | 1.08–1.21 | 0.86–0.91 |
| double / lookupApply | ma_bounded | 1.13–1.13 | 1.14–1.16 | 1.15–1.21 | 1.09–1.32 | 0.85–0.91 |
| float / lookup | ma_direct | 0.75–0.77 | 0.75–0.76 | 0.74–0.76 | 0.71–0.80 | 1.73–1.82 |
| double / lookup | ma_direct | 0.96–0.97 | 0.96–0.97 | 0.94–0.98 | 0.89–1.25 | 1.28–1.34 |
| float / lookupApply | ma_direct | 1.06–1.08 | 1.08–1.09 | 1.07–1.10 | 1.02–1.14 | 0.92–0.96 |
| double / lookupApply | ma_direct | 1.08–1.11 | 1.10–1.11 | 1.10–1.12 | 1.03–1.16 | 0.91–0.95 |

## Interpretation

LDC float Brettel direct stores improve 2.00–3.73 times over default pooled medians and give D/C++ 0.96–1.00. Split selection has no consistent additional advantage (0.96–1.02 D/C++). For double Brettel, prepared, direct and split forms all improve substantially, with small differences between them. The earlier LDC double Viénot preparation regression is not reproduced here: preparation and direct stores are approximately neutral versus default. This is evidence for this compiler/platform, not proof that the CI regression was spurious.

DMD split Brettel improves both scalars in every block. Float default is unusually slow: pooled medians are 169–176 ns/item; split is 16–28 times faster. Do not generalize this exceptional baseline into an expected application speedup. Double split improves 2.71–4.40 times in pooled cases. Substantial DMD/C++ gaps remain for Viénot and Machado, and large-batch Brettel still differs from C++.

For Machado, LDC bounded tables give pooled lookup speedup factors 1.15–1.31 and lookup+apply speedup factors 1.13–1.21. The float lookup block range includes reversals (minimum speedup 0.89), so small lookup wins need repetition. Combined application improves in every block. LDC direct interpolation regresses float pure lookup by about one third in elapsed time (speedup 0.74–0.77). DMD direct interpolation improves pure lookup for both scalars and double lookup+apply; float lookup+apply still regresses. Fixed and bounded DMD lookup+apply regress roughly 19–27% in elapsed time. No universal Machado replacement follows.

The severe DMD 2.111.0 fixed-table float lookup regression seen in CI is not reproduced on this machine: fixed lookup is roughly neutral. Source identity is checked, but hardware, GCC baseline and environment differ. Retain the CI result and investigate the differing code generation/workload behaviour before accepting a compiler policy.

## Measurement limits and decision

The governor was powersave, turbo enabled and SMT active. Observed scaling_cur_freq values were approximately 4.10–4.29 GHz at observation points; these are not continuous clock records. One unlabelled thermal zone rose from 59.05 to 96.05 degrees C before measurement and remained around 91–92 degrees C at later boundaries. Sensor types were not recorded, so this does not establish CPU temperature or throttling. AC power, background load and power profile are not independently documented; the note only says XPS.

Some block medians vary materially: maximum D block max/min is 1.67 for an unchanged DMD float lookup control, and 1.54 for an unchanged LDC prepared-Machado control. This limits interpretation of narrow improvements and of absolute compiler rankings. Small batches also show different deficiency behaviour. Balanced order and paired C++ measurements reduce some bias but do not eliminate it. The C++ source shares coefficients and is not an independent numerical oracle; release validation before D timing has different cache effects from C++.

**Consumer replay inspected; production performance acceptance remains open.** The existing `bv_split` already combines direct BV output stores with split Brettel selection. Its [four-compiler qualification](R7_4_5_BV_QUALIFICATION.md) passes extended Debug/Release semantic checks and repeats all three sizes. LDC double Viénot regresses in CI on both versions, so a blanket combined BV replacement remains unjustified. For Machado, keep default/fixed/bounded/direct operations separate until a portable choice or justified compiler policy is demonstrated. Do not introduce a production compiler fork from this run. Repeat small differences under better documented conditions and investigate remaining DMD gaps. Independent model envelopes, consumer composition, attributes/CTFE qualification and API review remain separate gates.

## Retained evidence

Condensed records under [data/r7_4_5/xps-20261001](../data/r7_4_5/xps-20261001/): inspection and platform observations; complete pooled report; all block summaries; candidate comparisons; original full archive hash manifest. These preserve all cases, including regressions and non-targeted controls. The original user-supplied archive retains raw rounds, binaries, source and command logs; its large audit payload is not duplicated into Git history, following QUALITY_GATES tier 3. Condensed reports do not replace that archive for a raw-round audit.
