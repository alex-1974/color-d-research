# R7.4.6 — CVD kernel architecture

## Question

The R7.4.5 investigation showed that the remaining DMD performance gap cannot
be treated as a simple language or matrix-multiply deficit. The indexed
Viénot loop exposed a bounds-check-heavy caller layout pathology, while the
reference-bound source form removed the pathology and materially improved DMD.

External implementation review adds a broader question: are we still doing too
much *model preparation* per color, and are we using a generic 3x3 kernel where
the model has exploitable structure?

This slice compares three execution architectures without changing the
scientific model:

1. **scalar**
   - call the model operation for every color;
   - model/deficiency/severity preparation remains inside the scalar call;
   - compiler optimization is not artificially blocked, so a compiler may
     hoist work if it can prove that is legal.

2. **prepared**
   - select or interpolate all model parameters once per batch;
   - apply a generic 3x3 transform, or for Brettel a prepared two-plane plan,
     to every color.

3. **specialized**
   - retain preparation outside the loop;
   - expose model structure to the compiler:
     - Viénot computes its identical first and second matrix rows only once;
     - Machado keeps the prepared matrix coefficients in scalar locals;
     - Brettel separates plane selection from the two direct matrix paths.

The benchmark does **not** include sRGB transfer functions, gamut mapping,
8-bit packing, image I/O, or allocation inside the timed kernel. The semantic
work is linear-light RGB -> selected CVD transform -> linear-light RGB.

## External implementation evidence

The architecture is motivated by several independent implementations:

- DaltonLens precomputes Brettel's two RGB-to-RGB projection matrices and the
  separation-plane normal outside the pixel loop. It also reduces Viénot to
  one RGB-space 3x3 matrix.
- Colorspacious constructs one Machado matrix for a selected severity and then
  applies it to an array using NumPy vectorized matrix arithmetic.
- Colour exposes Machado matrix construction as a separate operation.
- Chromanopia computes the Viénot/Machado matrix before its buffer loop and
  then applies only the prepared coefficients to each pixel.

These implementations are references for execution structure, not numerical
or API templates for color-d.

## Viénot specialization

The promoted Viénot matrices have identical first and second rows. The
specialized candidate therefore computes that row once and stores it into both
R and G. The third row retains the generic coefficient operation order,
including explicit zero/one coefficients, so the research candidate does not
silently turn IEEE-special-value behavior into a finite-only contract.

This candidate is deliberately more conservative than the stronger algebraic
rewrite:

~~~text
rg = a*r + b*g
b' = b + c*(r-g)
~~~

because dropping explicit zero/one terms and reassociating arithmetic can
change NaN, infinity, signed-zero, and rounding behavior. A stronger finite
fast path may be studied later only if the conservative specialization leaves
material performance on the table.

## Machado preparation

Machado severity is fixed for the whole benchmark batch at 0.65.

The scalar architecture performs the eleven-point table selection/interpolation
through the scalar call for every input. The prepared and specialized
architectures interpolate the 3x3 matrix once per batch. This directly tests
the common real-consumer case where deficiency and severity are stable while
many colors or pixels are processed.

A future variable-severity-per-color workload would be a separate semantic
case and must not be used to reject preparation for fixed-severity consumers.

## Brettel preparation

Brettel already has the scientifically reduced form used by DaltonLens:
two precomputed RGB-space projection matrices plus one RGB-space separation
normal. This slice therefore does not replace the model. It measures whether
hoisting deficiency selection and typed parameter construction out of the
per-color call materially changes DMD/LDC code generation.

## Semantic qualification

The D preflight covers:

- float and double;
- 65,536 deterministic finite extended-range colors;
- Viénot protan/deutan;
- Machado protan/deutan at severity 0.65;
- Brettel protan/deutan/tritan;
- black/white, extended values, NaN, infinities, and signed zero;
- CTFE scalar evaluation;
- `@safe pure nothrow @nogc` candidate implementations.

Prepared and specialized results are checked against the scalar reference with
the retained scalar-specific research tolerances.

The timed driver checks every output against the scalar architecture before
measurement. The replay additionally matches D and C++ observable checksums for
every block/direction/round.

## Performance method

The tracked replay:

