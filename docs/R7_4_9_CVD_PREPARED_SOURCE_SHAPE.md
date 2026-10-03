# R7.4.9 — Prepared CVD source/call-shape isolation

## Motivation

R7.4.8 rejected explicit SIMD for production. Its controlled XPS run exposed
a more promising result: the simple non-SIMD research prepared Viénot loop
reached roughly 1.12x GCC for float, whereas the previously qualified exact
production prepared path was around 1.42-1.43x GCC.

This slice isolates that difference without changing mathematics, layout,
bounds checks, or public semantics.

## Pinned production baseline

Exact color-d commit:

`bed36eee31fc35d0a8843ba12e55dfd7b12042e7`

The production candidate is the real public
`PreparedVienot1999Dichromat.tryApplyInto` operation compiled from that source.

## Compared source shapes

All replicas use production `LinearSRgb!T` AoS storage and the same Viénot
matrices and operation order.

1. `production`
   - exact public prepared object + `tryApplyInto`;
2. `free-ref`
   - free matrix loop with matrix passed by `const ref`;
3. `free-value`
   - free matrix loop with matrix passed by value;
4. `free-coefficients`
   - free loop with nine coefficients copied to local scalar values before the
     loop;
5. `member-snapshot`
   - replica prepared struct that snapshots its matrix and calls the free-ref
     loop;
6. `member-backed`
   - replica prepared struct that passes its member matrix directly.

All timed outer variant wrappers are explicitly preserved so call boundaries are
stable enough to compare generated code.

## Contracts

Every D candidate preserves:

- `@safe pure nothrow @nogc`;
- bounds checks enabled;
- exact in-place support;
- mismatch/no-write behavior where applicable;
- multiplication/addition order;
- NaN/infinity/extended-value observability;
- no allocation.

Finite, extended and special-value outputs are compared against exact
production before timing.

## Benchmark

Default controlled replay:

- float/double;
- protan/deutan;
- n=1024/8191/65536;
- 3 balanced blocks;
- 11 rounds x 24 repeats;
- CPU affinity;
- forward/reverse ordering;
- exact production and replicas in the same D binary;
- fully optimized R7.4.7 GCC Viénot reference;
- cross-variant/GCC checksum pairing;
- full binary hashes and disassembly capture.

## Decision rule

Prefer the simplest portable source form that:

1. materially improves exact production under LDC;
2. does not materially regress DMD;
3. remains stable over sizes and both deficiencies;
4. moves the exact D call materially toward GCC;
5. preserves all public semantics and attributes.

No production change is justified from research-loop timing alone. The same
source shape must win when measured directly against the exact production API
in one controlled binary.

## Status

Implementation and cross-compiler CI/toolchain smoke are complete.

GitHub Actions run 37111606255 passes under DMD 2.113.0 and LDC 1.43.0,
including the exact pinned production source, all six source-shape variants,
semantic/special-value/in-place equivalence, GCC checksum pairing, result
aggregation, and disassembly capture.

Shared-runner timings remain non-selection evidence.

Controlled XPS evidence is pending.


## XPS result

The controlled XPS replay completed successfully at research revision
`7680289da1281ad5cdf5e2a4c1f6cc589065ceb6` against exact production
revision `bed36eee31fc35d0a8843ba12e55dfd7b12042e7`.

Integrity and methodology gates passed:

- replay status: PASS;
- `files.sha256`: PASS;
- binary hashes recorded;
- exact production source pin: PASS;
- cross-variant/GCC checksum equality: PASS;
- DMD 2.113.0;
- LDC 1.41.0 / LLVM 19.1.7;
- GCC 15.2.0;
- sizes 1024/8191/65536;
- three balanced blocks;
- CPU 0 affinity;
- bounds checks enabled;
- hottest recorded thermal zone about 97 C.

Small percentage differences remain approximate under this thermal state. The
large negative/neutral results below are stable across sizes and deficiencies.

### Aggregate result

Median ratios across sizes and both deficiencies:

