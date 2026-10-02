# R7.4.5 — Combined BV qualification

The existing `bv_split` source already combines direct RGB stores with split
Brettel selection; Viénot uses direct stores in both `bv_direct` and `bv_split`.
The XPS replay measured that combination. This slice strengthens its semantic
qualification and repeats all three sizes on the four-compiler CI matrix,
without changing the timed kernel or introducing another equivalent variant.

`bv_qualification.d` checks float and double, all three Brettel deficiencies
and both Viénot deficiencies. Each scalar has 4,096 deterministic extended
RGB inputs, a 12 cubed edge cross-product (NaN, infinities, zero, normal and
subnormal magnitudes), and 15 points near stored separation planes: 5,839 inputs
in total. Separate tests use distinguishable synthetic plane matrices to check
positive/negative/equality branch selection. CTFE probes and explicit
`@safe pure nothrow @nogc` callers cover direct, split and in-place stores.

The checker returns failure explicitly; its checks remain active under
`-release`. Debug and optimized Release both run it before benchmarking.
It uses the existing absolute component tolerances (float 2e-6, double 1e-12)
and IEEE classification comparisons. It does not assert exact subnormal bits,
NaN payloads, signed-zero output bits, or independent model accuracy.

The workflow measures default/prepared/direct/split over sizes 1024/8191/65536,
three balanced blocks and 54 samples per language/case. Existing release full
corpus checks, C++ pairing, bounds checks and build flags remain in place.
Non-targeted Machado operations remain controls. CI clocks, thermals and SMT
are uncontrolled; differences across separate compiler jobs do not establish
an absolute compiler ranking.

## Recorded qualification — 2026-10-01