- builds DMD and LDC independently;
- uses `boundscheck=on` for D;
- builds C++ with `-O3 -ffp-contract=off -fno-fast-math`;
- gives D and C++ the same scalar/prepared/specialized algorithms;
- allocates input/output before timing;
- uses four warm-up batches;
- uses nine timed rounds and sixteen batch repetitions per round;
- tests 1024, 8191, and 65536 colors by default;
- pins each timed process to one allowed CPU;
- alternates compiler, workload, language, and forward/reverse order;
- records frequency/turbo/SMT/thermal observations without changing host
  policy;
- retains fixed binary hashes and disassembly.

The primary metrics are:

- D speedup versus its own scalar architecture;
- C++ speedup versus its own scalar architecture;
- D/C++ ratio for each *matched* architecture.

A prepared or specialized candidate is interesting only if it improves the
algorithm in both languages or narrows a D-specific code-generation deficit
without weakening semantics.

## Acceptance interpretation

This slice does not have a single "winner" threshold.

A production follow-up is justified when all of the following hold:

1. semantic preflight and D/C++ checksum gates pass;
2. the candidate does not materially regress the supported LDC path;
3. improvement is repeatable across sizes and balanced blocks;
4. the gain is attributable to less repeated work or simpler kernel structure,
   not to an uncontrolled one-off code-layout phase;
5. the API can expose preparation/batch execution without making image,
   renderer, thread, or allocation policy part of color-d.

Potential production shapes include a prepared value object and caller-owned
batch output, but this research slice does not freeze names or API.

## Files

- `kernels.d` — scalar, prepared, and specialized D candidates plus semantic
  qualification.
- `bench.d` — D batch benchmark.
- `reference.cpp` — matched C++ implementation.
- `preflight.d` / `dub.sdl` — inexpensive D semantic smoke.
- `run.py` — reproducible XPS/local replay, pooling, checksum verification,
  binary hashing, codegen capture, and archive creation.

## Status

Implementation and CI smoke qualification are complete at
`49bc475d165aeb972545a630e7a6ce3cf4be93bb`.

GitHub Actions run 37076556756 passed for both DMD 2.113.0 and LDC 1.43.0:

- release DUB semantic preflight: PASS;
- matched D/C++ replay smoke at n=1024: PASS;
- D/C++ checksum pairing: PASS;
- pooled-summary cardinality/sample-count checks: PASS.

Shared-runner timings are smoke evidence only and are not used for performance
selection. Controlled XPS replay over 1024/8191/65536 and balanced blocks is
still pending.


## XPS result — algorithm architecture comparison

The controlled XPS replay completed successfully at revision
`c2e3c5e119298e899f29c6676cc976b3f0611145`.

Archive integrity, binary hashes, semantic preflight, and D/C++ checksum pairing
all passed. The run used DMD 2.113.0, LDC 1.41.0, GCC 15.2.0, three workload
sizes (1024, 8191, 65536), three balanced blocks, CPU 0 affinity,
`boundscheck=on` for D, and matched D/C++ source architectures.

The host remained an uncontrolled powersave/turbo/SMT environment and reached
high package temperatures during the run, so small cross-language differences
remain approximate. The large architecture effects below are far beyond that
noise.

### Viénot

Hoisting the deficiency-selected matrix out of the per-color scalar call is the
dominant optimization.

Median D speedup versus scalar across sizes/deficiencies:

| compiler | scalar | prepared | specialized |
| --- | --- | ---: | ---: |
| DMD 2.113 | float  | ~11.8x | ~9.0x |
| DMD 2.113 | double | ~12.0x | ~10.8x |
| LDC 1.41  | float  | ~5.8x  | ~5.8x |
| LDC 1.41  | double | ~1.0x  | ~1.0x |

GCC gains essentially nothing from explicit preparation because it already
hoists/folds the equivalent scalar work. Therefore the huge D scalar penalty is
primarily a D compiler/source-shape failure to eliminate repeated invariant
preparation, not a better C++ scientific algorithm.

The conservative Viénot specialized kernel is slower than prepared on DMD and
neutral on LDC. Reusing the identical first/second row in source does not
improve the generated hot path enough to justify the extra specialization.

Prepared Viénot D/C++ median ratios are approximately:

