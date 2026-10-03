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


## Second controlled XPS result — static typed runtime tables

The second controlled replay completed at research revision
`723e6dcffde8866394bc176357ccaeb9d0584c4c`.

Archive SHA-256:

`1f3ddd17fe6f617117195cfb048c67279f96319cdc6460979632ded0ff25edbe`

Integrity and qualification gates passed:

- replay status: PASS;
- 316 recorded file hashes: PASS;
- 7 binary hashes: PASS;
- all six compiler preflights: PASS;
- exact production source pin: PASS;
- cross-variant/matched-C++ observable checksum equality: PASS;
- DMD 2.111.0 / 2.112.1 / 2.113.0;
- LDC 1.41.0 / 1.42.0 / 1.43.0;
- GCC 15.2.0;
- sizes 1024/8191/65536;
- three balanced blocks;
- CPU 0 affinity;
- bounds checks enabled.

The hottest recorded thermal zone reached about 100 C. Small percentage
differences remain approximate, but the Machado effects are large and
directionally stable across every compiler and workload size.

### Machado typed-static result

`typed-static` is the first scalar candidate that improves Machado across the
entire current supported compiler matrix and also across the older diagnostic
compiler pair.

Median speedup versus exact production:

| compiler | float fixed | float dynamic | double fixed | double dynamic |
| --- | ---: | ---: | ---: | ---: |
| DMD 2.111 | 2.120x | 1.366x | 4.606x | 4.530x |
| DMD 2.112.1 | **2.189x** | **1.608x** | **5.076x** | **4.772x** |
| DMD 2.113 | **2.214x** | **1.375x** | **4.817x** | **4.556x** |
| LDC 1.41 | 1.536x | 1.178x | 1.486x | 1.138x |
| LDC 1.42 | **1.499x** | **1.233x** | **1.568x** | **1.171x** |
| LDC 1.43 | **1.515x** | **1.233x** | **1.444x** | **1.173x** |

The current supported matrix is DMD 2.112.1/2.113.0 and LDC 1.42/1.43.
Every supported combination improves materially.

The dynamic workload is the key production signal:

- DMD 2.112.1 float: about +61%;
- DMD 2.113 float: about +38%;
- DMD 2.112.1 double: about 4.77x;
- DMD 2.113 double: about 4.56x;
- LDC 1.42/1.43 float: about +23%;
- LDC 1.42/1.43 double: about +17%.

All three workload sizes preserve the improvement direction.

### Code-size result

The static runtime representation also solves the code-shape problem exposed by
the first manifest-table experiment.

Under DMD 2.113:

- production float `matrixAtSeverity`: about 0x1399 bytes per table
  specialization;
- manifest typed `typedMachadoMatrix!float`: about 0x21f1 bytes;
- static typed `typedStaticMachadoMatrixRuntime!float`: about **0x51e bytes**.

For double, the static typed helper is about 0x550 bytes instead of the
manifest typed helper's approximately 0x239c bytes.

Under LDC 1.42/1.43 both typed forms are already compact; the static runtime
helper remains approximately 0xfa bytes for float and 0x15b bytes for double.

Thus `typed-static` both improves performance and removes the DMD manifest
table code-size pathology.

### Viénot remains rejected as a shared static-table change

The static representation is not a general license to convert every CVD model.

Important counterexamples:

- DMD 2.112.1 float Viénot `typed-static` regresses to only about
  0.56-0.58x production throughput;
- LDC 1.42 double dynamic Viénot regresses to about 0.42x;
- LDC 1.43 double dynamic Viénot regresses to about 0.65x.

The manifest typed-table shape remains extremely fast on DMD Viénot, but it is
not compiler-neutral and the static-data representation does not preserve that
benefit across the supported matrix.

Viénot therefore stays unchanged in production.

### Brettel remains rejected as a shared static-table change

Brettel also remains compiler/workload sensitive.

Although LDC and some DMD double/fixed cases improve, DMD float dynamic remains
a severe regression:

- DMD 2.112.1 float dynamic: about 0.38x production throughput;
- DMD 2.113 float dynamic: about 0.24x.

Brettel therefore stays unchanged in production.

### R7.4.12 selection decision

Only Machado satisfies the production selection gate.

The recommended production shape is:

1. retain the existing public `machado2009` -> preparation ->
   `PreparedMachado2009.apply` semantic path;
2. retain the existing prepared/batch API and interpolation arithmetic;
3. add target-scalar runtime Machado tables in immutable read-only storage;
4. at runtime, index/interpolate those target-scalar tables directly;
5. at CTFE, continue using the existing manifest double tables and the already
   qualified conversion path;
6. do not change Viénot or Brettel.

This is a data-materialization optimization, not a second CVD algorithm.

The exact color-d candidate must still pass the normal production workflow,
supported compiler matrix and an independent exact-candidate replay before
R7.4.12 is closed.


## First exact production-candidate replay — partial transfer, rejected

The first exact color-d candidate was replayed at production revision
`e4a354247cbd8cd4c3c2b264a25e317d9e659333`.

Archive SHA-256:

`c4c9d83e1ce00e363403e9b7d3877952f8caf3d88b2b0f23d24946ac43b46aa6`

Qualification gates passed:

- exact candidate source pin: PASS;
- all recorded file hashes: PASS;
- all binary hashes: PASS;
- DMD 2.112.1 / 2.113.0 preflight: PASS;
- LDC 1.42 / 1.43 preflight: PASS;
- semantic/IEEE/invalid-severity/CTFE checks: PASS;
- cross-variant/matched-C++ observable checksums: PASS.

However, the performance transfer gate did **not** pass.

