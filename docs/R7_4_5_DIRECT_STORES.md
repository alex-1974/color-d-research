# R7.4.5 — Direct RGB stores and split Brettel selection

## Question and measured source

Source: `72d4eab1b425bc71f61373b40e59e40d11e504bb`.
[Run 36908277016](https://github.com/alex-1974/color-d-research/actions/runs/36908277016)
passes DMD 2.111.0/2.113.0 and LDC 1.41.0/1.43.0.

The prior [prepared candidates](R7_4_5_PREPARED_CANDIDATES.md) left large float
gaps. In the measured LDC 1.43.0 Viénot float batch, two movss writes assemble
the red/green result in stack scratch; a movsd reads that scratch for an
aggregate output store. This motivates testing direct component stores rather
than assuming that explicit value-returning arithmetic fixes the problem.

Five variants run together:
- default: original per-item probes;
- prepared: coefficients once per batch and original Matrix3.apply;
- inline: explicit value-returning arithmetic;
- direct: prepared coefficients and direct output-component assignments;
  Brettel still selects a matrix value;
- split: direct stores plus separate first/second Brettel branches using the
  corresponding matrix by reference. Viénot is identical to direct.

Helpers compile as @safe pure nothrow @nogc; the new void helpers are marked
pragma(inline, true). Input channels are passed as scalar values before output
stores. Component precision, multiplication/addition order and plane comparison
>= 0 are preserved. Preparation stays inside each timed batch. Original
reference implementations and production color-d source/API remain unchanged.
There is no manual SIMD, fast-math, clipping or compiler-specific kernel fork.

## Validation and measurement

Debug preflights compare all candidate forms with the original probes over the
65536-color deterministic corpus, recorded non-finite/out-of-gamut/zero samples,
near-plane inputs, representative CTFE probes and attributed calls. The CTFE
wrapper accepts manifest plans by value and is not used by timed direct kernels.
The initial candidate commit failed because a manifest constant cannot bind
to the wrapper's const ref; the measured commit repairs only that wrapper.

Optimized -release binaries now also compare every component of every warmed
Brettel/Viénot batch with the original probe **before timing**. Explicit
exception checks remain active independently of assertions. This validates the
full generated finite corpus in the optimized batch path, not only sampled
checksums. Debug probes additionally cover the recorded edge inputs.
Tolerances remain float 2e-6 / double 1e-12, with NaN classification and infinity
equality in the edge probes. NaN payloads and signed-zero bits are not qualified.

All twenty measurement summaries report maximum sampled D/C++ checksum
differences of zero for float and double. This comparator shares coefficients;
it is a code-generation baseline, not an independent scientific oracle.
Independent numerical/reference-envelope qualification remains separate.

Each variant has 28 cases and 18 samples per language/case: 65536 items,
three warm-ups and nine rounds of sixteen batches in each order. Five variant
orders reverse on the second pass; each D binary has fresh paired C++ timings.
Full component validation is untimed and equal across D variants; its cache
effects relative to the C++ warm-up are a measurement limitation.

DMD uses -O -inline -release -boundscheck=on; LDC uses
-O3 -fp-contract=off -release -boundscheck=on; GCC C++ uses
-std=c++17 -O3 -ffp-contract=off -fno-fast-math.
Input/output allocation stays outside timing, and the timed attributed kernels
allocate no memory. Bounds checks remain on. See the
[baseline methodology](R7_4_5_PERFORMANCE_BASELINE.md) for input generation,
observable checksums and replay.

## Results

Protan medians, ns/item over 18 samples; ratios use C++ samples paired with
the direct variant in the same job.

| Compiler | Float kernel | Original | Prepared | Direct | Split | Direct/C++ |
|---|---|---:|---:|---:|---:|---:|
| ldc-1.41.0 | brettel | 13.166 | 10.114 | 2.465 | 2.452 | 1.11 |
| ldc-1.41.0 | vienot | 6.983 | 6.999 | 1.169 | 1.169 | 1.48 |
| ldc-1.43.0 | brettel | 12.905 | 12.587 | 2.456 | 2.468 | 1.11 |
| ldc-1.43.0 | vienot | 7.019 | 6.975 | 1.168 | 1.171 | 1.48 |
| dmd-2.111.0 | brettel | 42.567 | 29.535 | 15.847 | 12.895 | 7.17 |
| dmd-2.111.0 | vienot | 19.368 | 7.823 | 3.757 | 3.450 | 4.78 |
| dmd-2.113.0 | brettel | 35.580 | 19.004 | 10.949 | 8.600 | 7.35 |
| dmd-2.113.0 | vienot | 18.642 | 5.083 | 2.245 | 2.178 | 4.98 |

Across all three Brettel deficiencies, direct float stores yield about
5.3–5.7x the original LDC throughput. The paired LDC/C++ ratio falls to
1.11–1.14. Both Viénot deficiencies improve about 5.8–6.0x under LDC,
with a residual paired ratio of 1.48–1.49.

DMD improves as well, but substantial C++ gaps remain. Split matrix selection
further reduces DMD Brettel costs: protan double direct/split is 20.985/13.507
ns on DMD 2.111.0 and 12.690/8.191 on DMD 2.113.0; float is
15.847/12.895 and 10.949/8.600 respectively. Its extra benefit is not material
under LDC in this sequence. Direct and split Viénot have identical source
paths; their timing differences indicate placement/order/host variability.

LDC Brettel double retains the earlier large gain: protan direct is
3.852 ns with LDC 1.41.0 and 3.865 ns with 1.43.0, versus original
15.807/15.952 ns. LDC Viénot double still has no consistent win from prepared
direct arithmetic; on LDC 1.43.0 protan it is 1.113 versus original 0.930 ns.
Do not replace all paths on the strength of the float result.

Both LDC jobs and DMD 2.111.0 used EPYC 7763 runners; DMD 2.113.0 used EPYC
9V45. CPU affinity is recorded. Frequency, turbo, SMT, thermals and host load
are uncontrolled. Do not compare absolute timings across compiler jobs or
interpret small effects as controlled-hardware evidence.

## Generated code and decision

The current LDC direct Viénot float batch removes the result-packing scratch
writes/reads and shows packed floating-point multiply/add instructions.
Direct Brettel float also shows packed arithmetic but still has stack traffic
for prepared coefficients/register pressure. Thus direct stores do not remove
all stack use. Bounds-check failure paths remain visible.

Full disassembly of the four Brettel/Viénot batch functions for all five D
variants is committed with the measurements. Packed instructions alone do not
prove cross-color loop vectorisation or a complete causal explanation.
The source change and large measured gain support avoiding this aggregate
result form in the investigated float kernels.

**Decision:** retain direct stores and split selection as promising portable
research candidates. Direct float stores resolve most of the earlier LDC
penalty; split Brettel avoids a further measured DMD cost. No production API,
compiler fork or universal matrix-application replacement is accepted here.

The production performance gate stays open: residual LDC float gaps, DMD
code-generation gaps, Machado table representation, controlled consumer-machine
replay, broader workload shapes and independent numerical qualification remain.
The next performance slice should investigate the residual Viénot float loop
cost and preserve fixed-size Machado table information through lookup.

## Durable evidence

[Records for run 36908277016](../data/r7_4_5/run-36908277016/) contain 168 files:
all raw samples, min/median/max summaries, platform metadata, five Debug
preflights, binary hashes and complete relevant D batch disassembly excerpts.
Full binary disassembly and generated sources are additionally CI artifacts;
those artifacts expire. The tracked source, exact workflow build/run commands
and deterministic generator support replay.
