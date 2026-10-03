# R7.4.8 — Explicit SIMD for prepared CVD matrix batches

## Motivation

R7.4.7 established that the remaining Viénot/Machado matrix gap is a SIMD
problem rather than a scalar-algorithm problem.

On the XPS:

- DMD is approximately 1.00-1.10x scalar GCC;
- LDC without vectorization is approximately 0.91-0.98x scalar GCC;
- GCC gains approximately 2.4-2.6x on float from its useful vectorized form;
- LDC gains only approximately 1.65x on float;
- LDC double reaches full GCC performance because its scalar baseline and
  two-lane vectorization are both strong.

This slice asks whether an explicit, auditable 128-bit SIMD kernel can improve
the public AoS workload without changing the public API or CVD mathematics.

## Candidates

Three D execution shapes are compared:

1. `prepared`
   - current prepared research/reference matrix loop;
2. `gather-simd`
   - scalar AoS lane gathering/scattering around packed arithmetic;
3. `block-simd`
   - contiguous 48-byte AoS blocks for four float RGB values or two double RGB
     values;
   - explicit deinterleave;
   - packed 3x3 matrix arithmetic;
   - explicit reinterleave;
   - contiguous block stores;
   - scalar tail.

Float uses `float4`; double uses `double2`.

The matched C++ reference is the fully optimized R7.4.7 3x3 matrix oracle.

## AoS mapping

Four float RGB colors occupy three contiguous 128-bit blocks:

~~~text
A = [r0, g0, b0, r1]
B = [g1, b1, r2, g2]
C = [b2, r3, g3, b3]
~~~

The explicit shuffle network reconstructs:

~~~text
R = [r0, r1, r2, r3]
G = [g0, g1, g2, g3]
B = [b0, b1, b2, b3]
~~~

and reverses that mapping after the matrix operation.

Two double RGB colors analogously use:

~~~text
A = [r0, g0]
B = [b0, r1]
C = [g1, b1]
~~~

All mappings were independently symbolically checked before implementation.

## Compiler bindings

### DMD

DMD 2.113 uses `core.simd` XMM intrinsics for shuffles and unaligned loads.
The store problem is important:

- `core.simd.storeUnaligned` is not declared `pure` in DMD druntime;
- static-array stores preserve the pure API but DMD lowers them through poor
  x87-heavy code;
- a fixed-size `memcpy` experiment remains pure, but DMD emits three
  `memcpy@plt` calls inside each four-color hot-loop iteration.

The fixed-size memcpy variant is therefore retained only as research evidence,
not as a production recommendation.

### LDC

LDC 1.43 uses the same `core.simd` vector types plus:

- `ldc.simd.shufflevector`;
- pure LLVM-backed `loadUnaligned`;
- pure LLVM-backed `storeUnaligned`.

This allows the same semantic shuffle network while using compiler-native LLVM
vector primitives.

## CI codegen evidence

DMD and LDC both pass:

- build;
- deterministic finite-corpus equivalence;
- extended/special-value equivalence;
- exact in-place equivalence;
- `@safe pure nothrow @nogc` caller contract;
- n=1024 execution smoke;
- codegen capture.

LDC `block-simd` float codegen has the intended main-loop form:

- three contiguous `movups` loads for four AoS RGB colors;
- compact shuffle/deinterleave sequence;
- packed `mulps/addps` matrix arithmetic;
- compact reinterleave;
- three contiguous `movups` stores.

This is materially closer to GCC's R7.4.7 vector loop than LDC's automatic
vectorization, which used many scalar `movss` gathers.

DMD `block-simd` also produces the intended three contiguous loads, but its
backend spills most intermediate vectors to the stack. Store experiments are
worse still: the pure fixed-size memcpy form remains external calls in the hot
loop. Shared-runner timings already show the current DMD explicit-SIMD
candidate slower than its prepared scalar baseline; controlled XPS still
records the final evidence.

## Safety and semantic contract

The SIMD candidates preserve:

- identical per-lane multiplication/addition order;
- no FMA requirement;
- no fast-math;
- NaN/infinity observability;
- extended values;
- exact in-place operation;
- scalar tail;
- no allocation.

Pointer reinterpretation needed for contiguous block access is isolated in
small `@trusted pure nothrow @nogc` helpers with static layout assertions.

The public research entry points remain `@safe pure nothrow @nogc`.

## Qualification replay

`replay.py` performs:

- DMD and LDC builds;
- semantic preflight;
- GCC full build;
- sizes 1024/8191/65536 by default;
- three balanced blocks;
- forward/reverse order;
- CPU affinity;
- 11 rounds x 24 repetitions;
- checksum equality across every D variant and GCC;
- binary hashes;
- full disassembly capture;
- host/frequency/thermal observations.

Primary result columns are:

- SIMD speedup versus prepared D;
- D variant / GCC full.

## Promotion criteria

No explicit SIMD path is promoted merely because it compiles.

A candidate must:

1. pass all semantic/in-place checks;
2. materially improve the current compiler's prepared path;
3. improve or preserve performance across representative sizes;
4. move D materially toward GCC full performance;
5. retain a scalar/reference fallback;
6. preserve public safety/purity/allocation contracts;
7. have auditable generated load/shuffle/store code.

A compiler-specific SIMD path is acceptable only if workspace compiler-specific
optimization rules are satisfied by the final evidence.

## Current status

Cross-compiler SIMD implementation, semantic qualification, codegen capture,
and replay smoke are complete.

GitHub Actions run 37110151919 passes under both DMD 2.113.0 and LDC 1.43.0,
including:

