# R7.1 — CVD LMS reference model

## Scope

R7.1 establishes an independent reference layer for color-vision-deficiency (CVD) transformations before any production API is promoted into `color-d`.

The research compares the published Brettel (1997), Viénot et al. (1999), and Machado et al. (2009) families. The goal is not to select a winner, but to make their mathematical domains and assumptions explicit.

## Source-derived findings

Brettel, Viénot & Mollon (1997) present a computerized simulation of color appearance for dichromats. The method is based on LMS cone responses and uses projection geometry; the published work covers protan, deutan, and tritan dichromacy. citeturn0search4

Viénot, Brettel & Mollon (1999) describe digital colourmaps based on the LMS specification of the primaries of a standard video monitor. Their paper explicitly targets protanopic and deuteranopic display simulation. citeturn0search0turn0search47

Machado, Oliveira & Fernandes (2009) describe a physiologically based model derived from electrophysiological data and designed to handle normal colour vision, anomalous trichromacy, and dichromacy in one model. Their experimental evaluation included people with CVD and normal colour vision. citeturn0search1

DaltonLens provides an independent, readable implementation and reports tests against its Python reference implementation and external references. Its implementation keeps Brettel, Viénot and Machado as distinct models rather than treating them as one interchangeable transform. citeturn0search3turn0search5

## Working mathematical pipeline

The reference implementation will keep the representation boundary explicit:

```
encoded sRGB
    ↓
linear sRGB
    ↓
LMS
    ↓
CVD model
    ↓
LMS / linear RGB
    ↓
linear sRGB
    ↓
encoded sRGB
```

The research must record the exact RGB↔LMS matrices and white-point/adaptation assumptions used by each candidate. A matrix copied from an implementation without recording those assumptions is not sufficient evidence for a production API.

## Model boundary

### Brettel 1997

Projection-based dichromat simulation. This is particularly important as a reference for tritanopia because the projection geometry cannot in general be represented faithfully by one global 3×3 matrix. DaltonLens' reference C implementation explicitly describes Brettel's two-plane treatment and identifies it as the approach used for tritanopia. citeturn0search3turn0search12

### Viénot 1999

A compact display-oriented approximation based on LMS monitor-primary specifications. It is attractive for a low-cost generic transformation, but the published scope is specifically protanopic/deuteranopic display checking. citeturn0search0

### Machado 2009

A physiologically based severity model intended to cover anomalous trichromacy as well as dichromacy. Severity therefore belongs to this model's own parameterization; it must not automatically become a universal `0..1` parameter shared by all CVD models. citeturn0search1

## Production constraints

A future `color-d` API must:

- operate on an explicitly documented linear-light representation;
- preserve the library's scalar discipline;
- be allocation-free;
- remain `@safe`, `pure`, `nothrow`, and `@nogc` where the underlying operations permit;
- define non-finite behavior explicitly;
- define out-of-gamut behavior explicitly rather than silently clipping;
- separate transformation from accessibility classification;
- permit CTFE only where the exact mathematical implementation is CTFE-safe.

The consumer owns decisions such as "safe under CVD", contrast thresholds, Delta-E thresholds, and theme construction.

## R7.1 acceptance criteria

R7.1 is complete only when:

1. exact RGB↔LMS matrices are recorded for each selected reference;
2. white point and adaptation assumptions are recorded;
3. protan/deutan/tritan applicability is explicit;
4. dichromacy and anomalous-trichromacy semantics are not conflated;
5. at least one independent reference implementation is available for numerical cross-checking;
6. reference vectors can be executed from D;
7. float/double and CTFE/runtime behavior can be measured;
8. no production API is selected merely from an implementation convenience.

## Current conclusion

The evidence supports treating Brettel, Viénot and Machado as **different model families with different domains**, not as interchangeable implementations of a single universal CVD transform. R7.1 therefore remains a reference-model study; no production CVD API is promoted yet.
