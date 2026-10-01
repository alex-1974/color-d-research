# R6 — CIE colour difference research

**Consumer issue:** color-d #162  
**Research issue:** #1  
**Status:** active

## Scope

Determine the smallest generic CIE colour-difference surface justified for color-d.

The existing library already provides `deltaEOK` for Oklab. This research therefore does not assume that adding CIELAB or CIEDE2000 is automatically required. It tests whether standardized CIE workflows provide an independent interoperability capability worth promoting.

## Established external evidence

### CIELAB / Delta E 1976

ISO/CIE 11664-4 defines the CIE 1976 L*a*b* colour space and Euclidean colour difference. CIE describes CIELAB as a more-nearly-uniform space than tristimulus space and explicitly defines the Euclidean colour-difference calculation.

Reference:
- https://cie.co.at/publications/colorimetry-part-4-cie-1976-lab-colour-space-1
- https://www.cie.co.at/eilvterm/17-23-077

### CIEDE2000

ISO/CIE 11664 Part 6 defines the CIEDE2000 colour-difference formula as an extension of CIE 1976 L*a*b* colour difference, with corrections for lightness, chroma, hue and chroma-hue interaction. The standard specifies reference conditions and applies to CIELAB coordinates calculated according to ISO/CIE 11664-4.

References:
- https://www.cie.co.at/publications/colorimetry-part-6-ciede2000-colour-difference
- Sharma, Wu & Dalal (2005): https://onlinelibrary.wiley.com/doi/10.1002/col.20070
- Supplementary implementation data: https://hajim.rochester.edu/ece/sites/gsharma/ciede2000/

Sharma et al. specifically document implementation pitfalls, supplementary test data and small mathematical discontinuities. These are therefore part of the validation plan rather than implementation trivia.

## Architectural boundary

color-d should provide:

- explicit CIE colour representation only where independently justified;
- explicit XYZ/reference-white/adaptation semantics;
- explicit named difference algorithms;
- deterministic value-based operations;
- no consumer-specific perceptual thresholds.

color-d should not provide:

- accessibility decisions;
- just-noticeable-difference thresholds;
- theme semantics;
- UI policy;
- automatic selection between Delta-E algorithms.

## Reference-white question

The existing color-d XYZ type is explicitly **XYZ D65**. CIELAB is defined relative to a reference white, so a promotion cannot silently treat D65 as universal. Research must establish whether the minimum public surface should:

1. expose only a D65-bound CIELAB type;
2. expose a generic reference-white form;
3. keep CIELAB as an internal intermediate for CIEDE2000.

The answer must be driven by concrete use and interoperability rather than API breadth.

## Planned evidence

- R6.1: reference-white and adaptation boundary
- R6.2: CIELAB forward/reverse reference vectors
- R6.3: Delta E 1976 reference vectors
- R6.4: CIEDE2000 standard and supplementary vectors
- R6.5: zero-chroma and hue singularities
- R6.6: finite/non-finite and extended-value behavior
- R6.7: float/double and CTFE/runtime behavior
- R6.8: consumer-shaped validation and promotion decision

## Preliminary conclusion

The standards establish that CIELAB and Delta E 1976 are distinct standardized capabilities, while CIEDE2000 is a named CIELAB-based formula with defined reference conditions. That establishes generic legitimacy but does **not** yet establish that every component belongs in color-d.

Promotion remains evidence-gated.


## R6.1 result direction

Current external specification evidence identifies a meaningful boundary between the existing color-d XYZ D65 core and CIELAB workflows: current CSS Color 4 conversion guidance uses D50 for Lab and an explicit linear-Bradford adaptation from D65. The adaptation must therefore be visible in the architecture rather than silently treating XYZ D65 coordinates as Lab-relative-to-D50 coordinates.

R6.1 probe:
- D65 → D50 white mapping
- D50 → D65 round-trip
- CTFE execution

R6.2 probe:
- CIELAB forward conversion using the standard epsilon/kappa formulation
- reverse conversion
- reference-vector envelope
- explicit D65/D50 distinction
- CTFE execution

The CIELAB probes use a local CTFE-safe signed cube-root implementation for research purposes; this is not evidence that the production implementation should copy that helper. Production code must reuse the established color-d CTFE strategy after the API is settled.


## R6.3 result

R6.3 adds an executable Delta E 1976 baseline. The probe verifies the Euclidean CIELAB difference against the standard Sharma/Wu/Dalal supplementary pair, plus zero-distance, symmetry, and CTFE. This establishes Delta E 1976 as a simple generic metric candidate; it does not yet establish that CIELAB itself must become a broad public color model in color-d.
