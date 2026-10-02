# R7.4.4 — CVD attribute and allocation qualification

## Scope

Research branch: `research/163-cvd-transformations`.
This qualifies research arithmetic, not a released production API.

The two existing experiments now compile and call explicitly attributed
`@safe pure nothrow @nogc` paths for both `float` and `double`:

- Brettel: protan, deutan and tritan; both separation-plane paths exercised by primaries.
- Viénot: protan and deutan only.
- Machado: all three tables, severity endpoints, every reference point and
  representative interpolated points.

Representative calls are also evaluated at CTFE and compared with runtime
results. These comparisons establish capability, not independent model accuracy
or exhaustive CTFE equivalence.

## Allocation evidence

The core paths use fixed-size value structs, fixed-size arrays and borrowed
table slices. They call arithmetic helpers only; no native allocator, `new`,
dynamic array growth or allocating I/O is present in the qualified call graph.
Compiler enforcement of `@nogc` prevents GC allocations in these paths.

A real defect was exposed: slicing a manifest `enum` array in a runtime
`@nogc` function materialized an allocating array literal. Machado wrappers now
assign the manifest data to explicitly fixed-size local arrays before slicing.
This is research evidence, not a final production table-storage decision;
R7.4.5 must measure lookup and batch costs before that decision.

Diagnostic output, the general experiment harness and failure reporting are
outside the allocation claim. There is no general claim that `@nogc` alone
excludes native allocation.

## Validation integrity

The previous general workflow uses `--build=release`, disabling runtime
assertions. Its green results cannot establish assertion-based runtime gates.
Run 36858568218 checked out `b7ab15a73d1e62f9c126735881739764f9264add`,
before the non-finite and attribute additions.

The scoped `r7-4-4-qualification.yml` workflow:

1. records the checked-out SHA and toolchain versions;
2. requires a deliberate control program to fail with a runtime `AssertError`;
3. runs both experiments in Debug with runtime assertions active;
4. also compiles and runs Release as a smoke check;
5. preserves both outputs.

A pre-existing invalid identifier (`out`, a D keyword) in the non-finite probe
was corrected without changing its mathematical test.

## Limits and next step

Full independent double/reference envelopes, complete model-specific
non-finite contracts, comprehensive CTFE interval coverage, performance,
consumer composition and production API review remain separate promotion gates.

R7.4.5 is next: measure semantically equivalent model workloads and distinguish
table lookup/interpolation from application of a prepared matrix. Preserve
compiler, precision, build, machine, workload and distribution evidence.

## Verified result — 2026-10-01

Qualified source commit: `5d7dc28983b600cb77bf62d8131b0033e5221e82`.

[CI run 36859987457](https://github.com/alex-1974/color-d-research/actions/runs/36859987457):
all eight jobs passed.

| Compiler | Brettel / Viénot Debug + Release | Machado Debug + Release |
|---|---|---|
| DMD 2.111.0 | PASS | PASS |
| LDC 1.41.0 | PASS | PASS |
| DMD 2.113.0 | PASS | PASS |
| LDC 1.43.0 | PASS | PASS |

Every job passed the runtime assertion control. Debug is the numerical
validation evidence; Release is compile/execution smoke evidence.
The Machado float-versus-rounded-double component difference remains
`1.19209e-07`; this metric does not measure the full precision error of
severity interpolation or error relative to an independent oracle.
