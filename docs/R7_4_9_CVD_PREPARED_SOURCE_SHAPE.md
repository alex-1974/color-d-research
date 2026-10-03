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
