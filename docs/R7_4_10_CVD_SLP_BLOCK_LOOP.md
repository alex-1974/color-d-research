# R7.4.10 — SLP-friendly scalar block loops for prepared CVD batches

## Motivation

R7.4.7 showed that the remaining LDC-float gap is a vectorizer/load-shuffle
problem for the current AoS RGB loop, not a scalar-arithmetic problem.

R7.4.8 rejected explicit SIMD for production, and R7.4.9 showed that simple
matrix call-boundary/value-flow changes do not close the exact production gap.

This slice tests one final portable source-level strategy before treating the
remaining gap as backend-limited: make multiple independent RGB transforms
visible in one loop iteration so the compiler's SLP vectorizer can act on them.

## Pinned production baseline

Exact color-d commit:

`bed36eee31fc35d0a8843ba12e55dfd7b12042e7`

The production candidate is the real public
`PreparedVienot1999Dichromat.tryApplyInto` operation.

## Compared source shapes

All candidates use production `LinearSRgb!T` AoS storage and the same Viénot
matrices/arithmetic order.

1. `production`
   - exact public prepared API;
2. `scalar-replica`
   - portable scalar matrix loop baseline;
3. `unroll2`
   - two independent RGB transforms per loop iteration;
4. `unroll4`
   - four independent RGB transforms per loop iteration through the same
     inlined scalar write helper;
5. `unroll4-coefficients`
   - four independent transforms with all nine matrix coefficients copied to
     local scalars before the block loop and direct arithmetic in the block.

All block forms retain a scalar tail.

No vector/SIMD types, intrinsics, pointer reinterpretation, unsafe code, or
layout changes are used.

## Contracts

Every D candidate preserves:

- `@safe pure nothrow @nogc`;
- bounds checks enabled;
- exact in-place support;
- multiplication/addition order;
- NaN/infinity/extended-value observability;
- no allocation;
- public AoS layout.

The deterministic finite/special-value corpus is compared against exact
production before timing.

## Benchmark

Default controlled replay:

- float/double;
- protan/deutan;
- n=1024/8191/65536;
- three balanced blocks;
- CPU affinity;
- forward/reverse ordering;
- 11 rounds x 24 repetitions;
- exact production and all portable candidates in one D binary;
- fully optimized R7.4.7 GCC Viénot reference;
- checksum pairing across every candidate and GCC;
- full binary hashes and disassembly capture.

## Questions

1. Does LDC SLP-pack the 4-color source form more efficiently than its current
   AoS loop-vectorized production form?
2. Does 2-color unrolling help double or merely increase code size?
3. Does DMD remain neutral, or does code-size/layout sensitivity dominate?
4. Can a single portable source form materially improve LDC float without
   regressing double or DMD?

## Promotion gate

A candidate is promotable only if it:

- materially improves exact LDC production float across sizes/deficiencies;
- does not materially regress LDC double;
- does not materially regress DMD;
- preserves all semantic/safety contracts;
- has auditable generated code.

If no candidate satisfies these conditions, portable matrix-kernel
source-shape work should stop. The remaining LDC-float gap should then be
recorded as backend-limited for the current AoS API/toolchain generation.

## Status

Implementation and cross-compiler CI/toolchain smoke are complete.

GitHub Actions run 37113943936 passes under DMD 2.113.0 and LDC 1.43.0,
including the exact pinned production source, all five scalar block-loop
variants, special-value/in-place equivalence, matched GCC checksums, result
aggregation, and disassembly capture.

Shared-runner timings remain non-selection evidence.

Controlled XPS evidence is pending.
