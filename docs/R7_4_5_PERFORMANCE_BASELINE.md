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
