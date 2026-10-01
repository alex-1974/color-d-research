# R5.1 — sRGB gamut-boundary query baseline

**Status:** WORKING EXPERIMENT
**Parent:** color-d v0.2.0 issue #161
**Document revision:** 0.1
**Date:** 2026-09-30
**GitHub:** alex-1974/color-d#161

## Question

For finite OKLCH lightness `L` in `[0, 1]` and finite hue `h`, determine
the maximum canonical non-negative chroma `C` whose Oklab conversion is
directly representable by linear-light sRGB components in `[0, 1]`.

This is a boundary measurement. It is deliberately separate from gamut
mapping, clipping, JND policy, and consumer theme policy.

## Domain

- `0 < L < 1`: search from the in-gamut neutral anchor at `C = 0`.
- `L == 0` or `L == 1`: boundary chroma is exactly zero.
- finite `L` outside `[0, 1]`: invalid for this measurement contract.
- non-finite `L` or hue: invalid.
- finite hue revolutions are equivalent after direction normalization.

## Baseline method

The correctness baseline uses direct Oklab -> linear-sRGB equations and a
strict cube-membership predicate. It does not call a color-d gamut mapper.

1. Start with an in-gamut lower bracket `C = 0`.
2. Grow a positive upper bracket until the converted point leaves the
   linear-sRGB unit cube.
3. Bisect the bracket.
4. Keep the lower side strictly in gamut.
5. Stop when scalar progress can no longer refine the bracket or the selected
   reference tolerance is reached.

The production implementation is not required to use this algorithm. This
baseline exists to define and validate the mathematical result independently.

## Reference rationale

CSS Color 4 describes constant-lightness, constant-hue chroma reduction toward
an RGB gamut and notes binary search as a typical iterative implementation.
Its Local MINDE mapping policy is **not** part of this experiment.

Björn Ottosson's Oklab gamut-clipping derivation provides a second algorithmic
route based on gamut cusps and Halley refinement. That route is a candidate
optimization after the baseline has established reference behavior; fitted
constants are not imported into the correctness oracle.

## Required evidence

The experiment must characterize:

- `float` and `double`;
- endpoint lightness;
- hue periodicity;
- primary/secondary and intermediate hue directions;
- low/high lightness;
- cube-face and cusp-neighborhood transitions;
- the in-gamut lower bracket and out-of-gamut upper neighbor;
- CTFE feasibility for a production-equivalent fixed-iteration form;
- iteration count and runtime cost before any fast-path promotion.

Reference vectors must not be generated solely by the eventual production
implementation.

## Promotion gate

Promote only if a compact scalar measurement contract can be documented
truthfully with deterministic error behavior, `@safe pure nothrow @nogc`
implementation, float/double support, and practical CTFE/runtime cost.
