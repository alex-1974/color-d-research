# R7.4.1 — Fixed CVD reference corpus

This corpus fixes the first regression vector set for the R7 production-validation work.

Models:
- `bp`: Brettel protan
- `bd`: Brettel deutan
- `bt`: Brettel tritan
- `vp`: Viénot protan
- `vd`: Viénot deutan

Inputs and expected outputs are **linear RGB**. Values outside 0..1 are intentional: the CVD transform must not silently clip.

The expected values are frozen from the independent research/reference matrices already validated in R7.2. They are regression data; CI must not regenerate them from the implementation under test.

The corpus covers black, white, neutral gray, RGB primaries, RGB secondaries, and three interior colors. It deliberately includes out-of-gamut transformed results.

This is the initial corpus. Machado severity vectors will be added as a separate table because its severity dimension is model-specific.
