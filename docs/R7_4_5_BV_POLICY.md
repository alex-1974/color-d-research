# R7.4.5 — Integrated BV policy candidates

The combined source passes the previous qualification, but a blanket BV
replacement regresses LDC double Viénot. This experiment measures the final
integrated binaries rather than inferring a choice from isolated kernel timings.

| Operation | `bv_portable` | `bv_compiler` |
|---|---|---|
| Brettel float/double | Prepared planes, direct stores, split selection | Same |
| Viénot float | Prepared matrix, direct stores | Same |
| Viénot double under LDC | Original per-item reference form | Same |
| Viénot double under DMD | Original per-item reference form | Prepared matrix, direct stores |
| Viénot double under other compilers | Original form | Original form |

The compiler choice is centralized in `bv_policy.d`: LDC keeps original double
Viénot; DigitalMars uses direct double Viénot. The portable path is retained.
The tested versions are DMD 2.111.0/2.113.0 and LDC 1.41.0/1.43.0. There is no
version threshold or performance promise for future compilers, and no production
compiler fork is accepted by creating these research variants.

Both candidates call the same attributed internal batch functions as their
qualification probes. The original double source form retains per-item
coefficient selection; preparing once and returning a value is a distinct earlier
probe. Allocation, clipping, fast-math and disabled bounds checks are not added.
Machado operations remain unchanged measurement controls.

The extended 5,839-input checks now also run both integrated policies for every
valid deficiency, with separate and exact in-place arrays. CTFE and attributed
callers cover the same functions. The replay snapshots the policy and qualification
source and runs Debug and optimized Release qualification for every compiler,
including consumer runs. Its archives retain those logs and binaries.

The dedicated workflow compares default/direct/split/portable/compiler-selected
over 1024/8191/65536 items and three balanced blocks (54 samples per language/case).
The default replay now supports ten variants, adding these two to the prior eight;
the older pinned XPS protocol remains tied to its eight-variant revision.

## Recorded result — 2026-10-02