| compiler | scalar | variant | speedup vs exact production | D / GCC full |
| --- | --- | --- | ---: | ---: |
| DMD | float | production | 1.000x | 3.285x |
| DMD | float | free-ref | 1.000x | 3.280x |
| DMD | float | free-value | 1.214x | 2.699x |
| DMD | float | free-coefficients | 0.984x | 3.329x |
| DMD | float | member-snapshot | 1.212x | 2.709x |
| DMD | float | member-backed | 1.250x | 2.629x |
| DMD | double | production | 1.000x | 1.741x |
| DMD | double | free-ref | 1.136x | 1.529x |
| DMD | double | free-value | 1.101x | 1.581x |
| DMD | double | free-coefficients | 1.047x | 1.663x |
| DMD | double | member-snapshot | 1.099x | 1.575x |
| DMD | double | member-backed | 1.131x | 1.534x |
| LDC | float | production | 1.000x | 1.445x |
| LDC | float | free-ref | 0.723x | 2.028x |
| LDC | float | free-value | 1.000x | 1.450x |
| LDC | float | free-coefficients | 1.009x | 1.439x |
| LDC | float | member-snapshot | 1.005x | 1.440x |
| LDC | float | member-backed | 0.725x | 2.008x |
| LDC | double | production | 1.000x | 0.927x |
| LDC | double | free-ref | 0.713x | 1.327x |
| LDC | double | free-value | 1.002x | 0.919x |
| LDC | double | free-coefficients | 1.000x | 0.923x |
| LDC | double | member-snapshot | 1.002x | 0.924x |
| LDC | double | member-backed | 0.705x | 1.330x |

### LDC conclusion

The earlier R7.4.8 observation that a simple research prepared loop could reach
about 1.12x GCC does **not** reproduce when the exact production API and the
replicas are compiled and timed in one controlled binary.

The exact production Viénot float path is about 1.45x GCC here. The only
portable candidate shapes that preserve performance are:

- matrix by value: effectively neutral;
- explicit local coefficients: effectively neutral;
- replica member with local matrix snapshot: effectively neutral.

Passing the matrix/member by `const ref` without the production LDC snapshot
is materially worse, about 2.0x GCC for float and 1.33x for double.

Therefore the R7.4.8 ~1.12x result was a harness/code-placement artifact rather
than an independently transferable source-shape optimization.

No tested portable source/call shape closes the remaining LDC-float gap.

### DMD result is dominated by text placement

Several DMD replicas appear materially faster than exact production, especially
`member-backed` (~1.25x float speedup) and `free-value` (~1.21x).

The generated code prevents interpreting this as an algorithmic/source-shape
win.

For float, the exact production `PreparedVienot1999Dichromat.tryApplyInto`
and the replica `memberBacked` function have the same 67-instruction body in
the success/hot path. After normalizing addresses/symbol names, the only
differences are source-line/data references in the cold array-bounds failure
path. The multiplication/addition loop, loads, stores, bounds checks, and
branches are instruction-identical.

The same is true for the corresponding double hot path.

Yet the replica is about 25% faster for float and 13% faster for double.
This is direct in-binary confirmation of the DMD text-layout/front-end phase
sensitivity already established by R7.4.5.

Consequently the apparent DMD gains of the replicas cannot be promoted as
source-shape improvements from this experiment.

The `free-value` candidate is stable across workload sizes in this binary
(~1.20-1.22x float, ~1.09-1.12x double), but because an instruction-identical
replica in the same binary also shows a similarly large placement-dependent
gain, an exact production candidate would need its own fixed/replayed
qualification before such a change could be attributed to value passing.

R7.4.9 does not justify that production change.

### Final decision

**No production source-shape change is promoted from R7.4.9.**

Rationale:

1. no tested source shape improves LDC float materially;
2. LDC production/local-snapshot shape remains the best simple portable form;
3. LDC double is already at or better than matched GCC;
4. DMD replica speedups are confounded by demonstrated instruction-identical
   text-placement effects;
5. the earlier research-loop ~1.12x LDC result is not reproducible against
   exact production in one binary;
6. explicit SIMD was already rejected by R7.4.8.

The remaining LDC-float gap should therefore be treated as a backend
auto-vectorization/load-shuffle-quality problem for the current AoS public
layout, not as evidence for another simple matrix-call boundary rewrite.
