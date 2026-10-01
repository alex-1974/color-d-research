# R5.3 — sRGB gamut boundary: Ottosson cusp/Halley comparison

Status: WORKING EXPERIMENT  
Document revision: 0.1  
Date: 2026-09-30  
Parent: color-d #161

## Question

Can Björn Ottosson's sRGB gamut-intersection construction provide a substantially
cheaper implementation of the constant-lightness, constant-hue maximum-chroma
query while satisfying color-d's strict boundary contract?

## Reference

Björn Ottosson, "sRGB gamut clipping" (2021), especially
`compute_max_saturation`, `find_cusp`, and `find_gamut_intersection`.

The published construction uses a fitted maximum-saturation estimate followed
by one Halley step. The reference text notes an exceptional blue-hue region and
states that two or three iterations can be used when higher accuracy is needed.

## Method

Compare the cusp/Halley candidate against the independent R5.1/R5.2 binary
oracle on 99 interior lightness slices and all 360 integer-degree hues:
35,640 samples per compiler.

The constant-lightness specialization is algebraically checked against the
published general `find_gamut_intersection(a, b, L1, C1, L0)` with
`L0 == L1 == L` and `C1 == 1`.

Compilers:
- DMD 2.113.0
- LDC 1.43.0

## R5.3 one-step result

Both compiler jobs completed successfully.

DMD:
- samples: 35,640
- fast candidate outside strict cube: 20,584
- below oracle inside: 15,017
- above oracle outside: 20,593
- maximum absolute error: 0.0058705750989262451
- relative error at worst sample: 0.020659918977084739
- worst sample: L=0.49, h=264 degrees
- oracle C=0.28415286165631543
- fast C=0.27828228655738918

LDC:
- samples: 35,640
- fast candidate outside strict cube: 20,584
- below oracle inside: 15,033
- above oracle outside: 20,588
- maximum absolute error: 0.0058705750989263006
- relative error at worst sample: 0.020659918977084933
- worst sample: L=0.49, h=264 degrees
- oracle C=0.28415286165631543
- fast C=0.27828228655738912

## Interpretation

The result is not evidence that the general cusp/Halley construction is
unsuitable. It is evidence that the published one-step approximation is not
sufficient by itself for color-d's stricter maximum-directly-representable
chroma contract.

The worst sample lies in the blue region called out by the reference as an
accuracy exception for the one-step maximum-saturation approximation.

The strict inside/outside counts also show that returning the raw fast
candidate would not satisfy a contract requiring the returned value itself to
be directly representable.

## Next experiment

Repeat the dense comparison with two and three Halley refinements in the
maximum-saturation/cusp computation, keeping the binary oracle unchanged.

Record:
- maximum absolute and relative error;
- strict in-gamut/out-of-gamut classification;
- compiler agreement;
- operation/iteration cost.

Only after that comparison should color-d choose between:
- binary search;
- refined cusp/Halley;
- a fast estimate followed by a small bounded correction;
- another exact/numerical boundary method.


## R5.9 final contract result

R5.9 passed on DMD 2.113.0 and LDC 1.43.0 with 35,640 samples per scalar/iteration configuration. The independent bisection oracle was used as the correctness reference.

Observed maximum boundary error:

| scalar | iterations | max absolute error | max relative error | max bracket width |
| --- | ---: | ---: | ---: | ---: |
| float | 12 | 1.2204051e-4 | 1.73114e-2 | 1.2207031e-4 |
| float | 16 | 7.5995922e-6 | 1.11196e-3 | 7.6293945e-6 |
| float | 20 | 4.4703484e-7 | 6.79680e-5 | 4.7683716e-7 |
| float | 24 | 7.3341653e-9 | 4.24067e-6 | 2.9802322e-8 |
| double | 16 | 7.6174127e-6 | 1.11192e-3 | 7.6293945e-6 |
| double | 20 | 4.7613639e-7 | 6.79343e-5 | 4.7683716e-7 |
| double | 24 | 2.9760155e-8 | 4.24600e-6 | 2.9802322e-8 |
| double | 32 | 1.1629026e-10 | 1.67187e-8 | 1.1641532e-10 |

All tested configurations kept the returned lower endpoint in gamut and preserved the oracle bracket. Domain and hue-periodicity checks passed, as did CTFE evaluation for float and double.

The result supports fixed-iteration bisection as the correctness baseline. Any accelerated Cusp/Halley/Ottosson-derived implementation must preserve this boundary contract and be validated against the independent oracle; R5.9 does not justify promoting an accelerated approximation merely because it is faster.
