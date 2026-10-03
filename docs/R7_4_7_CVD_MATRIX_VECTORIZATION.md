# R7.4.7 — CVD matrix vectorization attribution

## Question

After the prepared CVD API and the compiler-family prepared-state fix were
promoted to color-d, the remaining exact-production gap is concentrated in the
generic 3x3 prepared matrix kernel:

- DMD remains materially behind the fully optimized GCC reference;
- LDC double is at or slightly ahead of GCC;
- LDC float remains about 1.4x slower than GCC.

Generated code provides an important clue: GCC vectorizes the matched AoS
matrix loop, while DMD emits a scalar loop. LDC vectorizes the loop, but its
float code is more shuffle-heavy than GCC.

This slice attributes the remaining gap before any manual SIMD or further
source-shape specialization is considered.

## Pinned production source

All D builds snapshot the exact merged color-d production revision:

`bed36eee31fc35d0a8843ba12e55dfd7b12042e7`

The measured public production operations are:

- `PreparedVienot1999Dichromat.tryApplyInto`;
- `PreparedMachado2009.tryApplyInto`.

Both deficiencies, float/double, and the same fixed Machado severity 0.65 are
included.

## Compiler modes

### DMD

- normal optimized production build.

DMD is not given a synthetic vectorization-off variant because the inspected
production kernel is already scalar.

### LDC

The same production source is built as:

- full optimization;
- loop vectorization disabled;
- SLP vectorization disabled;
- both loop and SLP vectorization disabled.

LDC exposes these controls directly as
`-disable-loop-vectorization` and `-disable-slp-vectorization`.

### GCC

The matched C++ source is built as:

- full `-O3`;
- `-fno-tree-loop-vectorize`;
- `-fno-tree-slp-vectorize`;
- both disabled.

All C++ modes retain `-ffp-contract=off -fno-fast-math`.

## Primary attribution metrics

For each scalar/model pair, the replay reports:

- GCC no-loop / full;
- GCC no-SLP / full;
- GCC no-both / full;
- LDC no-loop / full;
- LDC no-SLP / full;
- LDC no-both / full;
- DMD / GCC no-both;
- LDC full / GCC full;
- LDC no-both / GCC no-both.

The decisive interpretations are:

1. **DMD near GCC-no-both**: the DMD scalar kernel is already close to scalar
   C++, so the remaining DMD/full-GCC gap is mainly missing SIMD rather than
   poor scalar arithmetic.
2. **DMD materially slower than GCC-no-both**: portable scalar source-shape
   work remains justified before SIMD.
3. **LDC no-both near GCC-no-both but LDC full behind GCC full**: the float
   gap is primarily vectorizer/codegen quality.
4. **LDC no-both also behind**: there is still scalar/alias/source-shape work
   to do.
5. Loop-vs-SLP deltas show which backend pass provides the useful SIMD form.

## Method

Default controlled replay:

- sizes 1024, 8191, 65536;
- three balanced blocks;
- CPU affinity;
- forward/reverse case ordering;
- 4 warm-up batches;
- 11 timed rounds;
- 24 batch repetitions per round;
- no timed allocation;
- bounds checks enabled;
- identical deterministic input corpus;
- observable checksum matching across every compiler mode;
- compiler/build/host/thermal metadata retained;
- binary hashes and full disassembly retained.

Shared CI runs are correctness/toolchain smoke only. XPS timing is required for
performance conclusions.

## Non-goals

This slice does not introduce:

- manual SIMD;
- vector types/intrinsics;
- alignment or padding workarounds;
- fast-math;
- bounds-check disabling;
- public API changes;
- a new scientific CVD algorithm.

## Decision gate

Manual SIMD or a lower-level compiler-specific kernel is considered only if the
attribution demonstrates that a material gap remains after the scalar baseline
has been fairly separated from auto-vectorization benefit.

## Status

Implementation and CI/toolchain smoke are complete.

GitHub Actions run 37108441317 passed under both DMD 2.113.0 and LDC 1.43.0.
The smoke compiled and executed:

- the exact production D path;
- all four GCC vectorization modes;
- all four LDC vectorization modes in the LDC job;
- checksum-equivalent outputs;
- summary and attribution generation.

Shared-runner timing is not used as performance evidence. Controlled XPS
evidence is pending.
