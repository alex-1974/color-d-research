# R7.3 — Machado 2009 severity model

## Scope

R7.3 studies the Machado, Oliveira & Fernandes (2009) model as a separate CVD model family. It does not make severity a universal parameter across Brettel, Viénot and Machado.

The paper describes a physiologically based model derived from electrophysiological data and intended to handle normal colour vision, anomalous trichromacy and dichromacy in a unified model. Experimental evaluation involved people with CVD and normal colour vision. citeturn0search0

## Severity semantics

The independent DaltonLens reference documents Machado severity on a continuous scale from 0 to 1. It uses the published matrices at 0.1 increments and linearly interpolates between adjacent tabulated matrices for intermediate severity values. Severity 1 represents full dichromacy in that implementation. citeturn0search1turn1search0

This is different from merely interpolating Brettel output with the original color: Machado's matrices are the model's severity-dependent transformations.

The implementation evidence also shows that the model is applied to **linear RGB**, with sRGB decoding before the matrix and encoding afterwards. citeturn0search2turn0search5

## Published/reference matrix family

The reference table contains ten increments between normal vision and the full-severity endpoint. The following endpoint matrices are independently reproduced by multiple implementations:

### Protan, severity 1

```
[ 0.152286  1.052583 -0.204868 ]
[ 0.114503  0.786281  0.099216 ]
[-0.003882 -0.048116  1.051998 ]
```

### Deutan, severity 1

```
[ 0.367322  0.860646 -0.227968 ]
[ 0.280085  0.672501  0.047413 ]
[-0.011820  0.042940  0.968881 ]
```

### Tritan, severity 1

```
[ 1.255528 -0.076749 -0.178779 ]
[-0.078411  0.930809  0.147602 ]
[ 0.004733  0.691367  0.303900 ]
```

The complete 0.1-step table is preserved in the R7.3 probe rather than being rounded into a smaller production table. The source table is independently reproduced in public implementations and reference material. citeturn3search0turn3search2

## Tritan limitation

The DaltonLens review explicitly warns that Machado 2009 does not work well for tritanopia. Its simulator therefore treats Machado as useful for anomalous protan/deutan modelling but does not regard it as a strong tritan reference. citeturn0search1turn0search5

This is an important production boundary: implementing the published tritan matrix is not equivalent to claiming that it is a validated tritan perception model.

## Gamut

The matrix transform itself does not define the final display gamut policy. Some implementations clamp the resulting linear-RGB channels before re-encoding, while other research workflows preserve out-of-gamut values for diagnostics. The production library must therefore keep transformation and gamut policy separate.

## Model boundary

R7.3 establishes:

- Machado is a separate physiologically based model family;
- severity belongs to Machado's own model semantics;
- severity 0 is the identity endpoint;
- severity 1 is the complete-deficiency endpoint in the published/reference table;
- intermediate values use the published severity-dependent matrix family;
- transformations operate in linear RGB;
- protan and deutan are the stronger production candidates for severity modelling;
- tritan requires an explicit limitation and should not silently be presented as equally validated;
- no accessibility threshold is part of this model.

## Production API implication

A future API should make the model explicit rather than hide it:

```
Machado2009
    deficiency
    severity
    ↓
LinearSRgb
```

It should not expose a generic:

```
CvdTransform(deficiency, severity)
```

that implies that Brettel, Viénot and Machado share the same severity semantics.

A generic CVD deficiency enum may still be useful at a higher layer, but model-specific operations must retain their own contracts.

## R7.3 acceptance status

- [x] Machado model identified
- [x] severity domain documented
- [x] endpoint matrices recorded
- [x] linear-RGB boundary documented
- [x] independent reference identified
- [x] tritan limitation documented
- [x] complete severity table represented by probe
- [ ] numerical cross-check
- [ ] float/double error envelope
- [ ] CTFE/runtime equivalence
- [ ] production API decision

R7.3 therefore remains a research reference until its executable validation is complete.
