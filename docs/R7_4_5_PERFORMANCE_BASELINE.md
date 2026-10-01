# R7.4.5 — CVD performance baseline

## Research scope

This benchmark imports the qualified R7.2/R7.3 research source at the checked-out
commit, renames only its experiment entry point and records SHA-256 provenance.
It does not change color-d production source or introduce a production CVD API.

The C++ implementation shares the published coefficients and matches arithmetic
and workload semantics. It is a compiler/code-generation comparison baseline,
not an independent scientific oracle or an externally established best-in-class
implementation. A passing checksum comparison is not a model-accuracy claim.

## Workloads

For float and double:
- Brettel protan/deutan/tritan with per-input plane selection.
- Viénot protan/deutan.
- Machado protan/deutan/tritan prepared-matrix application.
- Machado adjacent-table lookup/interpolation, storing all nine coefficients.
- Machado per-input lookup/interpolation plus color application.

Prepared application uses severity 0.65. The lookup workloads traverse severities
0..1 in 1001 steps. Input RGB is a deterministic runtime LCG corpus inside 0..1;
the timed RGB batches mutate one input between invocations to prevent collapsing
identical calls. Lookup batches shift severity indices between invocations.

## Measurement

AoS value layout; 65536 items; three warm-up batches; nine measured rounds of
16 batches. Forward and reverse case orders give 18 samples per case.
Paired executable order is D/C++ then C++/D. Both executables run on the same
allowed CPU of the same runner. No fast-math or explicit SIMD is requested.
D bounds checks remain enabled. C++ loop indices are bounded by the matching
vector length; it provides no independent invalid-index API contract.

Allocation and coefficient preparation are outside timing. Kernels are noinline
batch calls; outputs are sampled into observable double checksums. Timing
includes one input mutation and one checksum read per RGB batch.
C++ uses GCC -O3 -ffp-contract=off -fno-fast-math.
DMD uses -O -inline -release -boundscheck=on.
LDC uses -O3 -fp-contract=off -release -boundscheck=on.

Before optimized timing, an assertion-enabled D Debug build invokes the existing
fixed-vector and attribute probes and runs the batch harness. The summary
requires finite timings/checksums, the complete 28-case matrix, and D/C++
checksum agreement for every sample.

Checksum tolerance is 48 times the preliminary component gate
(float 2e-6, double 1e-12), reflecting 16 samples of three components.
Report measured checksum differences; these checks are smoke validation, not an
independent vector envelope or an exhaustive batch oracle.

## Interpretation and gate status

Raw rounds, medians, min/max, compiler/build metadata, CPU details, source and
binary hashes are preserved as CI artifacts. Frequency, turbo, thermal state,
SMT and shared-host load are uncontrolled. Ratios compare paired executable
samples within a job. Absolute timings from different compiler jobs must not
be treated as a controlled compiler ranking.

A green workflow establishes that the benchmark builds, the preflight passes
and measurements are available. It is not an automatic performance acceptance.
Material D/C++ gaps require investigation or an explicit documented trade-off;
runner measurements alone cannot close a small performance difference.

The broad production performance gate remains open until results are reviewed,
material gaps resolved or justified, and a controlled consumer-machine replay
is available where needed. Independent reference validation, consumer
composition and API review remain separate gates.

## Replay

From experiments/r7_4_5_cvd_performance:
1. python3 prepare.py
2. Build Debug preflight and optimized D/C++ binaries using the exact commands
   in .github/workflows/r7-4-5-performance.yml.
3. Pin both binaries to one allowed CPU; run forward D/C++ then reverse C++/D.
4. python3 summarize.py

Compiler-specific flags are selected only in the harness. No compiler-specific
implementation fork is introduced by this baseline.

## Recorded baseline — 2026-10-01

