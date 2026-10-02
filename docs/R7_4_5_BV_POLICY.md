# R7.4.5 — Integrated BV policy candidates

The combined source passes the previous qualification, but a blanket BV
replacement regresses LDC double Viénot. This experiment measures the final
integrated binaries rather than inferring a choice from isolated kernel timings.

| Operation | `bv_portable` | `bv_compiler` |
|---|---|---|
| Brettel float/double | Prepared planes, direct stores, split selection | Same |
| Viénot float | Prepared matrix, direct stores | Same |
| Viénot double under LDC | Original per-item reference form | Same |
| Viénot double under DMD | Original per-item reference form | Prepared matrix, direct stores |
| Viénot double under other compilers | Original form | Original form |

The compiler choice is centralized in `bv_policy.d`: LDC keeps original double
Viénot; DigitalMars uses direct double Viénot. The portable path is retained.
The tested versions are DMD 2.111.0/2.113.0 and LDC 1.41.0/1.43.0. There is no
version threshold or performance promise for future compilers, and no production
compiler fork is accepted by creating these research variants.

Both candidates call the same attributed internal batch functions as their
qualification probes. The original double source form retains per-item
coefficient selection; preparing once and returning a value is a distinct earlier
probe. Allocation, clipping, fast-math and disabled bounds checks are not added.
Machado operations remain unchanged measurement controls.

The extended 5,839-input checks now also run both integrated policies for every
valid deficiency, with separate and exact in-place arrays. CTFE and attributed
callers cover the same functions. The replay snapshots the policy and qualification
source and runs Debug and optimized Release qualification for every compiler,
including consumer runs. Its archives retain those logs and binaries.

The dedicated workflow compares default/direct/split/portable/compiler-selected
over 1024/8191/65536 items and three balanced blocks (54 samples per language/case).
The default replay now supports ten variants, adding these two to the prior eight;
the older pinned XPS protocol remains tied to its eight-variant revision.

Status: prepared; four-compiler measurements and interpretation pending.
Source equivalence, independent scientific model accuracy, performance acceptance
and production/API decisions remain distinct.
