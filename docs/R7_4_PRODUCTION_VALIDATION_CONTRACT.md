# R7.4 — Production validation contract

## Purpose
R7.4 defines the evidence required before any CVD transformation is promoted from research into `color-d` production code.

This is a validation contract, not an accessibility policy and not a theme-generation specification.

## 1. Reference domains
Every promoted model is validated in its documented mathematical domain.

- Input/output: `LinearSRgb!T` for the matrix/projection core.
- Encoded sRGB conversion is tested separately where the public convenience operation includes it.
- No implicit gamut clipping is part of the transform.
- Alpha is not transformed by the CVD model; RGB semantics and alpha compositing remain separate.

DaltonLens describes Brettel 1997, Viénot 1999 and Machado 2009 as linear-RGB pipelines with sRGB encoding/decoding around the transformation. It also explicitly notes that simulation models are approximations and that individual perception varies.

## 2. Reference vectors
The production test corpus shall contain fixed, human-readable vectors covering:
1. black; 2. white; 3. neutral gray; 4. primary red; 5. primary green; 6. primary blue; 7. cyan; 8. magenta; 9. yellow; 10. at least three interior colors; 11. negative and >1 intermediate linear-RGB values where the model contract permits them.

For each promoted model/deficiency combination, expected output is stored at double precision from an independent reference implementation.

Reference vectors are generated once, reviewed, and treated as regression data. CI must not regenerate expected values from the implementation under test.

## 3. Tolerance policy
Use separate numerical gates for matrix/reference arithmetic and the complete encoded-sRGB pipeline.

- Published matrix coefficients: double absolute tolerance `1e-12` where the same published coefficients are used.
- Float: initial absolute tolerance `2e-6`, followed by measured error-envelope review.
- Encoded sRGB pipeline: determine the gate from an independent reference corpus and observed error.

The tolerance is a regression gate, not a claim about human perceptual accuracy. A tolerance-to-observed-error ratio materially above 10× is a review trigger under the workspace quality contract.

## 4. CTFE/runtime
For every public callable that promises CTFE: compile representative invocations at CTFE, execute the same values at runtime, compare the results, and test under DMD and LDC.

For table-driven Machado, test exact table points, both sides of every interval, representative interior points, and severity endpoints.

## 5. Non-finite values
The production contract must explicitly define NaN and infinity behavior. The default mathematical behavior should preserve visibility of non-finite inputs rather than silently normalize them. Test the exact behavior.

## 6. Gamut
The CVD transform must not silently clip. Tests distinguish `transform`, `inGamut`, `clip`, and `gamutMap`. Only the transformation belongs to the CVD model.

## 7. Attributes and allocation
Every promoted callable receives compile probes for `@safe`, `pure`, `nothrow`, and `@nogc`. No allocation is expected from a fixed-size matrix/value transform.

## 8. Model coverage
### Brettel 1997
Validate protan, deutan, tritan, projection-plane selection, linear-RGB domain, and neutral/white behavior.

### Viénot 1999
Promote only protan and deutan. Do not expose Tritan through a shared enum without a model-specific contract.

### Machado 2009
Validate all 33 reference matrices, severity 0.0–1.0, adjacent 0.1-table interpolation, and protan/deutan behavior. Tritan must be explicitly documented as an approximation or excluded from the production API.

The published Machado paper presents a unified physiological model and reports experimental evaluation; independent review material identifies a specific limitation for tritanopia/tritanomaly.

## 9. Performance gate
Benchmark representative batches. Record compiler/version, scalar type, build mode, CPU/platform, workload, warm-up, iterations, median/distribution, and allocation behavior.

The relevant comparison is the same mathematical work with the same precision and validation semantics.

## 10. Consumer composition
Before release, demonstrate composition of CVD transformation + deltaEOK + WCAG contrast + consumer-selected threshold/policy without requiring a CVD-specific accessibility classifier inside `color-d`.

## 11. Promotion checklist
```text
R7.4
 ├─ reference vectors                 ☐
 ├─ double error envelope             ☐
 ├─ float error envelope              ☐
 ├─ CTFE/runtime                      ☐
 ├─ non-finite contract               ☐
 ├─ gamut non-interference            ☐
 ├─ @safe/pure/nothrow/@nogc          ☐
 ├─ performance                       ☐
 ├─ consumer composition              ☐
 └─ production API review             ☐
```

**Status: validation contract defined; no production implementation yet.**