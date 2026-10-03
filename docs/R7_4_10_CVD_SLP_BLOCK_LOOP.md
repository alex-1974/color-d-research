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


## XPS result

The controlled XPS replay completed successfully at research revision
`f963344c4971b3025418c62eb146fbbe254e1f4c` against exact production
revision `bed36eee31fc35d0a8843ba12e55dfd7b12042e7`.

Integrity and methodology gates passed:

- replay status: PASS;
- `files.sha256`: PASS for all 140 recorded files;
- all three binary hashes: PASS;
- exact production source pin: PASS;
- cross-variant/GCC checksum equality: PASS;
- DMD 2.113.0;
- LDC 1.41.0 / LLVM 19.1.7;
- GCC 15.2.0;
- sizes 1024/8191/65536;
- three balanced blocks;
- CPU 0 affinity;
- bounds checks enabled;
- hottest recorded thermal zone about 99 C.

The host was hot, but the effects below are large and highly stable across all
sizes and both deficiencies.

### Aggregate result

Median ratios across sizes and both deficiencies:

| compiler | scalar | variant | speedup vs exact production | D / GCC full |
| --- | --- | --- | ---: | ---: |
| DMD | float | production | 1.000x | 2.639x |
| DMD | float | scalar-replica | 0.412x | 6.408x |
| DMD | float | unroll2 | 0.302x | 8.768x |
| DMD | float | unroll4 | 0.310x | 8.519x |
| DMD | float | unroll4-coefficients | 0.382x | 6.941x |
| DMD | double | production | 1.000x | 1.890x |
| DMD | double | scalar-replica | 0.460x | 4.142x |
| DMD | double | unroll2 | 0.286x | 6.618x |
| DMD | double | unroll4 | 0.290x | 6.511x |
| DMD | double | unroll4-coefficients | 0.374x | 5.069x |
| LDC | float | production | 1.000x | 1.415x |
| LDC | float | scalar-replica | 0.522x | 2.701x |
| LDC | float | unroll2 | 0.509x | 2.839x |
| LDC | float | unroll4 | 0.420x | 3.400x |
| LDC | float | unroll4-coefficients | 0.623x | 2.267x |
| LDC | double | production | 1.000x | 0.925x |
| LDC | double | scalar-replica | 0.995x | 0.930x |
| LDC | double | unroll2 | 0.613x | 1.529x |
| LDC | double | unroll4 | 0.506x | 1.847x |
| LDC | double | unroll4-coefficients | 0.625x | 1.490x |

A speedup below 1.0 means the candidate is slower than exact production.

### Stability across workload size

No block form has a hidden workload-size win.

LDC float median speedup versus production by size:

| variant | 1024 | 8191 | 65536 |
| --- | ---: | ---: | ---: |
| scalar-replica | 0.528x | 0.522x | 0.521x |
| unroll2 | 0.510x | 0.503x | 0.496x |
| unroll4 | 0.420x | 0.421x | 0.414x |
| unroll4-coefficients | 0.623x | 0.624x | 0.627x |

LDC double likewise shows no winning block form. The plain scalar replica is
essentially neutral, while all unrolled forms regress materially.

DMD is worse still: every replica/block form is substantially slower than exact
production across all three sizes.

### Codegen interpretation

The exact LDC production path is already loop-vectorized.

For float and sufficiently large non-overlapping slices, the production
`runVariant` contains a four-color SIMD main loop:

- four AoS RGB colors are gathered into packed vectors;
- packed `mulps/addps` matrix arithmetic is performed;
- results are reinterleaved;
- three contiguous `movups` stores write the 48-byte output block.

This is the same optimizer family identified in R7.4.7. It is not as efficient
as GCC's load/deinterleave schedule, but it is substantially better than the
portable explicit-unroll candidates.

The explicit `unroll4` source shape does not become a compact SLP kernel.
Instead, LDC retains:

- per-lane array-bounds checks for each of the four source/output indices;
- largely scalar per-color `mulss/addss` arithmetic;
- repeated matrix-memory accesses and temporary moves.

The `unroll4-coefficients` variant allows some packed partial operations, but
still carries multiple per-index bounds checks and mixed scalar/packed work.
It destroys the profitable production loop-vectorizer form and is therefore
about 37% slower than production for float.

DMD receives no useful vectorization from the block forms and pays heavily for
the larger source/control-flow shape.

### Final R7.4.10 decision

**Reject all tested portable unrolled scalar block loops for production.**

Rationale:

1. every unrolled candidate materially regresses LDC float;
2. every unrolled candidate materially regresses LDC double;
3. every replica/unrolled candidate materially regresses DMD;
4. the effects are stable across sizes and deficiencies;
5. LDC production is already auto-vectorized, while explicit unrolling prevents
   the profitable loop-vectorizer form;
6. R7.4.8 already rejected manual SIMD;
7. R7.4.9 already rejected simpler call/value-flow rewrites.

For DMD 2.113 and LDC 1.41/LLVM 19, portable matrix-kernel source-shape work is
therefore exhausted for the current AoS `LinearSRgb[]` layout.

The remaining LDC-float gap to GCC should be recorded as a backend
auto-vectorization/load-deinterleave quality limitation, not as evidence for a
different CVD algorithm or another portable matrix-loop rewrite.

LDC double is already at or better than matched GCC and should remain unchanged.

Before generalizing this conclusion to the current supported LDC 1.43 release,
the same exact production/vectorization evidence should be replayed on a
controlled host with LDC 1.43. Shared-runner correctness evidence is not enough
for that performance-evolution claim.
