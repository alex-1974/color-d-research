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

Replica implementation, semantic/CTFE preflight, compiler smoke, C++ reference
and controlled replay implementation are complete. Replay CI smoke and XPS
selection evidence are pending.