- build;
- special/extended-value and exact in-place preflight;
- n=1024 candidate smoke;
- disassembly capture;
- full replay/parser/checksum smoke against GCC.

Shared-runner timing remains non-selection evidence.

Controlled XPS qualification over 1024/8191/65536 and three balanced blocks is
pending.


## XPS qualification result

The controlled XPS replay completed successfully at research revision
`e859effe763dcbd680f7785ced2e14fee4a9f06a`.

Integrity and methodology gates passed:

- replay status: PASS;
- `files.sha256`: PASS for every recorded file;
- binary hashes recorded;
- cross-variant D/GCC observable checksum equality: PASS;
- DMD 2.113.0;
- LDC 1.41.0 / LLVM 19.1.7;
- GCC 15.2.0;
- sizes 1024/8191/65536;
- three balanced blocks;
- CPU 0 affinity;
- bounds checks enabled;
- no fast-math;
- hottest recorded thermal zone about 97 C.

The thermal state makes very small percentage differences approximate, but the
rejected effects below are large and directionally stable.

### Aggregate result

Median ratios across sizes and both deficiencies:

| compiler | scalar | model | gather speedup vs prepared | block speedup vs prepared | prepared / GCC | gather / GCC | block / GCC |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| DMD | float | Viénot | 0.22x | **0.61x** | 2.72x | 12.19x | 4.34x |
| DMD | float | Machado | 0.25x | **0.66x** | 3.01x | 12.27x | 4.35x |
| DMD | double | Viénot | 0.20x | **0.49x** | 1.62x | 7.93x | 3.38x |
| DMD | double | Machado | 0.20x | **0.47x** | 1.58x | 7.76x | 3.34x |
| LDC | float | Viénot | 0.56x | **0.82x** | 1.12x | 2.01x | 1.37x |
| LDC | float | Machado | 0.72x | **1.06x** | 1.45x | 2.01x | 1.35x |
| LDC | double | Viénot | 0.70x | **0.85x** | 0.83x | 1.17x | 0.99x |
| LDC | double | Machado | 0.80x | **0.96x** | 0.93x | 1.16x | 0.99x |

A speedup below 1.0 means the explicit SIMD candidate is slower than the
prepared reference.

### DMD

Both explicit SIMD forms are decisively rejected.

The block-SIMD path is approximately:

- 0.59-0.64x prepared throughput for Viénot float;
- 0.65-0.71x for Machado float;
- 0.45-0.54x for Viénot double;
- 0.45-0.51x for Machado double.

The gather-SIMD form is substantially worse again.

The controlled measurements agree with the generated-code diagnosis: DMD's
backend does not keep this explicit vector dataflow compact. The pure-compatible
store forms also prevent a competitive three-vector-store loop.

There is no evidence for a DMD explicit-SIMD production path from this slice.

### LDC float

The result is model-dependent and therefore also fails the production gate.

For Viénot, block SIMD is consistently slower than the prepared reference:

- n=1024: about 0.81x prepared throughput;
- n=8191: about 0.82x;
- n=65536: about 0.81x.

For Machado, block SIMD gives only a modest and stable improvement:

- n=1024: about 1.08x;
- n=8191: about 1.06x;
- n=65536: about 1.07x.

Even the Machado candidate remains roughly 1.31-1.41x slower than full GCC.

Therefore a shared LDC-float explicit-SIMD kernel is not justified. A
model-specific manual-SIMD branch for only ~6% median gain would add substantial
mechanism and maintenance cost while failing to solve the larger performance
question.

### LDC double

Explicit SIMD is unnecessary and regressive.

The existing prepared reference is already faster than or near GCC:

- Viénot prepared median: about 0.83x GCC;
- Machado prepared median: about 0.93x GCC.

Block SIMD moves both to about 0.99x GCC but is slower than the D prepared
reference:

- Viénot block SIMD: about 0.85x prepared throughput;
- Machado block SIMD: about 0.96x.

The compiler-generated double path remains preferable.

### Important source-shape observation

The negative SIMD result exposes a more valuable lead.

Within this same controlled replay, the non-SIMD prepared research loop reaches:

- LDC Viénot float: median about **1.12x GCC**;
- LDC Machado float: about **1.45x GCC**;
- LDC Viénot double: about **0.83x GCC**;
- LDC Machado double: about **0.93x GCC**.

The previously qualified exact production replay measured LDC Viénot float
near 1.42-1.43x GCC after the prepared-state correction.

The R7.4.8 prepared reference and production public prepared call therefore
still differ materially in optimizer-visible source/call shape even though the
3x3 arithmetic is equivalent.

This discrepancy is more promising than manual SIMD: the research prepared
Viénot float form is already much closer to C++ than the explicit block-SIMD
candidate (about 1.12x vs 1.37x GCC).

The next slice should reproduce these source/call shapes side-by-side against
the exact production API and generated code before any SIMD promotion is
reconsidered.

### Final R7.4.8 decision

**Reject explicit SIMD for production from this slice.**

Reasons:

1. DMD regresses materially for every tested type/model/workload.
2. LDC Viénot float regresses materially and consistently.
3. LDC Machado float improves only about 6% and remains materially behind GCC.
4. LDC double is already better with compiler-generated code.
5. The portable prepared research source shape exposes a larger optimization
   opportunity than the explicit SIMD path.
6. Maintaining manual ISA-sensitive code is not justified while a simpler
   source-shape discrepancy remains unresolved.

The explicit SIMD implementation remains valuable research evidence and a
future reference if compiler-generated vectorization cannot close the remaining
gap. It is not an accepted production mechanism.
