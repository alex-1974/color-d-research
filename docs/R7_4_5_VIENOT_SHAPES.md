# R7.4.5 — Viénot source-shape investigation

## Question and starting evidence

The integrated XPS replay at source `e948f48b71bea374702d79ae8bf9a4aba0010e56`
leaves DMD Viénot approximately 5.61–6.07 times C++ for float and
3.85–4.16 times C++ for double. See [the full XPS report](R7_4_5_BV_POLICY_XPS.md).
These are batch measurements with bounds checks enabled, not application-wide ratios.

The inspected binaries come directly from the fully verified archive
`color-cvd-xps-_o0btmdv.tar.gz`, SHA256
`867ce974fa94d1ba397c467059a9f9a379c0876aefe21fdda332d05e953daede`.
They were read with objdump, never executed here. The condensed function evidence
is in [data/r7_4_5/vienot-xps-codegen-20261002](../data/r7_4_5/vienot-xps-codegen-20261002/).

For DMD 2.111.0, both integrated Viénot batch bodies already contain the arithmetic.
Their only call is the bounds-failure path; a per-pixel helper call is therefore
not the observed cause of this residual gap. The successful inner loops use
scalar `mulss/addss` or `mulsd/addsd`, copy each RGB through a stack temporary,
and reload the nine matrix coefficients from stack storage per pixel.
Matrix preparation and coefficient conversion are outside the loop.

GCC 15.2.0 uses packed `mulps/addps` or `mulpd/addpd` in addition to scalar
tail paths. The functions include alias guards and rearrangement of AoS RGB
components. Packed code generation and avoidable scalar memory traffic are
concrete hypotheses for the gap; instruction counts alone do not establish
their individual timing contributions. The existing C++ reference and its
strict floating-point flags are unchanged.

## Two isolated candidates

| Replay variant | Change from the integrated Viénot path |
| --- | --- |
| `bv_vienot_index` | Keep a runtime prepared matrix; load r/g/b individually by index before direct stores, instead of copying the RGB aggregate. |
| `bv_vienot_static` | Use the same indexed loop with typed matrix coefficients evaluated at CTFE; select one of two template instantiations once per batch. |

Both retain the existing integrated Brettel path and unchanged Machado controls.
Neither changes `bv_policy.d` or the selected compiler policy. There is no
new compiler/version fork and no production API change.

The CTFE specialization uses the same tracked coefficient data and casts to the
same scalar type. Every three-term row expression and its grouping is retained,
including multiplication by zero and one. Removing `0*b` is not an equivalent
optimization for NaN or infinity; replacing the final row with a simplified
expression would also change rounding/IEEE behavior. The compiler may still
perform equivalent common-subexpression elimination for identical rows.

## Qualification and measurement protocol

The existing 5,839-input-per-scalar extended corpus now checks both candidates
against the original scalar source for all supported Viénot deficiencies,
including NaN, infinities, signed-zero inputs, subnormals and exact in-place use.
The preliminary finite component envelope remains 2e-6 for float and 1e-12 for
double; this is source-equivalence qualification, not an independent scientific
model oracle or a signed-zero-bit contract.

Additional batch checks cover lengths 0, 1, 2, 3, 7, 8, 9, 31, 32, 33 and 65.
They compare every component in separate-output and exact in-place calls and
verify that the suffix outside the selected in-place slice stays unchanged.
Both compile-time and runtime drivers use `@safe pure nothrow @nogc`.
Debug and optimized Release runs retain bounds checks.

The four-compiler qualification workflow compares default, direct, split,
portable policy, selected policy and these two candidates over sizes 1024,
8191 and 65536, three balanced blocks, and forward/reverse order.
There are 588 pooled cases per compiler and 54 samples per language/case.
The general replay smoke now exercises all twelve variants over two sizes and
two blocks (672 pooled cases per compiler).

`tools/inspect_vienot_codegen.py` retains only float/double Viénot batch
disassembly and binary hashes from the fixed binaries used in each replay.
It never executes a binary. Function size and mnemonic counts are diagnostic
evidence, not performance acceptance criteria.

## Decision status

The two source shapes are research probes pending the new compiler-matrix
results. Keep the measured integrated policy unchanged until component,
CTFE/attribute, in-place, control and timing evidence has been inspected.
A smaller generated function cannot close the performance gate by itself.
No consumer rerun is needed before the CI candidates have been compared.

The wider independent model oracle/envelopes and API/consumer review remain
open as described in the integrated-policy report.
