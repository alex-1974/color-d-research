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

## Compiler-matrix results

Measured source: `b2267e17ad45c5b47e3f1fa5922b55de83236b61`.
[Qualification run 36975703662](https://github.com/alex-1974/color-d-research/actions/runs/36975703662),
[baseline run 36975703575](https://github.com/alex-1974/color-d-research/actions/runs/36975703575),
and [replay smoke 36975703572](https://github.com/alex-1974/color-d-research/actions/runs/36975703572)
all complete successfully: twelve jobs across the four compiler versions.

All four qualification ZIP digests match GitHub. The replay archives contain
3,308 verified manifest entries and 1,324 successful recorded commands, including
1,008 CPU-pinned timed processes. All 254,016 raw sample rows reconstruct
7,056 block reports and 2,352 pooled reports exactly. Matched sampled D/C++
checksum differences are zero for float and double. Every one of the eleven
tracked source Git blob hashes matches GitHub at the measured commit; all four
archives share the same tracked and generated source hashes. The sixteen inspected
codegen binaries match the replay's fixed binary hashes.

Condensed evidence is in
[data/r7_4_5/vienot-shapes-36975703662](../data/r7_4_5/vienot-shapes-36975703662/).
The full comparison CSV includes every batch size, deficiency, candidate,
baseline and unchanged control, with pooled and per-block speedup ranges.

The following ranges cover both deficiencies and all three sizes. Speedup is
selected-policy D median divided by candidate D median; values below one are
regressions. Ratios to C++ are within each compiler's replay session.

| Compiler | Scalar | Indexed speedup | CTFE speedup | Indexed D/C++ | CTFE D/C++ |
| --- | --- | ---: | ---: | ---: | ---: |
| DMD 2.111.0 | float | 1.673–1.687 | 0.454–0.459 | 2.899–2.972 | 10.641–11.030 |
| DMD 2.111.0 | double | 1.963–2.006 | 1.146–1.321 | 1.893–1.925 | 2.842–3.309 |
| DMD 2.113.0 | float | 1.558–1.580 | 0.443–0.455 | 2.799–2.837 | 9.604–10.108 |
| DMD 2.113.0 | double | 1.972–2.011 | 1.134–1.411 | 1.791–1.827 | 2.523–3.177 |
| LDC 1.41.0 | float | 1.067–1.080 | 1.238–1.256 | 1.362–1.407 | 1.178–1.205 |
| LDC 1.41.0 | double | 0.855–0.880 | 1.000–1.007 | 0.865–0.886 | 0.735–0.776 |
| LDC 1.43.0 | float | 1.020–1.032 | 1.134–1.228 | 1.192–1.282 | 1.048–1.080 |
| LDC 1.43.0 | double | 0.815–0.988 | 0.975–1.002 | 0.806–0.969 | 0.665–0.959 |

DMD's indexed float gains hold in every block (1.541–1.689), as do indexed
double gains (1.857–2.481). The CTFE float regression also holds in every DMD
block (0.440–0.459). For LDC, CTFE float gains hold in every block (1.128–1.259);
CTFE double has no broad demonstrated benefit.

### Codegen and controls

The indexed DMD loops remove the per-pixel aggregate stack copy while retaining
scalar arithmetic and matrix loads. They contain three input component bounds
checks and one output check. Their complete functions are *larger* than the old
functions despite the measured gain. The CTFE DMD loops duplicate deficiency
bodies and add separate output-component checks. They remain scalar; constant
coefficients alone do not guarantee better scheduling or equivalent-expression
elimination. No detailed microarchitectural cause is claimed for their float
regression without counters or additional isolation.

LDC's CTFE float body is also larger while faster. Its indexed double body is
smaller while slower. This experiment directly rejects function size or static
instruction count as an acceptance shortcut.

Unchanged arithmetic controls matter. For the DMD indexed binaries, pooled
control speedups against the selected-policy binary are 0.935–1.007 on 2.111
and 0.983–1.009 on 2.113. The 0.935 minimum is float Brettel/protan at n=65536 on DMD 2.111,
about 6.9% slower despite unchanged arithmetic, present in all three blocks.
Do not label the complete candidate binary universally faster. On LDC, CTFE control ranges are 0.970–1.025 on 1.41 and 0.944–1.025 on
1.43; modest unrelated movements remain.

More materially, the DMD 2.113 CTFE binary slows unchanged double Machado
lookup by approximately 3.8 times (speedup 0.263–0.265) and lookup+apply by
approximately 3.4 times (speedup about 0.293). Both persist across sizes,
deficiencies and blocks. Targeted disassembly of double lookupBatch, lookup+apply,
and matrixAtSeverity has identical instruction/operand sequences after
normalizing relocation addresses and generated bounds-filename symbol identities.
Only placement/relocation changes are observed; the cause is unresolved.
The [control-code excerpts and normalization record](../data/r7_4_5/vienot-shapes-36975703662/dmd-2.113.0/control-code/)
retain that evidence. Do not attribute this large regression to changed Machado
arithmetic or dismiss it as ordinary block noise.

The maximum selected-policy Machado block-median max/min ratio is 1.103 for
DMD 2.111, 1.262 for DMD 2.113, 1.050 for LDC 1.41 and 1.024 for LDC 1.43.
These are shared CI hosts with uncontrolled clocks, thermals and SMT, not
controlled workstation measurements. CPU models differ: DMD 2.111 uses EPYC
9V74, DMD 2.113 and LDC 1.41 use EPYC 7763, and LDC 1.43 uses Xeon 8370C.
GCC is 13.3.0 here versus 15.2.0 in the XPS archive. Do not use cross-session
absolute timings as before/after gains.

## Decision and next probe

- Retain indexed component loading as the preferred *DMD Viénot research probe*:
  it improves both precisions on both DMD versions and every measured block.
- Reject the CTFE source shape for DMD: float and the 2.113 Machado controls
  materially regress. Its double gain is weaker than the indexed alternative.
- Retain CTFE float as a promising LDC research alternative. Keep the original
  double-Viénot LDC path; indexed double consistently loses and CTFE double
  provides no broad gain.
- Keep the integrated policy unchanged. No new compiler specialization or
  production promotion is justified by this one CI comparison alone.
- The DMD indexed residual gap is about 2.8–3.0 times C++ for float and
  1.8–1.9 times for double. The performance gate remains open.

The next narrow DMD probe should bind each input RGB by reference during
iteration, retain direct stores, and measure whether this removes the three
repeated indexed input checks while avoiding the old aggregate copy. Inspect
that generated loop before considering explicit packed arithmetic. Preserve
the same precision, IEEE expressions, bounds-checked builds, CTFE/attributes and
in-place tests. No unchanged consumer replay is requested at this stage.

The independent scientific oracle/envelopes and API/consumer review remain open.
Use `tools/inspect_bv_replay.py ARTIFACT.zip NEW_OUTPUT_DIRECTORY default bv_direct
bv_split bv_portable bv_compiler bv_vienot_index bv_vienot_static` to reconstruct
the reports and fixed-binary codegen evidence without executing archived binaries.
Source Git blob verification is a separate recorded network check. Large raw
archives and executables remain Tier-3 CI artifacts; their IDs, digests, sizes
and expiry dates are retained in artifacts.json rather than committing binaries.
