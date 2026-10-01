# R7.4.5 — Prepared Brettel and Viénot candidates

## Scope and reproducible evidence

Source: `8c844e2b96d55c092f1210d343798aebd39ac4f0`.
[Run 36906875614](https://github.com/alex-1974/color-d-research/actions/runs/36906875614)
passes DMD 2.111.0/2.113.0 and LDC 1.41.0/1.43.0.

This is a research experiment. It changes neither the qualified original
reference implementations nor color-d production source/API. The shared C++
comparator remains a code-generation baseline, not an independent scientific
oracle. See [baseline methodology](R7_4_5_PERFORMANCE_BASELINE.md).

Three executables isolate:
- **default:** original per-item Brettel/Viénot probes.
- **prepared:** selects/casts both Brettel matrices and plane normal, or one
  Viénot matrix, once per batch; retains the existing Matrix3.apply arithmetic.
- **inline:** same preparation, with an explicit attributed matrix arithmetic
  helper marked pragma(inline, true). Operation order and scalar precision
  match the original matrix application.

Preparation is **inside each timed noinline batch**, amortized over 65536
items. Input allocation remains outside timing. No manual SIMD, fast-math,
compiler-specific implementation, safety weakening or clipping is introduced.
Machado kernels are unchanged and serve as additional workload controls.

Each variant has its own paired D/C++ forward and reverse measurements, 28
cases and 18 samples per language/case. Variant order is default/prepared/inline
on the forward pass and reversed on the second pass. This is one balanced
sequence, not independently replicated controlled-hardware evidence.

[Committed records](../data/r7_4_5/run-36906875614/) retain all raw samples,
min/median/max summaries, platform metadata, three Debug preflights, binary
hashes and selected batch call/packed-arithmetic diagnostics (104 files).
Complete disassembly and generated sources are additionally in CI artifacts
and expire with those artifacts. Source, input generator, exact build commands
and workflow remain tracked for replay.

## Correctness scope

Assertion-enabled Debug preflights run the qualified original probes and both
candidate forms, with float and double:
- every component of the deterministic 65536-input RGB corpus;
- black, white, primaries, one out-of-gamut input, NaN, infinities and zero inputs;
- inputs constructed on/near all three stored plane equations;
- CTFE comparisons for a representative input for each Brettel deficiency.

Comparisons enforce finite component tolerances float 2e-6 / double 1e-12,
NaN classification and infinity equality. They do not assert NaN payloads or
signed-zero bit patterns. Candidate helpers and validation compile as
@safe pure nothrow @nogc. CTFE coverage here is representative, not exhaustive.

All twelve optimized measurement summaries report a maximum sampled D/C++
checksum difference of **zero** for float and double. Optimized full-corpus
component validation is not performed by this workflow; the timed checksum
checks are smoke evidence. Independent scientific model/reference-envelope
qualification remains separate.

The initial candidate commit failed type inference for module-qualified
template types. Explicit scalar template arguments repaired it before the
successful measured source above. No failed-run timing is used.

## Paired findings

Protan medians in ns/item, 18 samples per variant. The prepared/C++ ratio uses
the C++ measurements paired with that candidate, not another runner.

| Compiler | Kernel | Scalar | Baseline | Prepared | Inline | Prepared / C++ |
|---|---|---|---:|---:|---:|---:|
| ldc-1.41.0 | brettel | double | 16.483 | 3.848 | 3.848 | 0.92 |
| ldc-1.41.0 | vienot | double | 0.953 | 1.134 | 1.123 | 0.93 |
| ldc-1.41.0 | brettel | float | 13.347 | 10.207 | 10.220 | 4.61 |
| ldc-1.41.0 | vienot | float | 7.079 | 6.997 | 6.983 | 8.89 |
| ldc-1.43.0 | brettel | double | 12.309 | 3.093 | 3.093 | 0.86 |
| ldc-1.43.0 | vienot | double | 0.726 | 0.867 | 0.870 | 0.92 |
| ldc-1.43.0 | brettel | float | 10.003 | 8.148 | 8.355 | 4.43 |
| ldc-1.43.0 | vienot | float | 6.329 | 6.317 | 6.322 | 10.19 |
| dmd-2.111.0 | brettel | double | 29.142 | 39.093 | 47.478 | 9.31 |
| dmd-2.111.0 | vienot | double | 22.198 | 8.470 | 17.508 | 6.88 |
| dmd-2.111.0 | brettel | float | 42.539 | 29.600 | 34.069 | 13.35 |
| dmd-2.111.0 | vienot | float | 19.385 | 7.827 | 10.327 | 9.91 |
| dmd-2.113.0 | brettel | double | 29.172 | 38.958 | 47.560 | 8.46 |
| dmd-2.113.0 | vienot | double | 22.496 | 8.448 | 17.486 | 5.47 |
| dmd-2.113.0 | brettel | float | 42.676 | 31.671 | 36.339 | 14.32 |
| dmd-2.113.0 | vienot | float | 19.366 | 7.829 | 10.311 | 9.94 |

LDC 1.41.0 and both DMD jobs ran on EPYC 7763; LDC 1.43.0 ran on EPYC
9V74. CPU affinity is recorded. Frequency, turbo, SMT, thermals and shared-host
load remain uncontrolled; do not rank compiler versions by absolute timings.

Across all deficiencies, prepared Brettel double takes 23% of the original
time under LDC 1.41.0 and 25–29% under LDC 1.43.0 (about 3.5–4.4x faster).
Its paired C++ gap closes for this workload. Under both DMD versions it instead
takes 133–134% of baseline time. This source form is not a portable overall win.

Prepared Brettel float improves under both compiler families, but large paired
C++ gaps remain. Prepared Viénot improves substantially under DMD while LDC
float is essentially unchanged; LDC double regresses by about 19–24%.
The explicit-inline candidate offers no material LDC improvement and makes
the measured DMD candidates slower than the prepared form.

## Generated-code observations and decision

LDC prepared/inline Brettel batches remove the per-item brettelProbe call and
show packed floating-point arithmetic for both precisions. Prepared and inline
LDC 1.43.0 diagnostic excerpts match in those selected instructions.
Viénot float still lacks the selected packed multiply/add instructions.
D bounds-check failure paths remain visible. DMD prepared Brettel batches
retain a preparation call but remove the original per-item probe call.

These observations support further investigation; they do not establish a
complete causal model. Packed instructions may work on components of one color
and do not prove cross-color loop vectorisation. Removing a call alone does not
guarantee faster execution, as the DMD double regression demonstrates.

**Decision: retain these candidates and measurements; do not promote one
universally or add compiler-specific production forks.** This slice establishes
that coefficient preparation removes a large LDC double Brettel cost, while
explicit source-level matrix inlining does not resolve the float problem.

The production performance gate remains open. The next focused investigation
is float aggregate/loop code generation (including aggregate copies and
matrix selection), then fixed-size Machado table representation where needed.
A controlled consumer-machine replay and independent numerical qualification
are still required before any production decision.
