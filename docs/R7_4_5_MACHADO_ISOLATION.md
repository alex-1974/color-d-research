# R7.4.5 — Machado process isolation

**Status:** diagnostic slice complete; the earlier multifold control movements are not reproduced or explained. No production change or integrated performance winner is selected.

Measured source: `bb8f2a9bb129ac58e0ff23653145375b2af0b085`. Original benchmark source rebuilt for the paired comparison: `bc2c387e933469901cd8c2d2cedfe0b700db9f5f`. Branch: `research/163-cvd-transformations` in `alex-1974/color-d-research`.

## Question and result

The [reference-iteration experiment](R7_4_5_VIENOT_REFERENCE.md) reported DMD 2.113 float Machado lookup becoming about seven times slower and double lookup about five times faster when an unrelated Viénot source shape changed. Those movements persisted across sizes and blocks despite matching normalized control instructions. They cannot be attributed to changed Machado arithmetic or dismissed as ordinary sample noise.

This experiment separates Machado lookup and prepared matrix application into different executables. It also rebuilds the original integrated entry point and the new entry point on the same host. Neither the original integrated pair nor the isolated programs reproduce the earlier multifold pattern on the measured hosts. This narrows the evidence, but does not establish the cause of the older results. The earlier reference experiment used an AMD EPYC 9V45 host for DMD 2.113; the final paired experiment uses an EPYC 7763. Different sessions and CPUs remain material confounders.

The absence of the anomaly does **not** turn the earlier integrated benchmark into a qualified selection result. In particular, there is no basis here for a compiler-version threshold or a production workaround.

## Implementation and protocol

`bench.d` adds two compile-time entry-point selections:

- `IsolateLookup`: run only the existing `runLookup` cases.
- `IsolatePrepared`: run only the existing prepared-matrix `runCase` cases.

The batch and lookup kernels, coefficient tables, arithmetic precision and grouping, changing runtime inputs, checksums, and release-active component checks remain unchanged. There is no new pointer code or change to the `@safe pure nothrow @nogc` kernels. Matrix preparation and allocations remain outside timed sections. Preparation is at severity 0.65; lookup retains the varying `(i + shift) % 1001 / 1000` severity schedule.

`isolate.py` builds six optimized, bounds-checked executables:

| Label | Entry point | Viénot selection |
|---|---|---|
| `oldindex` | original integrated `bench.d` | indexed |
| `oldreference` | original integrated `bench.d` | reference iteration |
| `index` | current integrated `bench.d` | indexed |
| `reference` | current integrated `bench.d` | reference iteration |
| `lookup` | lookup only | original Machado lookup |
| `prepared` | matrix application only | original prepared application |

The original source is fetched from the pinned Git commit, with compilation filenames preserved as `bench.d`. Every other file in the original 11-file experiment snapshot must match the current snapshot byte for byte. Separate complete source layouts run the same generator; generated files are independently checked for exact agreement. No archived executable is reused for timing.

DMD uses `-O -inline -release -boundscheck=on`; LDC uses `-O3 -fp-contract=off -release -boundscheck=on`. All binaries are built once, hashed before measurement, and checked again afterward. Timed processes are pinned to the smallest allowed CPU. Three blocks rotate and reverse executable order; size order reverses in the middle block. Each process runs one size, forward or reverse case/scalar order, with three warmups, nine rounds and sixteen batch repetitions. Sizes are 1024, 8191 and 65536; all three deficiencies and both scalar types are covered. A pooled case has 54 rounds, a block has 18, and a direction has nine.

CPU affinity is controlled. Shared CI clocks, thermals, sibling activity and other host load are observed where available, but are not controlled. This is a D-to-D control investigation, not a new comparison against C++ or an independent scientific model qualification.

## Final paired results

Speedup is **original indexed median / comparison median**. Values above one mean the comparison is faster. Each range includes all three sizes and deficiencies. Original pair means `oldreference` versus `oldindex`; isolated means the corresponding separate executable versus `oldindex`.