- DMD float: 2.74x;
- DMD double: 1.58x;
- LDC float: 1.11x;
- LDC double: 0.81x.

Thus preparation fixes the gross architectural error but does not close the
remaining DMD code-generation gap.

### Machado

Machado shows the clearest prepare-once result.

Median D speedup versus scalar:

| compiler | scalar | prepared | specialized |
| --- | --- | ---: | ---: |
| DMD 2.113 | float  | ~18.5x | ~14.0x |
| DMD 2.113 | double | ~17.5x | ~12.3x |
| LDC 1.41  | float  | ~10.3x | ~10.4x |
| LDC 1.41  | double | ~1.0x  | ~1.0x |

Again, GCC's scalar and prepared timings are essentially identical: GCC already
moves the fixed severity/deficiency preparation out of the effective pixel
work. DMD does not, and LDC 1.41 does not reliably do so for float.

Explicitly preparing the severity matrix once per batch is therefore an
algorithm/API-level requirement for predictable D performance. It should not be
left to optimizer loop-invariant-code-motion.

The further specialized form that copies matrix coefficients into scalar locals
does not help DMD and is slower than the prepared generic form. LDC treats the
two forms as essentially equivalent.

Prepared Machado D/C++ median ratios are approximately:

- DMD float: 2.74x;
- DMD double: 1.74x;
- LDC float: 1.42x;
- LDC double: 0.96x.

### Brettel

Brettel also benefits from explicit preparation, but it exposes a second,
distinct issue.

Prepared plan speedup versus scalar is about:

- DMD float: ~2.9x;
- DMD double: ~2.7x;
- LDC float: ~3.7x;
- LDC double: workload-dependent, roughly 1.8-2.2x at the larger sizes.

The split specialized branch form is much faster than prepared for DMD and
brings DMD much closer to matched C++ in several cases. However both DMD and
GCC show strong workload/code-layout sensitivity for this specialized branch
shape. GCC's specialized Brettel kernel becomes substantially slower than its
own prepared/scalar path at 8191 and 65536; DMD's specialized float path also
rises reproducibly from roughly 4 ns/color at n=1024 to roughly 8-9 ns/color at
n=65536, while LDC stays nearly flat.

Therefore the split specialized Brettel form is **not** yet a production
candidate. The result is evidence that branch/source shape matters strongly,
but choosing it now would risk selecting one compiler/layout accident over
another.

### Architectural conclusion

The experiment confirms that the previous per-color API architecture was
suboptimal for bulk consumers.

The production-relevant conclusion is narrower than "specialize every model":

1. **Prepared transform objects are the primary missing abstraction.**
   Deficiency and, for Machado, severity must be prepared once and reusable over
   many colors.
2. **Viénot should use the prepared generic matrix kernel first.**
   The conservative row-specialized source form regresses DMD.
3. **Machado should use the prepared generic matrix kernel first.**
   Scalar-local coefficient specialization adds no value.
4. **Brettel should expose a prepared two-plane plan, but its optimal hot-loop
   branch form needs another focused compiler/codegen slice before production.**
5. The remaining DMD/C++ gap after preparation is now clearly a compiler/kernel
   code-generation problem rather than repeated model preparation.

A production API should therefore separate preparation from application, e.g.
conceptually:

~~~text
prepare model/deficiency[/severity]
        ->
Prepared transform value
        ->
apply(one color)
applyInto(input[], output[])
~~~

The exact public names remain a production design decision.

### Next research step

For Viénot and Machado, additional algorithm exploration is no longer the
highest-value work. The next step is production/API qualification of prepared
transforms plus batch execution.

For Brettel only, retain a research follow-up comparing prepared branch forms,
if-conversion/branchless selection where IEEE semantics allow it, and
auto-vectorization/codegen across DMD/LDC/GCC before selecting a production
batch kernel.


## Exact production replay

After the prepared API was promoted to color-d, the research harness gained a
separate production replay pinned to color-d commit
`7a7550d44b3133b1145562c6ca8483fe6b0f668c`.

The replay does not benchmark copied research candidates. It snapshots the
exact production `source/color/cvd.d` and `source/color/rgb.d` from that
commit and compiles `production_bench.d` directly against those modules.

Measured D paths are therefore the public production APIs:

- scalar `brettel1997Dichromat`, `vienot1999Dichromat`, and
  `machado2009`;
- prepared `PreparedBrettel1997Dichromat.tryApplyInto`;
- prepared `PreparedVienot1999Dichromat.tryApplyInto`;
- prepared `PreparedMachado2009.tryApplyInto`, after one successful
  `tryPrepareMachado2009`.

`production_reference.cpp` mirrors the same scalar/prepared model work.
The replay retains the same D/C++ checksum gates, CPU affinity, balanced
forward/reverse ordering, source/binary hashes, and codegen capture used by the
architecture comparison.

GitHub Actions run 37079909935 passed the exact-production replay smoke under
both DMD 2.113.0 and LDC 1.43.0. The smoke uses n=1024 and one block only;
shared-runner timing is not performance evidence.

Controlled XPS production performance evidence over 1024/8191/65536 and three
balanced blocks is pending.


## Exact production XPS result

The controlled XPS exact-production replay completed successfully with research
revision `849d633135d2e7ede592ea2c6ec32e79aeb42dda` and pinned color-d
revision `7a7550d44b3133b1145562c6ca8483fe6b0f668c`.

Archive, tracked-file hashes, production-source hashes, and all three binary
hashes verified. D/C++ observable checksum pairing passed for every
compiler/block/direction/round.

The run used DMD 2.113.0, LDC 1.41.0, GCC 15.2.0, CPU 0 affinity,
n=1024/8191/65536, three balanced blocks, and `boundscheck=on`.
The XPS remained in powersave mode with turbo and SMT enabled and reached about
98 C in the hottest recorded zone. Large factors are robust; small percentage
differences remain approximate.

### Exact prepared production performance

Median prepared D/C++ ratios across sizes and deficiencies:

| compiler | scalar | Viénot | Machado | Brettel |
| --- | --- | ---: | ---: | ---: |
| DMD 2.113 | float  | 2.62x | 2.55x | 3.27x |
| DMD 2.113 | double | 1.60x | 1.61x | 3.93x |
| LDC 1.41  | float  | 1.96x | 1.96x | 1.82x |
| LDC 1.41  | double | 1.44x | 1.44x | 1.67x |

DMD Viénot/Machado prepared absolute times are about 2.1-2.3 ns/color and
match the research prepared kernels closely. Thus the prepare-once production
promotion successfully retained the DMD prepared-kernel performance.

Brettel remains much more expensive and size-sensitive, as expected from the
earlier branch/code-shape result.

### Scalar-to-prepared production speedups

The exact public API exposes much larger scalar/prepared ratios than the
research architecture prototype for several DMD paths:

| compiler | scalar | Viénot | Machado | Brettel |
| --- | --- | ---: | ---: | ---: |
| DMD 2.113 | float  | ~76x | ~150x | ~13x median |
| DMD 2.113 | double | ~13x | ~118x | ~2.5x |
| LDC 1.41  | float  | ~3.3x | ~1.8x | ~1.2x |
| LDC 1.41  | double | ~0.62x | ~2.3x | ~1.2x |

These ratios must not be read simply as a larger algorithmic win. The exact
production scalar refactor changed compiler code shape.

DMD disassembly shows scalar loops retaining calls to the public
`prepare...()` and `apply()`/Machado preparation paths inside the loop.
Compared with the research scalar candidate, the production scalar path is
roughly 6.2x slower for Viénot float, 6.4x slower for Machado double, about
7.6x slower for Machado float, and materially slower for some Brettel-float
cases. Viénot double and Brettel double remain close to the research scalar
baseline.

Therefore the production scalar convenience API has a compiler-sensitive
performance regression and should not be treated as a bulk-performance
baseline.

### LDC public prepared call-shape regression

A second issue appears only after measuring the exact public prepared API.

Compared with the R7.4.6 research prepared kernels, production prepared D
absolute times change by approximately:

| scalar/model | production / research |
| --- | ---: |
| LDC float Viénot | 1.74x |
| LDC double Viénot | 1.48x |
| LDC float Machado | 1.35x |
| LDC double Machado | 1.35x |
| LDC float Brettel | ~3.05x median, strongly size-sensitive |
| LDC double Brettel | ~1.51x median, strongly size-sensitive |