Source: `7856b172ad432670f7500d3cad3585fe59ad0170`.
[Run 36903552400](https://github.com/alex-1974/color-d-research/actions/runs/36903552400)
passes all four compiler jobs. Raw samples, summary CSV, preflight output,
platform metadata, default D/C++ binary hashes and kernel call diagnostics are
archived under [data/r7_4_5/run-36903552400](../data/r7_4_5/run-36903552400/).
The complete assembly and generated source are additionally in CI artifacts;
those artifacts expire, whereas the committed measurement records remain.

Every default and supplemental LDC cross-module case reports a maximum
D/C++ sampled checksum difference of zero for float and double.

### Representative paired result

Protan, LDC 1.43.0, AMD EPYC 7763 runner; median ns/item over 18 samples.
Ratios are within this job and workload only; lower is faster.

| Kernel | Scalar | D ns/item | C++ ns/item | D/C++ |
|---|---|---:|---:|---:|
| Brettel | double | 15.916 | 4.197 | 3.79 |
| Brettel | float | 12.907 | 2.205 | 5.85 |
| Viénot | double | 0.936 | 1.226 | 0.76 |
| Viénot | float | 6.993 | 0.785 | 8.90 |
| Prepared Machado | double | 1.258 | 1.226 | 1.03 |
| Prepared Machado | float | 1.500 | 0.788 | 1.90 |
| Machado lookup | double | 8.514 | 5.896 | 1.44 |
| Machado lookup | float | 6.835 | 4.548 | 1.50 |
| Machado lookup + apply | double | 11.657 | 10.365 | 1.12 |
| Machado lookup + apply | float | 9.735 | 10.091 | 0.96 |

DMD has substantial gaps as well. Do not rank the four D compiler jobs by
absolute ns/item: their runner CPUs differ (Xeon 6973P-C, EPYC 9V45 and EPYC
7763), and the DMD float Brettel spread is especially platform/order sensitive.
Min/max and both raw orders are retained, so these effects stay visible.

### Investigation performed

LDC was additionally compiled with `-enable-cross-module-inlining`, then
measured in a fresh D/C++ paired sequence. For LDC 1.43.0 protan, the major
ratios remain essentially unchanged: Brettel float 5.93, Viénot float 8.92.
Enabling cross-module inlining alone does not close these gaps. The experiment
does not justify introducing a compiler-specific production implementation.

Inspection of the default LDC timed batch functions shows:

- Brettel loops call the scalar `brettelProbe` for each item and do not show
  packed floating-point arithmetic in the batch body itself.
- Viénot double and prepared-Machado double have packed arithmetic instructions;
  Viénot float lacks those selected packed arithmetic instructions.
- Machado lookup+apply retains a call to `matrixAtSeverity` per item.
- D bounds-check failure paths remain present.

These are code-generation observations, not a complete causal performance
model. A packed instruction can operate on components of one color rather than
multiple colors; instruction presence alone does not prove loop vectorisation.
The diagnostic excerpts are tied to the measured binaries.

### Decision and remaining qualification

**Benchmark baseline recorded; production performance gate remains open.**

The next focused research slice should test, in isolation:

1. selecting/preparing Viénot coefficients once per batch;
2. preparing Brettel plane matrices once and reviewing the per-item scalar call;
3. preserving a fixed-size Machado table contract through lookup;
4. float aggregate layout and generated loop code;
5. controlled XPS replay of baseline and candidate binaries.

Keep ordinary scalar APIs, `@safe`/`@nogc`, finite/gamut semantics and CTFE
evidence intact. Do not remove safety checks, enable fast-math, invent a bulk
public API or introduce manual SIMD solely to make a benchmark pass.

The C++ baseline uses a fixed 11-element table and an unchecked but bounded
vector loop. The D lookup accepts a dynamically sized borrowed slice and keeps
bounds checks enabled. These representation/safety differences require review
before making a general language-performance claim.

## Follow-up: prepared coefficient candidates

The focused preparation and explicit-arithmetic experiment is complete and
recorded in [R7_4_5_PREPARED_CANDIDATES.md](R7_4_5_PREPARED_CANDIDATES.md).
LDC Brettel double improves substantially, but DMD double regresses and major
float gaps remain. The candidate prepares coefficients inside each timed batch;
the original baseline methodology above describes the default executable.
No universal candidate is accepted and the production performance gate remains
open. Float code generation, fixed-size Machado representation and controlled
consumer-machine replay remain the next investigations.

## Follow-up: direct stores and split selection

The [direct-store investigation](R7_4_5_DIRECT_STORES.md) records a large
portable float improvement under both LDC and DMD. Release binaries now also
check full finite Brettel/Viénot batch components before timing. Residual C++
gaps and LDC Viénot double trade-offs remain; no production gate is closed.
