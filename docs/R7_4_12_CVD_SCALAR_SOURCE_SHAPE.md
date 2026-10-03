# R7.4.12 — Scalar CVD convenience-call source shape

## Motivation

The prepared/batch CVD architecture is complete and qualified. A separate
question remains for the public scalar convenience functions:

- `brettel1997Dichromat`;
- `vienot1999Dichromat`;
- `machado2009`.

Production currently delegates each scalar call through preparation and a small
Prepared value. This keeps one mathematical path, but exact-production
qualification showed compiler-sensitive scalar codegen. A direct-arithmetic
rewrite was previously rejected because it was not compiler-neutral,
particularly for LDC Machado.

This slice isolates the scalar-call source shape without changing the prepared
API or batch kernels.

## Pinned production baseline

Exact color-d commit:

`bed36eee31fc35d0a8843ba12e55dfd7b12042e7`

The production variant calls the real public scalar functions from that source.

## Candidates

The research replicas preserve the same matrices, tables, interpolation and
operation order.

1. `production`
   - exact public scalar API;
2. `carrier-replica`
   - structure-equivalent prepare -> small carrier -> apply chain;
3. `direct-return`
   - prepare Matrix3/Brettel plan and apply directly without a Prepared carrier;
4. `out-kernel`
   - preparation writes directly to an out Matrix3/plan before apply;
5. `inline-chain`
   - equivalent helper chain with explicit inline qualification;
6. `typed-table`
   - Viénot/Brettel matrices and Machado tables are materialized at compile
     time in the target scalar type, avoiding repeated double -> float/double
     matrix conversion at runtime.

The typed-table candidate is especially relevant to Machado because dynamic
table indexing otherwise forces two matrix materializations before
interpolation.

## Workloads

Two scalar workload classes are retained.

### Fixed configuration

Deficiency is fixed and Machado severity is fixed at 0.65 while the scalar API
is called for each independent color.

This is a codegen diagnostic and historical comparison workload. Public
documentation still recommends the Prepared API for repeated configuration.

### Dynamic parameters

Deficiency varies per color. Machado severity also varies through deterministic
values in [0,1].

This better represents a legitimate scalar convenience workload where
preparation cannot simply be hoisted by the caller.

## Semantic gates

Before timing, every replica is compared with exact production for:

- float and double;
- every supported deficiency;
- finite and extended RGB values;
- NaN and infinities;
- signed zero;
- Machado severities 0, 0.05, 0.1, 0.35, 0.65, 0.9, 0.99 and 1;
- Machado invalid severity below 0, above 1 and NaN;
- CTFE evaluation.

All candidate entry points remain:

`@safe pure nothrow @nogc`

No allocation, SIMD, bounds-check removal, fast-math, API change or changed IEEE
semantics are introduced.

## Benchmark method

The controlled replay builds:

- exact production + replicas under DMD/LDC;
- a matched C++ scalar reference derived from the R7.4.6 reference
  implementation.

Default XPS method:

- sizes 1024, 8191, 65536;
- three balanced blocks;
- forward/reverse ordering;
- CPU affinity;
- four untimed warm-ups;
- five timed rounds;
- three calls per round;
- fixed and dynamic workloads;
- observable checksum equality across every D variant and C++;
- binary hashes;
- full disassembly capture;
- frequency/turbo/SMT/thermal observations.

The primary selection metric is candidate speedup relative to exact production.
D/C++ is retained as the external performance reference.

## CI smoke observation

The first shared-runner smoke is correctness/toolchain evidence only, not a
performance decision. It nevertheless identifies useful candidates for XPS:

- DMD shows a large apparent advantage for typed target-scalar matrices/tables
  in Viénot and Machado;
- LDC Viénot is already essentially insensitive to simple source-shape
  changes;
- LDC Machado shows a split result: typed tables are promising for fixed
  configuration but not obviously for dynamic float input;
- inline-chain is a more stable LDC Machado candidate;
- carrier/out-kernel forms do not show a compelling reason for promotion.

These observations must not be promoted without controlled XPS evidence,
especially because prior research established strong DMD text-layout
sensitivity.

## Decision rule

A production candidate must:

1. materially improve exact production in the workload it claims to optimize;
2. remain stable across 1024/8191/65536 and both workload classes where
   applicable;
3. avoid material regression on the other supported compiler family;
4. preserve scalar CTFE/IEEE/attribute semantics;
5. survive exact candidate-commit replay after promotion into color-d;
6. be justified against matched C++ work.

DMD gains are not accepted from timing alone when generated code indicates an
instruction-identical placement effect.

