# R7 — CVD model synthesis and production API boundary

## Purpose

R7.1–R7.3 establish three distinct CVD model families. This document converts that evidence into a candidate production API boundary without implementing production code.

The boundary follows color-d's existing principle that mathematical transformations belong in the library while accessibility policy and theme construction remain consumer responsibilities.

## Evidence summary

| Model | Deficiencies | Severity semantics | Transform structure | Current research status |
| --- | --- | --- | --- | --- |
| Brettel 1997 | protan, deutan, tritan | full dichromat transform; no universal severity contract | two-plane projection | independently exercised in R7.2 |
| Viénot 1999 | protan, deutan | full-deficiency display simulation; no established universal severity contract | single 3×3 matrix | independently exercised in R7.2 |
| Machado 2009 | protan, deutan, tritan matrices | model-specific 0..1 severity table | severity-dependent 3×3 matrices | complete table exercised in R7.3 |

The table is descriptive. It is not a ranking of models.

## Proposed production layering

### 1. Shared mathematical primitives

The production layer should reuse existing typed color spaces:

```
SRgb!T
   ↓ toLinear
LinearSRgb!T
   ↓ model-specific CVD transform
LinearSRgb!T
   ↓ toSRgb
SRgb!T
```

No CVD function should silently perform gamut clipping or gamut mapping.

### 2. Model-specific operations

The public contract should preserve model identity.

Conceptually:

```
brettelDichromat(color, deficiency)
vienotDichromat(color, deficiency)
machado(color, deficiency, severity)
```

The exact naming remains a production API design task. The important constraint is that the signature must not imply that all models have the same semantics.

### 3. Deficiency type

A shared descriptive enum can represent the three cone-deficiency families:

```
protan
deutan
tritan
```

But a model function must constrain which values are valid. In particular, Viénot 1999 should not silently accept tritan merely because a shared enum contains it.

### 4. Severity

Do not put severity into the generic deficiency type.

Machado has an explicit severity model with eleven reference matrices and intermediate interpolation between adjacent table entries.

Brettel and Viénot do not acquire Machado's severity semantics merely because a common convenience API would be shorter.

If a future Brettel/Viénot severity operation is desired, it must be a separately documented model contract.

## Output and gamut

The transformation returns a mathematical color value. It does not decide whether that value is displayable.

Therefore:

```
CVD transform
     ↓
LinearSRgb
     ↓
consumer decides:
    inGamut?
    clip?
    gamutMap?
```

This follows the existing color-d gamut boundary established by #161.

## Accessibility boundary

No function belongs in color-d whose semantic meaning is equivalent to:

```
isColorBlindSafe(...)
```

or any other policy classifier.

A consumer may compose:

```
CVD transform
      +
deltaEOK
      +
WCAG contrast
      +
consumer threshold/policy
```

The threshold and resulting UI decision belong to the consumer.

## Error and non-finite behavior

The production API must explicitly document behavior for NaN and infinity. The mathematical transform should not silently repair invalid values.

Invalid model parameters, such as a severity outside Machado's documented domain, must have an explicit API contract rather than relying on accidental matrix indexing behavior.

## Allocation and D attributes

The transform should be a value operation with no required allocation.

Where supported by the implementation, public mathematical operations should be:

```
@safe pure nothrow @nogc
```

CTFE should be promised only after an executable production test establishes it.

## CTFE and table storage

Machado's 33 matrices are small enough to be represented as immutable compile-time data. That makes a CTFE-capable implementation technically plausible.

The consumer does not need a runtime-loaded model table for ordinary use.

This does not mean the library should generate themes or other derived assets at CTFE. It only means the mathematical CVD transformation may be evaluated at compile time when the caller chooses to do so.

## Candidate minimal API

The minimum production surface suggested by the evidence is:

```
CvdDeficiency
    .protan
    .deutan
    .tritan

brettelDichromat(...)
vienotDichromat(...)
machado(...)
```

with model-specific constraints documented by each callable.

A generic dispatch function may be considered later only if it can preserve the model-specific contracts without creating ambiguous parameters.

## Promotion gate

Before production promotion, R7 must additionally demonstrate:

1. exact production-callable reference vectors;
2. float/double error envelopes;
3. CTFE/runtime equivalence for each promoted callable;
4. non-finite behavior;
5. gamut-preservation behavior;
6. @safe/@nogc/pure/nothrow compile probes;
7. benchmark evidence for representative workloads;
8. consumer composition with existing deltaEOK/WCAG measurements;
9. Ddoc and unittest coverage for every public callable.

## Current decision

**API boundary defined; production implementation deferred.**

The research supports model-specific CVD transformation functions. It does not justify a universal `severity` parameter or an accessibility-policy helper.

No production code is changed by R7.