DMD prepared Viénot/Machado remain within roughly +/-6% of the research
candidate, so this is not a general cost of the public API design.

The LDC codegen gives a concrete hypothesis. In the research Viénot-float
prepared loop, matrix values are hoisted into XMM registers before the main
vectorized work. In the exact-production benchmark, the generic noinline
wrapper passes the prepared value by `const ref`; after
`tryApplyInto` is inlined, LDC repeatedly loads/shuffles matrix coefficients
through the prepared-object pointer inside the vectorized loop.

This is consistent with an alias/call-shape barrier preventing full scalar
replacement/loop-invariant hoisting. It is evidence, not yet proof that the
public API itself is at fault: a normal consumer can call
`prepared.tryApplyInto` directly rather than through the benchmark's generic
`const ref` wrapper.

### Revised status

The prepared production architecture is semantically correct and solves the
gross repeated-preparation problem, but the performance story is not yet
closed:

1. DMD prepared Viénot/Machado transferred successfully, with the previously
   identified remaining compiler/kernel gap.
2. The exact scalar convenience implementation needs a focused inlining/code-
   shape qualification before it can be accepted as performance-neutral.
3. LDC public prepared performance requires a direct-call/value-call diagnostic
   to separate real API cost from the benchmark wrapper's `const ref` alias
   shape.
4. Brettel remains a separate branch/codegen problem and should not drive the
   matrix-model fix.

Do not add compiler-specific workarounds or change safety semantics from this
result alone.


## Prepared call-shape isolation result

The XPS call-shape replay completed successfully at research revision
`cfcb1cdfc95677946dd9a28a92d67ffc66c68cc7` against the same pinned
color-d production commit
`7a7550d44b3133b1145562c6ca8483fe6b0f668c`.

All file and binary hashes verified, and all four call shapes produced identical
checksums for every compiler/scalar/model/workload/round.

The four shapes were:

1. prepared object passed by `const ref` through a noinline wrapper;
2. prepared object passed by value through a noinline wrapper;
3. prepared object passed by `const ref`, copied to a local value, then used;
4. direct public `prepared.tryApplyInto` call.

### DMD 2.113

DMD is essentially insensitive to these four prepared call shapes. Across
Viénot/Machado, float/double and all sizes, the central differences remain
within roughly one percent, with only ordinary hot-host noise at the largest
workloads.

Therefore a local prepared-value snapshot is performance-neutral for the
current DMD prepared kernel.

### LDC 1.41

LDC shows a strong, scalar-dependent scalar-replacement/alias effect.

Median ratios versus the current `const ref` wrapper across sizes:

| scalar/model | by value | local copy | direct |
| --- | ---: | ---: | ---: |
| float Viénot | ~0.734x | **~0.721x** | ~0.992x |
| float Machado | ~0.739x | **~0.728x** | ~1.007x |
| double Viénot | ~1.009x | **~0.693x** | ~1.003x |
| double Machado | ~1.007x | **~0.702x** | ~1.013x |

Thus:

- direct public method invocation does **not** remove the LDC regression;
- passing the prepared value by value helps float but not double;
- making an explicit local value copy is the only shape that reliably improves
  both float and double.

The local-copy speedup is about 1.38x for float and 1.42-1.44x for double.

Using the exact-production C++ measurements from the immediately preceding XPS
run as the matched reference, the local-copy LDC path is approximately:

- Viénot float: 1.36-1.45x C++;
- Machado float: 1.38-1.45x C++;
- Viénot double: 0.90-0.99x C++;
- Machado double: 0.90-1.01x C++.

The call-shape result therefore confirms that the public prepared object's
field access through a const `this`/reference shape blocks useful LDC scalar
replacement or loop-invariant hoisting. A local snapshot of the small prepared
value before entering the hot loop is the robust compiler-neutral source shape.

### Production implication

The public API does not need to change.

A production optimization should:

1. snapshot prepared matrix/plan state into local values before the batch loop;
2. keep the existing caller-owned slices, safety, bounds-check and no-allocation
   contracts;
3. restore the scalar convenience callables to direct model arithmetic rather
   than relying on `prepare().apply()` being inlined by DMD;
4. qualify the exact patched production commit on XPS before merge.

This is an internal implementation/code-shape correction, not a new semantic
or API contract.


