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


## XPS result — vectorization attribution

The controlled XPS replay completed successfully at research revision
`c968f63b309f789721627b57a25651d03908ab3d` against pinned color-d
production revision
`bed36eee31fc35d0a8843ba12e55dfd7b12042e7`.

Archive integrity, `files.sha256`, all binary hashes, and cross-mode observable
checksum pairing passed. The run used DMD 2.113.0, LDC 1.41.0, GCC 15.2.0,
sizes 1024/8191/65536, three balanced blocks, CPU 0 affinity, and bounds checks
enabled.

The host reached approximately 99 C in the hottest recorded thermal zone, so
small percentage differences remain approximate. The attribution factors below
are large and consistent across sizes/deficiencies.

### Aggregate attribution

Median ratios across sizes and deficiencies:

| scalar/model | GCC no-loop / full | GCC no-SLP / full | GCC no-both / full | LDC no-loop / full | LDC no-SLP / full | LDC no-both / full | DMD / GCC no-both | LDC full / GCC full | LDC no-both / GCC no-both |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| float Viénot | 3.20x | 1.01x | 2.56x | 1.44x | 1.00x | 1.65x | **1.00x** | **1.42x** | **0.91x** |
| float Machado | 3.20x | 1.00x | 2.41x | 1.19x | 0.98x | 1.65x | **1.10x** | **1.43x** | **0.98x** |
| double Viénot | 1.48x | 0.99x | 1.47x | 1.11x | 1.02x | 1.41x | **1.05x** | **0.93x** | **0.92x** |
| double Machado | 1.46x | 0.99x | 1.46x | 1.12x | 1.02x | 1.43x | **1.05x** | **0.91x** | **0.92x** |

### Scalar conclusion

The remaining DMD gap to fully optimized GCC is not primarily a scalar
arithmetic problem.

Against GCC with both loop and SLP vectorization disabled, DMD is:

- Viénot float: essentially parity, median ~1.00x;
- Machado float: ~1.10x;
- Viénot double: ~1.05x;
- Machado double: ~1.05x.

Across individual sizes/deficiencies the DMD/scalar-GCC ratio remains roughly
0.95-1.14x.

LDC with both vectorizers disabled is also excellent scalar code:

- float Viénot ~0.91x scalar GCC;
- float Machado ~0.98x;
- double Viénot/Machado ~0.92x.

Therefore further generic scalar 3x3 source-shape optimization is no longer the
highest-value path.

### GCC vectorization

GCC's useful speedup comes overwhelmingly from the loop vectorizer.

For float, disabling loop vectorization makes the kernel about 3.2x slower.
Disabling SLP alone is essentially neutral. With loop vectorization disabled
but SLP still enabled, GCC can actually be slower than with both vectorizers
disabled, so the SLP-only fallback is not the desired execution form.

For double, loop vectorization is worth about 1.46-1.48x and again SLP alone is
not material.

### LDC vectorization

LDC's loop vectorizer is also the dominant useful pass, but its float gain is
smaller than GCC's:

- float Viénot: full vs no-both speedup ~1.65x;
- float Machado: ~1.65x;
- double Viénot: ~1.41x;
- double Machado: ~1.43x.

For double this is close to GCC's ~1.46-1.47x SIMD gain. Because LDC's scalar
code is already ~8% faster than scalar GCC, full LDC double ends at
~0.91-0.93x GCC full.

For float, GCC obtains ~2.4-2.6x from its useful vectorized form while LDC gets
only ~1.65x. This difference explains essentially the entire remaining
~1.42x LDC-float gap.

### Codegen interpretation

The disassembly confirms that GCC and LDC both use a four-color SIMD main loop
for float, but the generated AoS deinterleave strategy differs substantially.

GCC loads each 48-byte block of four RGB colors with three contiguous
16-byte `movups` loads, then rearranges the values with shuffles and performs
packed arithmetic.

LDC's vectorized float loop reconstructs the same four-color block using many
individual scalar `movss` loads, followed by multiple unpack/shuffle
operations. It also spills/broadcasts prepared coefficients through stack
slots before the vector loop.

Thus LDC is not failing to vectorize; it is producing a materially less
efficient AoS load/deinterleave schedule.

The no-vector LDC kernel is a compact scalar loop with matrix coefficients
already held in registers, which is why it compares favorably with scalar GCC.

### Decision

R7.4.7 resolves the attribution question:

1. DMD scalar prepared-matrix arithmetic is already at or near scalar C++
   performance.
2. DMD's gap to fully optimized GCC is primarily the absence of equivalent
   SIMD auto-vectorization.
3. LDC double vectorization is already competitive with GCC.
4. LDC float's remaining gap is primarily vectorizer/load-shuffle quality for
   AoS RGB data, not scalar arithmetic or CVD model structure.
5. Further generic scalar algorithm changes are not justified by this evidence.

The next research slice should therefore qualify an explicit SIMD strategy at
the existing internal batch boundary, while preserving:

- the public AoS `LinearSRgb!T[]` API;
- scalar/reference fallback;
- IEEE semantics;
- bounds/safety contracts;
- no allocation;
- runtime CPU feature correctness.

Manual SIMD must be evidence-driven and independently qualified; R7.4.7 does
not itself authorize promotion.
