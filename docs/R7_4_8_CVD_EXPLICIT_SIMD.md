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