## PR #170 candidate exact-production result

The exact-production XPS replay of color-d candidate
`69269171dfc796e3d891db3aeef119261cb0f916` completed successfully using
research revision `f152c07cbf9670fae4bd61820a7334f0976d4873`.

Integrity, production-source hashes, binary hashes and D/C++ checksum pairing
all passed. The run used the same DMD 2.113.0 / LDC 1.41.0 / GCC 15.2.0
matrix, sizes 1024/8191/65536 and three balanced blocks as the exact-production
baseline.

### Prepared local-snapshot confirmation

Median prepared D/C++ ratios for the candidate are:

| compiler | scalar | Viénot | Machado | Brettel |
| --- | --- | ---: | ---: | ---: |
| DMD 2.113 | float  | 2.66x | 2.67x | 3.24x |
| DMD 2.113 | double | 1.67x | 1.76x | 4.11x |
| LDC 1.41  | float  | **1.41x** | **1.41x** | **0.50x** |
| LDC 1.41  | double | **0.91x** | **0.92x** | **0.95x** |

Relative to the pinned production baseline, candidate prepared D absolute time
changes by approximately:

| compiler/scalar/model | candidate / baseline |
| --- | ---: |
| LDC float Viénot | **0.739x** |
| LDC float Machado | **0.749x** |
| LDC double Viénot | **0.702x** |
| LDC double Machado | **0.699x** |
| LDC float Brettel | **0.322x median** |
| LDC double Brettel | **0.634x median** |
| DMD float Viénot | ~1.01x |
| DMD double Viénot | ~1.03x |
| DMD float Machado | ~1.04x |
| DMD double Machado | ~1.07x |

The local prepared-state snapshot therefore reproduces the call-shape
diagnostic in the exact public production implementation. It is a strong
production candidate.

The small DMD increases are much smaller than the LDC gain but must be checked
again on the final candidate because changing unrelated scalar code can move
DMD hot code and this investigation has already established DMD layout
sensitivity.

### Scalar direct-arithmetic candidate rejected

The same candidate also restored direct arithmetic to the scalar convenience
functions. This does **not** provide a compiler-neutral scalar fix.

Compared with the current exact-production baseline:

- DMD Viénot float improves modestly (~0.93x), while Viénot double improves
  strongly (~0.40x);
- DMD Machado float is unstable/slower in the central result (~1.19x) and
  Machado double improves only modestly (~0.93x);
- LDC Machado regresses severely: float is about **4.67x** the current scalar
  time and double about **2.37x**;
- other scalar paths are mixed and include workload/layout sensitivity.

Compared with the earlier research scalar architecture, production direct
Machado remains much slower for several compiler/scalar combinations, so the
direct scalar rewrite does not restore the desired baseline.

Conclusion: do **not** merge the scalar rewrite together with the prepared
local-snapshot optimization. Keep the local-snapshot change, revert scalar
convenience functions to the existing production implementation, and study
scalar source shape separately.

A final exact-production XPS replay is required after that split because DMD
code placement can change when the scalar bodies are reverted.


## Final unconditional-snapshot candidate rejected; compiler-family gate justified

The exact-production replay of color-d commit
`44918bac87a25dc31bacd7de60e0383dc98bbb88` passed all integrity and
semantic/checksum gates but failed the DMD performance acceptance criterion.

The candidate contained only prepared local snapshots; scalar convenience
functions were identical to the production baseline.

### LDC

The expected improvement reproduced:

- Viénot float: about 0.72x baseline prepared time;
- Machado float: about 0.73x;
- Viénot double: about 0.72x;
- Machado double: about 0.73x;
- Brettel improved materially as well.

### DMD

The same source change was not performance-neutral after the scalar rewrite was
removed and text placement changed:

- Viénot float regressed approximately 22-27% across every tested
  size/deficiency combination;
- Machado double regressed approximately 15-22%;
- other prepared paths were smaller/mixed.

Generated-code comparison is decisive: the previous mixed candidate and the
final unconditional-snapshot candidate have instruction-identical DMD
`tryApplyInto` bodies for the affected prepared types, but at different text
addresses/phases. Example Viénot float is the same 276-byte instruction body
with different placement. The 64-byte benchmark wrapper is likewise
instruction-identical and moved.

