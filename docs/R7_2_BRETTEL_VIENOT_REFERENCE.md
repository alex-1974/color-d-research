# R7.2 — Brettel 1997 and Viénot 1999 reference transforms

## Purpose

R7.2 records the concrete linear-light RGB transforms used by an independent reference implementation and makes their model boundaries explicit. It is still research evidence, not a production API.

## Primary literature

Brettel, Viénot & Mollon (1997) describe dichromat simulation in LMS space as projection onto a reduced stimulus surface. For protan and deutan the defining monochromatic anchors are 575 nm and 475 nm; for tritan they are 660 nm and 485 nm.

Viénot, Brettel & Mollon (1999) describe replacement colourmaps for protanopes and deuteranopes based on LMS specifications of standard video-monitor primaries. The published scope is display checking for protan and deutan.

## Independent reference

DaltonLens/libDaltonLens provides a public-domain C implementation and states that its Brettel implementation uses the sRGB standard for linear RGB and the Smith & Pokorny 1975 LMS model, with two projection planes and a separation-plane normal. It provides precomputed linear-RGB matrices for protan, deutan and tritan.

The same reference provides single 3×3 linear-RGB matrices for Viénot 1999 protan and deutan and explicitly warns that its Viénot tritan matrix is not accurate for tritanopia; it uses Brettel for tritan instead.

## Brettel precomputed transforms

The independent reference gives the following two projection transforms for each deficiency:

### Protan

Plane 1:

```
[ 0.14980  1.19548 -0.34528 ]
[ 0.10764  0.84864  0.04372 ]
[ 0.00384 -0.00540  1.00156 ]
```

Plane 2:

```
[ 0.14570  1.16172 -0.30742 ]
[ 0.10816  0.85291  0.03892 ]
[ 0.00386 -0.00524  1.00139 ]
```

Separation-plane normal in linear RGB:

```
[ 0.00048  0.00393 -0.00441 ]
```

### Deutan

Plane 1:

```
[ 0.36477  0.86381 -0.22858 ]
[ 0.26294  0.64245  0.09462 ]
[-0.02006  0.02728  0.99278 ]
```

Plane 2:

```
[ 0.37298  0.88166 -0.25464 ]
[ 0.25954  0.63506  0.10540 ]
[-0.01980  0.02784  0.99196 ]
```

Separation-plane normal:

```
[-0.00281 -0.00611  0.00892 ]
```

### Tritan

Plane 1:

```
[ 1.01277  0.13548 -0.14826 ]
[-0.01243  0.86812  0.14431 ]
[ 0.07589  0.80500  0.11911 ]
```

Plane 2:

```
[ 0.93678  0.18979 -0.12657 ]
[ 0.06154  0.81526  0.12320 ]
[-0.37562  1.12767  0.24796 ]
```

Separation-plane normal:

```
[ 0.03901 -0.02788 -0.01113 ]
```

These values are **implementation-reference values**, not claimed here to be literal coefficient tables copied from the 1997 paper. The reference implementation explains how they are generated from its chosen LMS model, modern sRGB primaries, and RGB white as the neutral element.

## Viénot 1999

For protan and deutan, the same independent reference supplies:

Protan:

```
[ 0.11238  0.88762  0.00000 ]
[ 0.11238  0.88762  0.00000 ]
[ 0.00401 -0.00401  1.00000 ]
```

Deutan:

```
[ 0.29275  0.70725  0.00000 ]
[ 0.29275  0.70725  0.00000 ]
[-0.02234  0.02234  1.00000 ]
```

The matrices operate on **linear RGB**. The independent reference performs sRGB decoding before the transform and sRGB encoding afterwards.

No Viénot-1999 tritan production candidate is accepted by R7.2. The reference explicitly identifies its single-matrix tritan approximation as inaccurate and uses Brettel 1997 for tritan instead.

## Severity

Brettel and Viénot transforms in this reference are full-deficiency transforms. The reference applies severity by linear interpolation between the original linear-RGB vector and the simulated result. This is a **consumer/model parameterization**, not evidence that severity is a universal CVD API parameter.

Machado severity remains a separate R7.3 research topic.

## Boundary findings

R7.2 establishes:

- transformations operate in linear RGB;
- Brettel requires two projection transforms plus a separation-plane test;
- Viénot provides compact single-matrix transforms for protan and deutan;
- Viénot's tritan single-matrix approximation is explicitly rejected as a production reference;
- severity must remain model-specific;
- no gamut clipping/mapping policy is included in the mathematical transform;
- no accessibility decision is included.

## R7.2 acceptance status

- [x] Brettel protan transform recorded
- [x] Brettel deutan transform recorded
- [x] Brettel tritan transform recorded
- [x] Viénot protan transform recorded
- [x] Viénot deutan transform recorded
- [x] Viénot tritan limitation recorded
- [x] linear-RGB boundary recorded
- [x] independent reference identified
- [x] CTFE matrix application probe added
- [x] numerical cross-check against independent DaltonLens reference vectors
- [ ] float/double error envelope
- [x] runtime vs CTFE matrix equivalence (same pure arithmetic path)
- [ ] production API decision

R7.2 is therefore **reference extraction complete but validation incomplete**. It must not yet be promoted to `color-d`.


## R7.2 numerical cross-check

A small set of linear-RGB golden vectors was generated from the independent DaltonLens reference implementation and embedded in the D probe. The vectors cover black, white and three interior colors for all Brettel deficiencies and protan/deutan Viénot.

The cross-check is intentionally against the **independent implementation**, not against the coefficients merely re-entered into D. This establishes that the D-side matrix application and plane-selection logic reproduce the external reference values to the stated tolerance.

This is still not a claim that the selected reference implementation is the unique or universally correct interpretation of the original literature. The white-as-neutral choice, Judd-Vos handling and modern-sRGB adaptation remain explicit model assumptions.

The research therefore now has numerical implementation evidence, while production API selection remains deferred.