Source: `e948f48b71bea374702d79ae8bf9a4aba0010e56`.
[Integrated-policy run 36971582787](https://github.com/alex-1974/color-d-research/actions/runs/36971582787)
passes all four compiler jobs. The performance baseline (run 36971582778) and
expanded ten-variant consumer smoke (run 36971582756) also pass all four jobs.
Each Debug/Release qualifier passes 5,839 extended/IEEE inputs per scalar and
explicit policy, CTFE and attribute checks. The recorded policy labels confirm
DMD selects direct double Viénot and LDC selects the original form.

All four ZIP digests and 2,412 archive manifest entries verify. The eleven
tracked snapshot files match GitHub at the pinned source revision. Generated
coefficients are identical across the artifacts and covered by the manifests.
All 956 recorded commands succeed; 720 timed process commands use the recorded
CPU affinity. Reconstructing 181,440 raw samples exactly reproduces all 5,040
block reports and 1,680 pooled reports. Matched D/C++ sampled checksum differences
are zero for float and double. These are source/workload checks, not independent
scientific model qualification.

| Compiler job | CPU model reported by runner |
|---|---|
| DMD 2.111.0 | AMD EPYC 7763 |
| DMD 2.113.0 | Intel Xeon Platinum 8370C |
| LDC 1.41.0 | AMD EPYC 9V45 |
| LDC 1.43.0 | AMD EPYC 7763 |

Do not infer an absolute compiler ranking from different jobs. GCC is 13.3.0
in this CI replay, versus 15.2.0 on the earlier XPS. Frequency, thermal state,
SMT and shared host load remain uncontrolled. One unchanged LDC 1.43 float
lookup control has block max/min 1.80, so narrow differences need restraint.

## Integrated compiler-selected measurements

Ranges below include every deficiency. Speedup is original D median divided by
`bv_compiler` median; greater than 1 is faster. Each block range matches compiler,
scalar, deficiency and size, but variants run in separate timed processes. These
are descriptive ranges, not confidence intervals. Complete portable and control
comparisons, including regressions and unchanged Machado cases, are retained.


| Compiler | Scalar / kernel | Speedup 1024 | Speedup 8191 | Speedup 65536 | All block speedups | Paired D/C++ |
|---|---|---:|---:|---:|---:|---:|
| dmd-2.111.0 | float / brettel | 6.65–6.78 | 7.60–7.66 | 3.30–3.32 | 3.30–7.70 | 1.99–5.94 |
| dmd-2.111.0 | float / vienot | 5.59–5.68 | 5.67–5.76 | 5.61–5.70 | 5.57–5.77 | 4.37–4.45 |
| dmd-2.111.0 | double / brettel | 4.15–4.19 | 4.65–4.66 | 2.14–2.16 | 2.14–4.70 | 1.21–3.25 |
| dmd-2.111.0 | double / vienot | 5.42–5.42 | 5.41–5.42 | 5.44–5.44 | 5.41–5.46 | 3.31–3.41 |
| dmd-2.113.0 | float / brettel | 42.58–42.90 | 27.01–28.66 | 21.34–21.37 | 21.15–43.80 | 2.11–4.58 |
| dmd-2.113.0 | float / vienot | 5.74–5.79 | 5.43–5.64 | 5.50–5.54 | 5.42–6.79 | 5.53–6.31 |
| dmd-2.113.0 | double / brettel | 4.08–4.10 | 3.22–3.29 | 2.66–2.68 | 2.65–4.29 | 1.33–2.48 |
| dmd-2.113.0 | double / vienot | 4.91–5.05 | 4.89–5.04 | 4.90–5.05 | 4.89–5.06 | 3.40–4.55 |
| ldc-1.41.0 | float / brettel | 1.26–1.29 | 1.31–1.95 | 5.50–6.41 | 1.25–6.49 | 1.07–1.13 |
| ldc-1.41.0 | float / vienot | 6.29–6.33 | 6.43–6.52 | 6.37–6.37 | 6.02–6.68 | 1.39–1.44 |
| ldc-1.41.0 | double / brettel | 0.88–0.90 | 0.95–1.45 | 4.12–4.35 | 0.88–4.42 | 0.87–0.89 |
| ldc-1.41.0 | double / vienot | 1.00–1.00 | 0.99–1.01 | 0.98–1.03 | 0.92–1.13 | 0.70–0.72 |
| ldc-1.43.0 | float / brettel | 1.46–1.51 | 1.49–2.98 | 5.32–5.77 | 1.45–5.78 | 1.12–1.16 |
| ldc-1.43.0 | float / vienot | 6.00–6.00 | 5.93–6.10 | 5.81–5.95 | 5.81–6.13 | 1.45–1.51 |
| ldc-1.43.0 | double / brettel | 1.15–1.18 | 1.23–2.42 | 4.11–4.26 | 1.15–4.26 | 0.89–0.93 |
| ldc-1.43.0 | double / vienot | 1.00–1.00 | 1.00–1.01 | 1.02–1.02 | 0.99–1.04 | 0.72–0.78 |

## Interpretation and decision

The compiler-selected candidate restores LDC double Viénot to approximately
original performance (pooled speedup 0.98–1.03 for LDC 1.41 and 1.00–1.02 for
LDC 1.43), while being 1.17–1.26 times faster than the all-direct/split binary.
On DMD it preserves direct double Viénot's gain: 5.41–5.44 times original on
2.111 and 4.89–5.05 on 2.113. The portable policy loses those gains: its original
DMD double Viénot remains approximately 17–23 times the paired C++ baseline.
The compiler-selected candidate therefore has a material supported-matrix
advantage over that portable choice, with a centralized and qualified decision.

Brettel and float Viénot largely preserve the corresponding direct/split control
performance. The extreme DMD 2.113 float Brettel speedups (21–43 times) reflect
an unusually slow original baseline on that job; they are not expected general
application speedups. Material DMD/C++ gaps remain after integration: roughly
2.0–6.3 for float operations and up to 4.5 for double Viénot in these cases.
LDC float Viénot still differs from C++ by about 1.39–1.51.

LDC 1.41 double Brettel at n=1024 is 11–14% slower than original D in pooled
cases; at n=8191 protan also slightly regresses. This behaviour is shared by the
existing split control (integrated/control pooled factors 0.976–1.018 across
these double cases); integration does not establish its cause. LDC 1.43 does
not show that small-batch regression in this run. A size-specific fallback or
new compiler threshold is not selected from this evidence.

Static inspection retains LDC 1.41 default, split and compiler-selected double
Brettel disassembly. The original batch calls the scalar helper per item. The
candidate has a larger body, input/output range checks and packed/scalar paths.
After address normalization, split and compiler-selected computation instructions
match; the differing immediates are bounds-failure file-name length/source-line
arguments. These observations document generated code, not a proven causal
explanation for the small-batch result.

**Integrated source equivalence and compiler choice qualified on this CI matrix;
production performance acceptance remains open.** `bv_compiler` is the preferred
candidate for the next consumer replay, rather than a promoted production default.
No API or production source is changed. The LDC small-batch limitation and material
remaining C++ gaps require investigation or an explicit accepted trade-off.
Independent scientific reference envelopes and public API/consumer review remain
separate gates.

## Retained evidence and next consumer replay

Condensed records under
[data/r7_4_5/bv-policy-36971582787](../data/r7_4_5/bv-policy-36971582787/) retain
both policies, every case, block and pooled summaries, checksum/source/binary
identity, build commands, platform observations, Debug/Release logs, comparisons
and static diagnostic excerpts. CI artifacts retain complete raw rounds and
binaries; expiry is recorded per artifact. The large audit payload is not duplicated
into Git history. Reconstruct reports using ordinary Python without -O:

```bash
python3 tools/inspect_bv_replay.py ARTIFACT.zip NEW_OUTPUT_DIRECTORY \
    default bv_direct bv_split bv_portable bv_compiler
```

The pinned [XPS script](../tools/run_xps_bv_policy.sh) compares original,
all-direct/split and compiler-selected binaries at all three sizes and blocks.
It runs both Debug and Release qualifiers before timing, records the observed
power profile if available, leaves existing checkouts alone and changes no power,
SMT or turbo controls. Use mains power, a stable profile and low background load;
let the machine return to a similar starting temperature before a repeat. Provide
actual AC/background notes; the script does not assert them automatically.

Run the tracked script from a checkout containing it:

```bash
bash tools/run_xps_bv_policy.sh "XPS; record actual AC and background conditions here"
```

The final RESULT_ARCHIVE line identifies the archive to return. The returned
2026-10-02 integrated archive is now [inspected](R7_4_5_BV_POLICY_XPS.md): all hashes,
source identities, raw matrices and reconstructed reports pass. The gains survive
integration on the XPS; the LDC small-batch CI regression is not reproduced there.
This completes the integrated consumer stage, while material DMD/C++ gaps and
independent model/API gates remain open. Earlier isolated-form XPS measurements
retain their own source/binary identity.

### Viénot component-load and CTFE source-shape follow-up

The [four-compiler source-shape comparison](R7_4_5_VIENOT_SHAPES.md) at source
`b2267e17ad45c5b47e3f1fa5922b55de83236b61` is fully inspected. Indexed component
loading improves DMD Viénot by about 1.56–1.69 times for float and 1.96–2.01 times
for double against the selected policy. CTFE coefficients improve LDC float,
but materially regress DMD float and unchanged double Machado controls under
DMD 2.113. No integrated policy or production API was changed. The DMD indexed
residual gap remains about 2.8–3.0 times C++ for float and 1.8–1.9 times for
double on these CI hosts; the performance gate is still open. The next narrow
probe is reference-bound input iteration with direct stores and bounds checks.