The first candidate moved target-scalar immutable Machado tables into production,
but retained the scalar convenience chain:

`machado2009 -> tryPrepareMachado2009 -> PreparedMachado2009.apply`.

Within the same exact-candidate binary, the direct `typed-static` replica
remained materially faster under LDC:

| compiler | scalar | workload | typed-static speedup vs candidate production |
| --- | --- | --- | ---: |
| LDC 1.42 | float | fixed | 1.458x |
| LDC 1.42 | float | dynamic | 1.097x |
| LDC 1.42 | double | fixed | 1.516x |
| LDC 1.42 | double | dynamic | 1.180x |
| LDC 1.43 | float | fixed | 1.466x |
| LDC 1.43 | float | dynamic | 1.108x |
| LDC 1.43 | double | fixed | 1.489x |
| LDC 1.43 | double | dynamic | 1.174x |

Thus the data representation transferred only part of the research gain.
The remaining carrier/preparation call chain is still observable in scalar
codegen.

DMD timings in this exact-candidate binary again show strong placement-sensitive
behavior, including cases where candidate production appears faster than the
standalone replica. Because R7.4.5/R7.4.9 already proved instruction-identical
DMD hot paths can differ materially by text placement, those values are not
used to override the LDC transfer failure.

### Revised production shape

The corrected production candidate still uses one mathematical matrix-selection
path:

1. private `machadoMatrixAtSeverity` performs the deficiency selection and
   severity interpolation;
2. `tryPrepareMachado2009` wraps that matrix in
   `PreparedMachado2009` for repeated use;
3. scalar `machado2009` applies that same matrix directly, avoiding the
   temporary Prepared carrier.

This is not a second CVD algorithm. Matrix selection/interpolation remains
shared; only the scalar carrier is removed.

Revised color-d candidate head:

`241e0f893040baa9bda8669c0299c9ffd9d25b5b`

The revised candidate must pass normal CI and a second exact-candidate replay
before merge.


## Second exact production-candidate replay — accepted

The revised production candidate was replayed at color-d revision
`241e0f893040baa9bda8669c0299c9ffd9d25b5b`.

Archive SHA-256:

`181db3294a80753e5fe4eb85e07b01f96ed3391fdecb89584e1c5258e4e58d90`

Qualification gates passed:

- replay status: PASS;
- 228 recorded file hashes: PASS;
- all five binary hashes: PASS;
- exact candidate source pin: PASS;
- DMD 2.112.1 / 2.113.0 preflight: PASS;
- LDC 1.42 / 1.43 preflight: PASS;
- semantic/IEEE/invalid-severity/CTFE checks: PASS;
- cross-variant/matched-C++ observable checksums: PASS;
- sizes 1024/8191/65536;
- three balanced blocks;
- bounds checks enabled.

The hottest recorded thermal zone reached about 100 C. Small percentage
differences are therefore approximate.

### Production transfer

Compared with the original exact-production baseline replay, the revised
production path is faster on every supported compiler/type/workload aggregate.

Median production speedup versus the original baseline:

| compiler | float fixed | float dynamic | double fixed | double dynamic |
| --- | ---: | ---: | ---: | ---: |
| DMD 2.112.1 | 3.28x | 8.04x | 8.90x | 7.43x |
| DMD 2.113.0 | 2.10x | 5.00x | 4.08x | 3.96x |
| LDC 1.42.0 | 1.34x | 1.37x | 1.50x | 1.42x |
| LDC 1.43.0 | 1.37x | 1.39x | 1.37x | 1.34x |

The DMD factors include the already documented text-placement sensitivity and
should not be interpreted as purely algorithmic speedup factors. The important
gate result is that no supported DMD workload regressed, while the LDC transfer
is stable and material.

The improvement direction is preserved across all three workload sizes. Under
LDC 1.43 the production speedup is approximately:

- float fixed: 1.37x;
- float dynamic: 1.39x;
- double fixed: 1.37x;
- double dynamic: 1.34x.

### Production versus standalone typed-static replica

The revised production path no longer needs to match the standalone research
replica instruction-for-instruction to pass the promotion gate. The important
question is whether the accepted production source shape transfers the intended
optimization without regression.

Under LDC dynamic scalar workloads, revised production is actually faster than
the standalone `typed-static` replica:

- LDC 1.42 float dynamic: replica speedup vs production 0.876x;
- LDC 1.42 double dynamic: 0.869x;
- LDC 1.43 float dynamic: 0.869x;
- LDC 1.43 double dynamic: 0.887x.

That is, production is about 13-15% faster in the legitimate dynamic scalar
workload.

For the fixed-configuration diagnostic, the standalone replica remains roughly
4-16% faster than production depending on scalar/compiler. This is not a
regression versus the original production baseline, and fixed repeated
configuration is explicitly the workload for which callers should use the
Prepared API.

DMD same-binary replica ratios remain dominated by the text-layout effect
already established by R7.4.5/R7.4.9. They are not used as an independent
selection metric.

### Final R7.4.12 decision

The revised Machado production candidate passes the performance-transfer gate.

Accepted production changes:

1. target-scalar immutable Machado runtime tables;
2. one shared private matrix-selection/interpolation function;
3. Prepared construction wraps that matrix for reuse;
4. scalar `machado2009` applies the same selected matrix directly.

Rejected / unchanged:

- Viénot remains unchanged;
- Brettel remains unchanged;
- no compiler-version fork;
- no public API change;
- no SIMD;
- no weakened CTFE, IEEE, allocation or safety contract.

R7.4.12 therefore supports merging color-d PR #172 after normal CI remains
green.