Source: `2a896ea470d7aacfe5791e7239605ac4435d5332`.
[Run 36924616940](https://github.com/alex-1974/color-d-research/actions/runs/36924616940)
passes all four jobs. Debug and Release each pass 5,839 inputs per scalar;
CTFE instantiations and attributed callers compile in every build.
The existing performance workflow (run 36924616973) and consumer replay smoke
(run 36924616881) also pass all four jobs at this source revision.

All four artifact ZIP digests match GitHub's recorded digests. Archive manifest
hashes, full raw sample matrices, and every block and pooled min/median/max and
D/C++ ratio are independently reconstructed. Together these contain 145,152
raw sample rows, 4,032 block cases and 1,344 pooled cases. Matched sampled
D/C++ checksum differences are zero for both scalars in every artifact.
All snapshot source hashes, including generated coefficients, match the
previous XPS archive. Timed kernels therefore have unchanged source identity;
this slice adds qualification rather than another implementation.

Condensed records, build qualification logs, source/binary identities and CI
artifact digests are retained under
[data/r7_4_5/bv-qualification-36924616940](../data/r7_4_5/bv-qualification-36924616940/).
Raw rounds and complete binaries are additionally in the CI audit artifacts,
which expire on 2026-12-30. Reconstruct reports with
[tools/inspect_bv_replay.py](../tools/inspect_bv_replay.py), passing an artifact
ZIP and a new output directory; run ordinary Python without -O.

## Performance result

The following ranges cover every deficiency, not just protan. Speedup means
original D median divided by combined `bv_split` median; greater than 1 is faster.
Block ranges compare matching block/scalar/deficiency/size, but separate variant
processes. These descriptive ranges are not confidence intervals.


| Compiler | Scalar / kernel | Speedup 1024 | Speedup 8191 | Speedup 65536 | All block speedups | Paired D/C++ |
|---|---|---:|---:|---:|---:|---:|
| dmd-2.111.0 | float / brettel | 6.74–6.78 | 7.61–7.68 | 3.30–3.32 | 3.30–7.88 | 1.99–5.93 |
| dmd-2.111.0 | float / vienot | 5.60–5.68 | 5.68–5.75 | 5.60–5.69 | 5.58–5.77 | 4.37–4.46 |
| dmd-2.111.0 | double / brettel | 4.15–4.19 | 4.67–4.69 | 2.14–2.16 | 2.14–5.89 | 1.20–3.24 |
| dmd-2.111.0 | double / vienot | 5.42–5.42 | 5.37–5.41 | 5.43–5.44 | 4.89–5.44 | 3.30–3.43 |
| dmd-2.113.0 | float / brettel | 9.94–9.96 | 9.81–9.84 | 4.53–4.61 | 4.51–10.01 | 2.13–5.15 |
| dmd-2.113.0 | float / vienot | 7.50–7.51 | 7.47–7.51 | 7.48–7.49 | 7.45–7.59 | 4.96–5.12 |
| dmd-2.113.0 | double / brettel | 4.27–4.28 | 4.20–4.24 | 2.11–2.16 | 2.11–4.30 | 1.25–2.78 |
| dmd-2.113.0 | double / vienot | 5.51–5.54 | 5.47–5.51 | 5.52–5.54 | 5.46–5.60 | 3.81–3.93 |
| ldc-1.41.0 | float / brettel | 1.54–1.60 | 1.58–3.19 | 5.43–5.74 | 1.52–5.76 | 1.11–1.16 |
| ldc-1.41.0 | float / vienot | 5.92–5.98 | 5.94–6.01 | 5.86–6.01 | 5.84–6.06 | 1.46–1.51 |
| ldc-1.41.0 | double / brettel | 1.17–1.19 | 1.21–2.38 | 4.09–4.35 | 1.16–4.36 | 0.89–0.93 |
| ldc-1.41.0 | double / vienot | 0.84–0.84 | 0.82–0.82 | 0.83–0.85 | 0.81–0.88 | 0.86–0.92 |
| ldc-1.43.0 | float / brettel | 1.44–1.52 | 1.51–3.02 | 5.34–5.79 | 1.44–5.79 | 1.11–1.16 |
| ldc-1.43.0 | float / vienot | 5.95–5.97 | 5.93–6.11 | 5.83–5.88 | 5.83–6.15 | 1.46–1.51 |
| ldc-1.43.0 | double / brettel | 1.16–1.18 | 1.32–2.28 | 4.12–4.29 | 1.15–4.34 | 0.90–0.94 |
| ldc-1.43.0 | double / vienot | 0.84–0.84 | 0.83–0.83 | 0.84–0.85 | 0.82–0.88 | 0.86–0.92 |

The combined form improves Brettel for every compiler/scalar/size/deficiency
in every block. DMD split selection materially outperforms the direct-only
Brettel variant; LDC split and direct-only are approximately tied. Gains over
the original are much smaller for LDC small batches than large batches, so
65536-item results must not be presented as a general application speedup.
Material DMD/C++ residual gaps remain, particularly at size 65536.

Float Viénot improves substantially on all four compilers. Double Viénot
improves on DMD, but LDC combined medians are about 18–22% slower than original
in all sizes/deficiencies. The regression occurs in every block on both LDC
versions, reproducing the earlier CI observation. It remains a platform-dependent
trade-off because the same source was approximately neutral on the XPS.
LDC float Viénot also remains about 1.46–1.51 times C++, whereas double Viénot
is still faster than this C++ baseline despite its regression against original D.
Both comparisons matter.

A measurement-control warning appears on DMD 2.113.0: float Viénot in the
split binary is roughly 9% faster than in the direct binary, even though the
Viénot source form is the same. Static disassembly comparison retains both
kernels and finds the same 137 instructions after normalizing symbol addresses,
RIP displacements and address comments; constant references resolve to the same
addresses. Binary placement differs. This does not identify the timing cause,
and the difference must not be attributed to Brettel split selection. It reinforces
the requirement to benchmark the final integrated binary before adopting a policy.

## Decision and next boundary

**Combined BV source equivalence qualified on the tested four-compiler matrix;
production performance acceptance remains open.** No production code or compiler
fork is introduced. `bv_split` remains a valid research candidate for Brettel
and float Viénot. A blanket BV replacement is rejected because of LDC double
Viénot and remaining C++ gaps.

The next implementation slice should compare an integrated internal policy:
combined Brettel, direct float Viénot, and original versus direct double Viénot.
A compiler-dependent double choice is only a candidate, and requires the same
centralized policy, attributes, CTFE, numerical checks and final-binary measurements.
The DMD/C++ residual gap still requires investigation rather than acceptance by
a green CI. No new XPS run is needed merely to repeat unchanged kernels; a new
integrated policy does need a targeted consumer replay. Independent scientific
reference envelopes and public API/consumer review remain separate gates.

## Follow-up: integrated policy

[The integrated BV comparison](R7_4_5_BV_POLICY.md) is now measured across the
four-compiler matrix. A centralized compiler-selected double Viénot choice
preserves DMD gains and restores approximately original LDC timing. Small-batch
LDC 1.41 double Brettel and material C++ residual gaps keep performance acceptance
open. The new policy binary still needs its own consumer replay.
