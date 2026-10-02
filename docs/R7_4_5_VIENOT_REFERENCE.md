# R7.4.5 — Viénot reference-bound input iteration

## Question

The [indexed source-shape comparison](R7_4_5_VIENOT_SHAPES.md) improves DMD
Viénot, but its generated inner loops still check each of r/g/b indexed input
loads separately. The remaining measured CI gap is about 2.8–3.0 times C++
for float and 1.8–1.9 times for double. An input reference should let the
compiler traverse an RGB element without either the original aggregate copy
or three independent indexed accesses.

## Isolated probe

`bv_vienot_ref` calls `referenceVienotBatch`. It prepares the same runtime
typed matrix once, iterates `foreach (i, ref p; input)`, snapshots r/g/b
before any output write, and calls the same direct-store helper as the
indexed variant. All nine products and six additions retain their existing
precision and grouping, including IEEE-significant zero terms.

This is a source-shape experiment. `@safe pure nothrow @nogc`, CTFE, exact
in-place calls, bounds-checked builds, AoS storage, deficiency selection and
the C++ reference are retained. Partial overlap is not a newly promised
contract. No selected compiler policy or production API is changed.

The qualification corpus checks the new probe alongside the existing probes:
5,839 inputs per scalar covering finite extended-range values, NaN, infinity,
signed-zero inputs and subnormals. Batch tests cover lengths 0, 1, 2, 3, 7, 8,
9, 31, 32, 33 and 65, separate output, exact in-place operation, and untouched
suffixes. CTFE and runtime drivers enforce the existing attribute set.
The preliminary component envelope remains source-equivalence evidence, not
an independent scientific model oracle or signed-zero-bit contract.

## Comparison and evidence

The four-compiler qualification workflow compares default, selected policy,
indexed input, and reference-bound input over sizes 1024, 8191 and 65536,
three balanced forward/reverse blocks: 336 pooled cases per compiler and
54 samples per language/case. Unchanged Brettel/Machado controls remain in
the report. The general smoke exercises all thirteen replay variants over
two sizes/two blocks: 728 pooled cases per compiler.

The codegen inspector retains the fixed selected-policy, indexed, reference
and C++ float/double Viénot bodies, including their binary hashes. The raw
archive inspector accepts the new qualification line while retaining old
archive compatibility, and reconstructs the complete raw timing reports
plus codegen evidence without executing archived binaries.

Results are pending this probe's CI matrix. Check whether the three indexed
input bounds checks disappear, whether arithmetic remains scalar, whether
per-block gains hold, and whether unchanged controls move materially.
Code size and instruction counts alone cannot accept the candidate.