| Compiler / host | Scalar | Lookup original pair | Lookup isolated | Prepared original pair | Prepared isolated |
|---|---|---:|---:|---:|---:|
| DMD 2.111 / EPYC 9V74 | float | 1.003–1.007 | 0.997–1.013 | 0.998–1.001 | 0.999–1.000 |
| DMD 2.111 / EPYC 9V74 | double | 0.998–1.006 | 0.996–1.005 | 0.998–1.000 | 0.999–1.000 |
| DMD 2.113 / EPYC 7763 | float | 1.004–1.019 | 1.003–1.016 | 0.999–1.001 | 0.996–1.000 |
| DMD 2.113 / EPYC 7763 | double | 0.999–1.005 | 0.990–1.002 | 0.996–1.006 | 0.999–1.005 |
| LDC 1.41 / EPYC 7763 | float | 0.958–1.024 | 0.986–1.023 | 0.997–1.000 | 0.997–1.011 |
| LDC 1.41 / EPYC 7763 | double | 0.998–1.003 | 0.993–1.002 | 0.996–1.003 | 0.997–1.024 |
| LDC 1.43 / EPYC 7763 | float | 0.966–1.026 | 0.967–1.033 | 0.996–1.001 | 0.975–1.007 |
| LDC 1.43 / EPYC 7763 | double | 0.996–1.004 | 0.996–1.005 | 0.995–1.001 | 0.981–1.005 |

DMD 2.113 original-pair block speedups are 0.999–1.022 for float lookup, 0.998–1.006 for double lookup, 0.996–1.003 for float prepared application and 0.979–1.013 for double prepared application. Thus the earlier persistent multifold control changes are absent in both pooled and block summaries on this host.

The original/current entry-point comparisons also stay close in pooled results: across both controls and scalar types, DMD 2.111 spans 0.992–1.005 and DMD 2.113 spans 0.987–1.008. Restoring the original entry source therefore does not recreate the older anomaly here.

These results are not uniformly quiet. DMD 2.111 original-pair blocks reach 0.842–1.250 for double lookup and 0.985–1.275 for float prepared application. Across all unchanged-control executable cases, forward/reverse direction-median ratios span 0.621–1.193 for DMD 2.111, 0.848–1.039 for DMD 2.113, 0.819–1.770 for LDC 1.41 and 0.521–2.210 for LDC 1.43. These isolated direction disturbances are retained; they do not match the earlier persistent binary-dependent pattern. Pooled medians alone cannot justify accepting small differences.

## Code generation

Targeted disassembly retains float/double lookup batches, prepared batches, and `matrixAtSeverity`, with binary hashes and function addresses modulo 64 and 4096. The integrated indexed/reference controls match normalized instructions under both DMD versions. The prepared loops and matrix helper also match across the separated DMD executables.

For the isolated float lookup, a strict symbol-offset comparison differs at the divisor literal's annotation: the nearest generated `_TMP` label and offset differ. Reading the referenced nonwritable ELF bytes verifies `00 00 7a 44`, the float value 1000, in every executable. An additional constant-content diagnostic replaces only read-only RIP operand annotations with their exact linked bytes. All three targeted DMD functions then match across every executable for both scalar types. Branch targets, branch conditions, arithmetic and all other operands remain in the comparison.

LDC lookup and matrix-helper sequences also match with that constant-content normalization. LDC's isolated prepared batch has a different normalized sequence, so no universal LDC code-equivalence claim is made.

This is instruction/constant equivalence, not proof of identical placement, cache behavior, floating-point execution state or host scheduling. Function addresses do vary. Neither address variation nor unchanged instruction sequences identifies the causal mechanism.

## Verification and retained evidence

Final source CI:

- [isolation: 36982005899](https://github.com/alex-1974/color-d-research/actions/runs/36982005899)
- [baseline: 36982005830](https://github.com/alex-1974/color-d-research/actions/runs/36982005830)
- [replay smoke: 36982005828](https://github.com/alex-1974/color-d-research/actions/runs/36982005828)
- [Debug/Release qualification: 36982005991](https://github.com/alex-1974/color-d-research/actions/runs/36982005991)

All 16 jobs passed. The existing qualifier continues to cover the numerical/IEEE, exact-in-place, tail, CTFE and attribute checks; this slice does not widen its preliminary numerical envelope or establish an independent oracle.

For the four final isolation ZIPs, independent read-only inspection verifies:

- ZIP digests against GitHub metadata, and 1,164 manifest entries;
- 492 successful commands and 432 CPU-pinned timed processes;
- all 24 fixed binary hashes;
- 80,352 raw rounds and exact reconstruction of 8,928 directional summaries, 4,464 block summaries and 1,488 pooled summaries;
- zero sampled unchanged-control checksum differences across all five relevant programs;
- all 12 tracked current-source Git blob hashes against GitHub, the original `bench.d` blob against its pinned commit, and byte agreement of the remaining original/current build dependencies and generated files.

The initial four-executable pass at `f2b0237f905e37f38b79da7d6e1bb4792a0e89d5`, [run 36981014454](https://github.com/alex-1974/color-d-research/actions/runs/36981014454), also passed. DMD 2.113 ran on a Xeon Platinum 8370C and had lookup reference/index pooled speedups of 1.031–1.036 for float and 0.997–1.004 for double. Its compact results are retained as supplemental observations, not a before/after performance claim. All four initial archives, their 760 manifest entries, 328 commands, 288 pinned processes and 44,064 raw rounds were checked; their 12 tracked source blobs were verified independently.

Superseded paired-build setup failures involved unavailable historical Git objects and incomplete generator layouts. They supply no timing evidence. Full Git history and two complete generator layouts are present in the final successful run.

Condensed evidence is under `data/r7_4_5/machado-isolation-36982005899/`; initial observations are in its `initial/` subdirectory. Artifact IDs, digests and expiry dates are retained there. Raw executable archives remain temporary CI audit artifacts. No downloaded executable was run during analysis.

Reproduce the measurement from the pinned source in an isolated research checkout:

```sh
python3 experiments/r7_4_5_cvd_performance/isolate.py --compiler dmd --output /tmp/color-cvd-isolation-dmd
```

Independently inspect a downloaded final artifact without executing its binaries:

```sh
python3 tools/inspect_machado_isolation.py isolation-dmd-2.113.0.zip /tmp/color-cvd-isolation-inspection
python3 tools/inspect_machado_isolation_codegen.py /tmp/color-cvd-isolation-inspection
```

The inspector's optional third positional argument supplies an expected source revision for a different run; the default pins the final measured revision. Network verification of source blob identity and the GitHub ZIP digest is separate from offline manifest/raw-report checks.

## Decision and next experiment

Keep the separate measurement programs and paired-source runner as research diagnostics. The previous multifold movements remain unexplained and are not used to select an integrated winner. No production policy or compiler support promise changes.

A useful next slice measures floating-point state before and after individual cases and deliberately varies code placement on one host with one fixed compiler. It should retain the original/reference control pair and explicit per-direction/block evidence. Those are hypotheses to test; no floating-point-state, compiler-defect or microarchitectural cause is established here. An unchanged consumer rerun is not requested.


## XPS FP-state / placement diagnostic — phase 1

The next investigation is implemented on branch `research/163-fp-placement-diagnostic`
without changing production policy or accepted CVD kernels. Phase 1 deliberately
precedes any placement perturbation.

`fp_state_diagnostic.py` builds the indexed and reference Viénot controls twice
from the same tracked source with DMD, records fixed binary hashes and disassembly,
pins every timed process to one CPU, and runs three balanced forward/reverse blocks
at 1024, 8191 and 65536 items. The duplicate A/A builds establish whether rebuild
identity and timing are quiet enough before a placement experiment is interpreted.

With `FpStateDiagnostic`, `bench.d` records MXCSR and the x87 control word
immediately before and after each benchmark case. The reads are outside the timed
region and use the small x86 helper `fp_state.c`. The driver retains every state
row in `fp-state.csv` and separately records any before/after mutation in
`fp-state-changes.csv`. It does not modify FTZ, DAZ or rounding mode in phase 1.

Run on the XPS with the fixed compiler selected for this diagnosis:

```sh
python3 experiments/r7_4_5_cvd_performance/fp_state_diagnostic.py \
  --compiler dmd \
  --output /tmp/color-cvd-fp-state
```

Acceptance for moving to phase 2 is diagnostic, not a production performance
gate: the run must complete with fixed binaries, complete FP-state pairs and no
unexplained within-case FP-state mutation. A/A timing dispersion and binary
identity are evidence to inspect, not assumptions. Phase 2 will then vary code
placement deliberately while preserving the same kernels, FP state, workload,
affinity and output checksums. Only after placement is isolated should explicit
FTZ/DAZ state variation be combined with placement.
