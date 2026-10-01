# R7.4.5 — Combined BV qualification

The existing `bv_split` source already combines direct RGB stores with split
Brettel selection; Viénot uses direct stores in both `bv_direct` and `bv_split`.
The XPS replay measured that combination. This slice strengthens its semantic
qualification and repeats all three sizes on the four-compiler CI matrix,
without changing the timed kernel or introducing another equivalent variant.

`bv_qualification.d` checks float and double, all three Brettel deficiencies
and both Viénot deficiencies. Each scalar has 4,096 deterministic extended
RGB inputs, a 12 cubed edge cross-product (NaN, infinities, zero, normal and
subnormal magnitudes), and 15 points near stored separation planes: 5,839 inputs
in total. Separate tests use distinguishable synthetic plane matrices to check
positive/negative/equality branch selection. CTFE probes and explicit
`@safe pure nothrow @nogc` callers cover direct, split and in-place stores.

The checker returns failure explicitly; its checks remain active under
`-release`. Debug and optimized Release both run it before benchmarking.
It uses the existing absolute component tolerances (float 2e-6, double 1e-12)
and IEEE classification comparisons. It does not assert exact subnormal bits,
NaN payloads, signed-zero output bits, or independent model accuracy.

The workflow measures default/prepared/direct/split over sizes 1024/8191/65536,
three balanced blocks and 54 samples per language/case. Existing release full
corpus checks, C++ pairing, bounds checks and build flags remain in place.
Non-targeted Machado operations remain controls. CI clocks, thermals and SMT
are uncontrolled; differences across separate compiler jobs do not establish
an absolute compiler ranking.

Status: source prepared; four-compiler qualification and interpretation pending.
Production performance acceptance and independent model/API gates remain open.
