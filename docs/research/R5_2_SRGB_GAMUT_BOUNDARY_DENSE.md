# R5.2 — dense sRGB gamut-boundary characterization

**Status:** WORKING EXPERIMENT
**Parent:** color-d v0.2.0 issue #161
**Document revision:** 0.1
**Date:** 2026-09-30
**GitHub:** alex-1974/color-d#161

R5.2 extends the independent R5.1 binary-search oracle to a dense grid:
99 interior lightness slices by 360 integer-degree hues (35,640 samples), in
both `double` and `float`.

The probe records maximum bisection count, maximum bracket growth, and the
largest observed float-vs-double boundary difference while preserving strict
inside/outside assertions independently for each scalar type.

This stage deliberately does not yet adopt the Ottosson cusp/Halley algorithm.
Ottosson shows that fixed-hue Oklab RGB components are cubic and supplies a
cusp plus Halley-refined gamut-intersection method. For constant-lightness
projection that method is a strong optimization candidate, but it must first
be compared against this dense oracle rather than replacing the oracle.

CSS Color 4 independently documents constant-lightness/constant-hue chroma
reduction and notes binary search as a typical iterative implementation.
Its gamut-mapping policy and JND behavior are outside this boundary-measurement
experiment.
