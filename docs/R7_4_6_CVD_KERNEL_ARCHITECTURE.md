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

Implementation complete; performance evidence pending.