Therefore the regression is another DMD text-layout/front-end phase effect, not
a change in CVD arithmetic or safety semantics.

### Engineering decision

Workspace DLANG_PRACTICES 15.5 explicitly permits an internal compiler-specific
optimized implementation when semantics are identical, material gain is
reproducible, the supported compiler matrix is covered, the gate is centralized
and testable, and a portable/reference path remains.

The production candidate is consequently revised to one centralized
compiler-family capability decision:

- LDC: local prepared-state snapshot before batch hot loops;
- DMD/non-LDC: retain the established member-backed prepared path.

This is preferable to an alignment or padding workaround and does not introduce
per-release compiler version forks.

The revised exact production commit still requires a final XPS replay before
merge.


## Compiler-gated final production candidate accepted

The exact-production XPS replay of color-d commit
`0efa650d231cea917e71cc4dd5fc35fe27b65d9b` completed successfully at
research revision `7d5dc783e8d60c93d8dc9eb3fc15e3e1d6a23cea`.

All integrity gates passed:

- production revision pin: PASS;
- tracked source hashes: PASS;
- binary hashes: PASS;
- D/C++ checksum pairing: PASS;
- DMD 2.113.0 / LDC 1.41.0 / GCC 15.2.0 matrix recorded;
- sizes 1024/8191/65536;
- three balanced blocks;
- bounds checks enabled.

The host again reached high package temperatures, up to roughly 99 C in the
recorded hottest zone. Large effects are robust; small percentage differences
remain approximate.

### DMD: established production path preserved

The compiler-family gate leaves DMD on the existing member-backed prepared
implementation.

Relative to the pinned production baseline, median prepared D time ratios
across sizes and deficiencies are approximately:

| scalar/model | gated / baseline |
| --- | ---: |
| float Viénot | 1.018x |
| float Machado | 1.000x |
| float Brettel | 0.979x |
| double Viénot | 0.996x |
| double Machado | 1.000x |
| double Brettel | 0.997x |

Individual measurements span the normal hot-host/layout range; the largest
single increase is about 5.7%.

Generated-code comparison confirms that the important DMD prepared
`tryApplyInto` hot loops are restored to the baseline placement/instruction
shape. Their symbol addresses match the baseline replay for the inspected
Viénot, Machado, and Brettel instantiations, and the instruction bodies are
unchanged. Remaining timing differences are therefore not evidence of a new
DMD implementation regression.

### LDC: snapshot gain retained

The LDC-gated local prepared-state snapshot reproduces the material gain.

Median prepared D time ratios versus the production baseline are approximately:

| scalar/model | gated / baseline |
| --- | ---: |
| float Viénot | **0.732x** |
| float Machado | **0.724x** |
| double Viénot | **0.711x** |
| double Machado | **0.735x** |
| float Brettel | **0.324x** |
| double Brettel | **0.660x** |

Matched D/C++ median ratios for the final gated candidate are approximately:

| scalar/model | D / C++ |
| --- | ---: |
| float Viénot | **1.43x** |
| float Machado | **1.42x** |
| double Viénot | **0.93x** |
| double Machado | **0.96x** |
| float Brettel | **0.53x** |
| double Brettel | **0.99x** |

Brettel double at n=1024 has a small-batch trade-off: the snapshot form is about
19-20% slower than the old LDC path there, but it is about 34-48% faster at
8191/65536 and remains around C++ performance overall. This is accepted as a
documented workload-size trade-off for the material larger-batch gain.

### Final production decision

The accepted implementation uses one centralized semantic-neutral
compiler-family capability gate:

- LDC -> local prepared-state snapshot before batch hot loops;
- DMD/non-LDC -> established member-backed prepared path.

No public API changes, compiler-version thresholds, alignment/padding hacks,
manual SIMD, disabled bounds checks, or relaxed IEEE semantics are introduced.

This satisfies workspace DLANG_PRACTICES 15.5:

- semantics identical;
- difference internal;
- reproducible material gain;
- supported compiler matrix covered;
- centralized/testable capability gate;
- understandable reference/portable path retained.

The prepared-path performance correction is therefore qualified for promotion.
Scalar convenience source-shape work remains separate in color-d issue #171.