## Status

Replica implementation, semantic/CTFE preflight, compiler smoke, matched C++
reference and controlled replay implementation are complete.

GitHub Actions run 37117110518 passes under DMD 2.113.0 and LDC 1.43.0,
including:

- exact pinned production source;
- all six scalar source-shape variants;
- finite/extended/NaN/infinity and invalid-severity validation;
- CTFE validation;
- fixed and dynamic scalar workloads;
- matched C++ checksum pairing;
- replay aggregation;
- binary hashing;
- full disassembly capture.

Shared-runner timings are diagnostic only and are not selection evidence.

Controlled XPS selection evidence is pending.


## First controlled XPS result — manifest typed tables

The first controlled XPS replay completed at research revision
`2d11404d6ba9cd0ce24cada508da5729d6dcd4b2` against exact production
revision `bed36eee31fc35d0a8843ba12e55dfd7b12042e7`.

Archive SHA-256:

`a37cbeba3968674bff2dcd63e9bc57f65baf9c65e4f3a56a06115474e4494675`

Integrity/methodology gates passed:

- replay status: PASS;
- 140 recorded file hashes: PASS;
- three binary hashes: PASS;
- exact production source pin: PASS;
- all D/source-shape/GCC observable checksums: PASS;
- DMD 2.113.0;
- LDC 1.43.0 / LLVM 22.1.8;
- GCC 15.2.0;
- sizes 1024/8191/65536;
- three balanced blocks;
- CPU 0 affinity;
- bounds checks enabled;
- hottest recorded thermal zone about 97 C.

Small percentage differences remain approximate because of the thermal state.
The material effects below are stable across all three sizes.

### Machado

The manifest target-scalar `typed-table` candidate is the only candidate that
improves every measured compiler/type/workload combination.

Median speedup versus exact production:

| compiler | scalar | fixed | dynamic |
| --- | --- | ---: | ---: |
| DMD 2.113 | float | **1.245x** | **1.414x** |
| DMD 2.113 | double | **1.182x** | **1.193x** |
| LDC 1.43 | float | **1.570x** | **1.186x** |
| LDC 1.43 | double | **1.485x** | **1.151x** |

The dynamic result is particularly important because it cannot be explained by
simply hoisting fixed deficiency/severity preparation.

For LDC float dynamic Machado, the typed-table candidate reaches about
0.74x matched C++ time, i.e. it is already faster than the matched C++ scalar
reference in this workload.

DMD remains materially slower than C++ even after this improvement, so DMD
Machado still has backend/source lowering headroom.

### Viénot

Viénot exposes a compiler-family split.

DMD 2.113 gains dramatically from removing runtime double -> target-scalar
matrix materialization:

| scalar | fixed typed-table speedup | dynamic typed-table speedup |
| --- | ---: | ---: |
| float | **8.729x** | **8.504x** |
| double | **1.325x** | **1.307x** |

The float effect is stable across all three sizes. Direct-return and
inline-chain are also about 6x faster than exact production, proving that the
production prepare/carrier call chain is not eliminated by DMD.

LDC differs:

- float fixed is effectively neutral;
- float dynamic regresses by about 6%;
- double dynamic improves by about 32%.

Therefore one shared Viénot typed-table path is not currently compiler-neutral.
A DMD-specific capability path may be justifiable only after the required DMD
version-matrix qualification.

### Brettel

No manifest typed-table promotion is justified.

The most serious result is DMD float, where typed-table is only about 0.22x
production throughput. The larger two-matrix plan is expensive when represented
as the current manifest value shape.

Brettel remains on the production carrier/prepared path.

### Codegen finding: manifest arrays are not the final representation

The first XPS result proves that target-scalar constants can remove real work,
but the current `enum` table representation is not suitable as the final DMD
implementation.

For example, DMD 2.113 emits:

- production float Machado `matrixAtSeverity` helpers of about 0x1399 bytes
  each;
- manifest typed `typedMachadoMatrix!float` of about **0x21f1 bytes**.

The latter materializes a large manifest-array source shape on the stack/code
path even though it is still faster because it avoids repeated
double-to-float conversion.

Similarly, typed Viénot still copies a manifest matrix through stack storage
rather than simply indexing immutable target-scalar data.

Therefore the first XPS result is **selection evidence for typed target-scalar
data**, but not yet for the manifest-array implementation.

The next candidate uses module-level `immutable` target-scalar matrices/tables
and ref-backed constant plans so runtime indexing reads directly from read-only
storage. CTFE remains routed through the already validated manifest constants.

This `typed-static` representation must be qualified before any production
promotion.
