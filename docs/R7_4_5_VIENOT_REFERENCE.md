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

## Inspected results

Measured source: `bc2c387e933469901cd8c2d2cedfe0b700db9f5f`.
[Reference-iteration qualification 36978601249](https://github.com/alex-1974/color-d-research/actions/runs/36978601249),
[baseline 36978601266](https://github.com/alex-1974/color-d-research/actions/runs/36978601266),
and [replay smoke 36978601286](https://github.com/alex-1974/color-d-research/actions/runs/36978601286)
finish successfully: twelve jobs across the four compilers.

All four qualification ZIP digests match GitHub. The archives contain 1,964
verified manifest entries and 772 successful recorded commands, including 576
CPU-pinned timed processes. All 145,152 raw sample rows reconstruct 4,032 block
reports and 1,344 pooled reports exactly. Matched sampled D/C++ checksums differ
by zero for float and double. All eleven tracked source Git blob hashes match
GitHub at the recorded source revision; all four archives share tracked and
generated source hashes. Codegen evidence covers sixteen fixed binaries whose
hashes match the replay manifests. This verifies source-equivalence/replay
integrity, not independent model accuracy.

Condensed data is in
[data/r7_4_5/vienot-reference-36978601249](../data/r7_4_5/vienot-reference-36978601249/).
Speedup below is the baseline D median divided by the reference candidate
median. Each range includes both deficiencies and all three batch sizes.

| Compiler | Scalar | Ref vs indexed speedup | Ref vs selected-policy speedup | Ref D/C++ |
| --- | --- | ---: | ---: | ---: |
| DMD 2.111.0 | float | 1.064–1.136 | 1.668–1.770 | 2.474–2.656 |
| DMD 2.111.0 | double | 0.976–1.001 | 1.815–1.837 | 1.790–1.882 |
| DMD 2.113.0 | float | 0.994–1.016 | 1.459–1.498 | 3.230–3.305 |
| DMD 2.113.0 | double | 0.968–1.008 | 1.775–1.796 | 1.874–1.947 |
| LDC 1.41.0 | float | 0.931–0.937 | 0.997–1.008 | 1.458–1.508 |
| LDC 1.41.0 | double | 0.972–0.983 | 0.829–0.854 | 0.879–0.914 |
| LDC 1.43.0 | float | 0.961–0.966 | 0.999–1.006 | 1.392–1.418 |
| LDC 1.43.0 | double | 0.986–0.994 | 0.825–0.830 | 0.886–0.902 |

For DMD 2.111 float, ref/index gains hold across blocks (1.057–1.139).
For DMD 2.113 float, block ratios span 0.981–1.034: no broad gain is established.
Neither DMD double comparison demonstrates a consistent improvement over index.
LDC does not benefit: float loses to index and double loses to the selected
original-double source form. Being faster than C++ in a double case does not
justify replacing an even faster D baseline.

### The codegen hypothesis is confirmed, but it is not a performance verdict

Both DMD versions remove all three explicit indexed input component bounds
checks. The loop retains the one output index check and reads r/g/b directly
without the old aggregate stack copy. Matrix preparation/copies are outside
the pixel loop; nine coefficient loads from stack storage, nine scalar
products and six scalar additions remain in each successful iteration.
No packed arithmetic is generated.

Complete Viénot function sizes fall from 785 to 703 bytes for float and 775
to 693 bytes for double. Static instruction counts fall from 151 to 133 and
139 to 121 respectively. These diagnostic reductions do not establish a
portable timing win: the two DMD hosts produce different ref/index outcomes.

The DMD 2.111 job uses EPYC 7763; DMD 2.113 uses EPYC 9V45; LDC 1.41 uses EPYC
7763; LDC 1.43 uses EPYC 9V74. Clocks, thermals and SMT remain uncontrolled on
shared CI hosts. GCC is 13.3.0. Do not infer a compiler-version threshold from
a comparison that also changes CPU, and do not compare absolute timings or
D/C++ ratios to earlier sessions as controlled before/after gains.

### Material unchanged-control movements remain unresolved

Against index, pooled unchanged arithmetic controls span 0.997–1.039 for
DMD 2.111, 0.141–5.108 for DMD 2.113, 0.979–1.024 for LDC 1.41, and 0.990–1.009
for LDC 1.43. The DMD 2.113 extremes persist across sizes, deficiencies and
blocks:

| DMD 2.113 unchanged control | Ref/index pooled speedup | Ref/index block speedup |
| --- | ---: | ---: |
| Float Machado lookup | 0.141–0.144 | 0.135–0.179 |
| Float Machado lookup+apply | 0.196–0.200 | 0.189–0.220 |
| Double Machado lookup | 4.920–5.108 | 4.891–5.204 |
| Double Machado lookup+apply | 3.755–4.009 | 3.581–4.107 |

Thus float lookup slows by about seven times while double lookup speeds up by
about five times. Do not accept the complete ref binary from its Viénot result
alone or present those unchanged-control gains as a new algorithmic improvement.

Targeted float/double lookupBatch, lookup+apply and matrixAtSeverity disassembly
has identical instruction/operand sequences after normalizing instruction and
relocation addresses plus generated bounds-filename symbol identities. All six
pairs match. The comparison record retains the normalization method and fixed
binary hashes; it does not prove identical placement or execution state.
The [control-code excerpts](../data/r7_4_5/vienot-reference-36978601249/dmd-2.113.0/control-code/)
retain the evidence. The cause remains unresolved; no microarchitectural or
toolchain defect is asserted from this static comparison.

The selected-policy Machado block-median maximum max/min ratios are 1.018,
1.454, 1.175 and 1.255 for DMD 2.111, DMD 2.113, LDC 1.41 and LDC 1.43.
The repeatable, candidate-specific multi-fold control movements are materially
larger than those block ranges and cannot be dismissed as ordinary block noise.

## Decision and next investigation

Reference-bound iteration qualifies the existing semantic/attribute corpus and
confirms the predicted removal of redundant input checks. It is not a broad
replacement for the indexed probe: its extra float gain is established only on
one DMD/CPU combination, double does not broadly improve, and LDC regressions
remain. Keep both probes for diagnosis, keep the selected policy unchanged, and
do not add a compiler-version fork or promote this source form to production.

The performance gate remains open. In this session, reference Viénot still costs
about 2.5–3.3 times C++ for DMD float and 1.8–1.95 times for double.
The next investigation should isolate matrix application and Machado lookup in
separate benchmark programs, retain fixed binaries and equivalent outputs, and
test whether placement/execution-state changes reproduce the large DMD 2.113
control movements. Resolve that confounding evidence before selecting the next
integrated winner. The reference loop can remain a useful safe scalar baseline
for later matrix-layout or packed-arithmetic work.

Reconstruct the reports and Viénot codegen using
`tools/inspect_bv_replay.py ARTIFACT.zip NEW_OUTPUT_DIRECTORY default bv_compiler
bv_vienot_index bv_vienot_ref`. Source Git blob identity was checked separately
against GitHub. Raw archives and executables remain Tier-3 CI artifacts; IDs,
digests, sizes and expiry dates are retained in artifacts.json. Independent
scientific oracle/envelopes and API/consumer review also remain open.


### Machado isolation follow-up — 2026-10-02

The [fixed-binary isolation and paired-source investigation](R7_4_5_MACHADO_ISOLATION.md)
is complete at measured source `bb8f2a9bb129ac58e0ff23653145375b2af0b085`.
All 16 final CI jobs pass. Rebuilding the original entry source and separating
Machado lookup/prepared application on the same hosts does not reproduce the
earlier multifold unchanged-control movements. DMD 2.113's original lookup pair
stays within about 2% in pooled results on the EPYC 7763 host. The earlier
reference run used EPYC 9V45; cause attribution remains open. Direction/block
disturbances are retained, and no integrated winner or production policy is
selected. Next diagnostic: floating-point state and deliberate code-placement
variation on one host/compiler.
