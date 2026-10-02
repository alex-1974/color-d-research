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

Run on the XPS with the fixed compiler selected for this diagnosis. The phase-1 driver requires DMD 2.113.0 exactly and aborts on another DMD version:\n\n```sh\npython3 experiments/r7_4_5_cvd_performance/fp_state_diagnostic.py \\\n  --compiler /path/to/dmd-2.113.0 \\\n  --expected-dmd 2.113.0 \\\n  --output /tmp/color-cvd-fp-state\n```

Acceptance for moving to phase 2 is diagnostic, not a production performance
gate: the run must complete with fixed binaries, complete FP-state pairs and no
unexplained within-case FP-state mutation. A/A timing dispersion and binary
identity are evidence to inspect, not assumptions. Phase 2 will then vary code
placement deliberately while preserving the same kernels, FP state, workload,
affinity and output checksums. Only after placement is isolated should explicit
FTZ/DAZ state variation be combined with placement.


### Superseded preliminary XPS run

An initial XPS invocation reached all timed processes with DMD 2.111.0 before the
post-processing step failed on the hyphenated A/A variant names. The raw archive
is still useful as diagnostic evidence but is not the requested fixed-compiler
phase-1 result.

Both A/A rebuild pairs were byte-identical. MXCSR control bits and the x87
control word remained unchanged in every inspected before/after pair. MXCSR
changed only by sticky exception flag bit 5 (precision) from 0x1f80 to 0x1fa0
in the first arithmetic case of each process; this is an observed status flag,
not a change of FTZ, DAZ, rounding mode or exception masks. The driver now
separates MXCSR status flags from control-state changes and records both.

The preliminary A/A timing medians were centered close to 1.0, but individual
paired medians showed substantial outliers under the existing powersave/turbo/
thermal conditions. They therefore reinforce the need for balanced blocks and
do not justify a placement conclusion. Repeat phase 1 with DMD 2.113.0 before
advancing to deliberate placement variation.


## XPS FP-state diagnostic — DMD 2.113.0 result

Phase 1 completed successfully on the XPS at research revision
`29cc9c5813e6a6f4e7a5e056c83196043dee8dea`.

Evidence summary:

- DMD 2.113.0 was used as requested.
- 2,016 timing groups and 4,032 before/after FP-state records were produced.
- both duplicate indexed binaries were byte-identical;
- both duplicate reference binaries were byte-identical;
- zero FP control-state changes were observed;
- the only observed control state was MXCSR control `0x1f80` with x87
  control word `0x037f`;
- 72 MXCSR status changes were observed, all corresponding to sticky precision
  status being set during arithmetic, not FTZ/DAZ/rounding or exception-mask
  changes.

A/A timing is centered near unity but remains noisy. Across all paired medians,
the indexed duplicate median ratio was about 1.007 and the reference duplicate
median ratio about 1.003. Individual paired medians nevertheless ranged roughly
0.36–1.77 for indexed and 0.65–2.28 for reference. The host was still running
the powersave governor with turbo and SMT enabled, and observed thermal sensors
reached approximately 99–100 C during the run.

Decision: FP control-state mutation is not a supported explanation for the
earlier multifold movements. Because A/A timing still contains large isolated
outliers, placement testing must use multiple deterministic offsets, balanced
ordering, fixed binaries and per-block/per-direction evidence rather than
interpreting single comparisons.

## Code-placement diagnostic — phase 2

`placement_diagnostic.py` deliberately varies executable text placement while
keeping the D source kernels, compiler, compiler flags, workload and FP-control
instrumentation unchanged.

For each indexed/reference family it builds text-padding variants of 0, 64, 128,
256, 512 and 1024 bytes. The padding object is linked ahead of the unchanged D
sources. Before any timing is accepted, the driver records demangled symbol
addresses and requires at least one targeted benchmark symbol to change its
offset within a 4 KiB page. Full disassembly, symbol tables, binary hashes,
placement modulo 64/modulo 4096, FP-state evidence and balanced raw timing are
preserved.

Run on the same XPS:

```sh
python3 experiments/r7_4_5_cvd_performance/placement_diagnostic.py \
  --compiler "$HOME/dlang/dmd-2.113.0/linux/bin64/dmd" \
  --expected-dmd 2.113.0 \
  --cc gcc \
  --output /tmp/color-cvd-placement-213
```

A failed placement-validation check is a useful result: it means the linker did
not place the padding object ahead of the measured D text and the layout method
must be changed before timing data is interpreted.


## Code-placement diagnostic — phase 2 result

The XPS phase-2 placement run completed successfully at revision
`f4a8aa0566c8bb86f95d363830658862bd99ef8a` with DMD 2.113.0.

Evidence summary:

- 216 raw process outputs;
- 6,048 timing groups;
- 0 FP control-state changes;
- the only observed FP control state remained MXCSR control `0x1f80` and
  x87 control word `0x037f`;
- all 12 targeted symbols moved under the 64/128/256/512/1024-byte padding
  variants;
- normalized instructions for every targeted function were identical within
  each indexed/reference family across all padding variants;
- the padding changed target offsets within a 4 KiB page, but because every
  increment was a multiple of 64 bytes, each target's offset modulo 64 remained
  unchanged.

For Viénot, after taking the median across the three blocks for each logical
case/direction, the placement-to-p0 median ratios were close to unity. Indexed
medians were approximately 1.000, 1.010, 1.013, 1.000 and 1.000 for the
64/128/256/512/1024-byte variants. Reference medians were approximately 1.003,
1.007, 1.000, 1.000 and 1.002. Unchanged Brettel, prepared, lookup and
lookup+apply controls showed similarly small central movements together with
isolated large outliers.

Decision: changing the 4 KiB page offset while preserving mod-64 code alignment
does not reproduce the earlier multifold timing movements. The phase-2 evidence
therefore does not support page-offset placement as the primary cause.

A more targeted alignment question remains. In the p0 binaries, the float
Viénot batch entry is at mod-64 20 in the indexed family and mod-64 4 in the
reference family, while the corresponding double batch entry is mod-64 0 in
both families. Because phase 2 preserved those mod-64 positions, it could not
test cache-line/code-alignment sensitivity directly.

## 64-byte alignment diagnostic — phase 3

`alignment_diagnostic.py` keeps the same DMD 2.113.0, kernels, FP-state
instrumentation, workload, affinity, balanced ordering, hashes, symbols and
disassembly, but uses 0/16/32/48-byte text padding.

Before accepting timing evidence, it requires the target symbols to change
their address modulo 64. This isolates the remaining code-alignment hypothesis
without yet changing floating-point controls or production code.

Run on the same XPS:

```sh
python3 experiments/r7_4_5_cvd_performance/alignment_diagnostic.py \
  --compiler "$HOME/dlang/dmd-2.113.0/linux/bin64/dmd" \
  --expected-dmd 2.113.0 \
  --cc gcc \
  --output /tmp/color-cvd-alignment-213
```


## 64-byte alignment diagnostic — phase 3 result

The XPS phase-3 alignment sweep completed successfully at revision
`dc5d40c01968b5b8220253f6c16476b13e3821ab` with DMD 2.113.0.

Integrity and controls:

- all archive hashes verified;
- 144 raw process outputs;
- 4,032 timing groups;
- all 12 targeted symbols changed address modulo 64;
- zero FP control-state changes;
- the only FP control state remained MXCSR control `0x1f80` and x87
  control word `0x037f`;
- 144 MXCSR changes were sticky precision-status changes only.

Unlike the 4 KiB-offset sweep, this run produced a strong repeatable Viénot
alignment pattern.

After taking the median across the three blocks for each logical
scalar/deficiency/size/direction case and then comparing each padding variant
with p0:

| family | scalar | p16 / p0 median | p32 / p0 median | p48 / p0 median |
| --- | --- | ---: | ---: | ---: |
| indexed | float | ~0.654 | ~1.003 | ~0.672 |
| indexed | double | ~0.640 | ~0.977 | ~0.661 |
| reference | float | ~0.997 | ~1.034 | ~1.023 |
| reference | double | ~0.648 | ~1.024 | ~0.663 |

The indexed-float, indexed-double and reference-double pattern persists in all
three blocks and in both execution directions. Typical per-block/direction
median ratios for p16 and p48 are approximately 0.58–0.75, while p32 returns
close to p0. Reference-float remains approximately alignment-insensitive.

The entry offsets for the Viénot batch kernel are:

- indexed float: p0=20, p16=36, p32=52, p48=4 modulo 64;
- indexed double: p0=0, p16=16, p32=32, p48=48 modulo 64;
- reference float: p0=4, p16=20, p32=36, p48=52 modulo 64;
- reference double: p0=0, p16=16, p32=32, p48=48 modulo 64.

The alternating p0/p32 versus p16/p48 behavior in both double families, and the
same 16-byte phase shift in indexed float, is consistent with a 32-byte-periodic
front-end/code-layout effect. The experiment does not establish whether the
responsible mechanism is instruction fetch, decode, uop-cache placement, a
specific internal branch/loop alignment, or another microarchitectural detail.
It also shifts every later text symbol together, so it does not identify the
specific responsible function yet.

Decision: code alignment is now a supported candidate explanation for at least
part of the previously unexplained DMD timing movement. It is not yet a
production optimization rule. A finer sweep is required to map the periodicity
and separate entry-point alignment from internal-loop/helper alignment.

## Fine alignment diagnostic — phase 4

Phase 4 uses 0/8/16/24/32/40/48/56-byte padding. It retains the same DMD 2.113.0
compiler, kernels, correctness checks, FP-state capture, CPU affinity, binary
hashes and balanced forward/reverse blocks.

The goals are:

1. determine whether the observed effect is genuinely 32-byte periodic;
2. locate the transition region within the 64-byte window;
3. compare Viénot with unchanged Brettel/prepared/lookup controls;
4. provide enough evidence to design a later function-local alignment probe
   rather than adopting global text padding as a workaround.


## Fine alignment diagnostic — phase 4 result

The XPS fine alignment sweep completed successfully at revision
`b7a0ab2dffebe1981c0d70c1efb368a9fae5dd6d` with DMD 2.113.0.

Integrity and controls:

- status: passed;
- 8,064 timing groups;
- all 12 targeted symbols changed address modulo 64;
- zero FP control-state changes;
- the only FP control state remained MXCSR control `0x1f80` and x87
  control word `0x037f`;
- 288 MXCSR changes were sticky precision-status changes only;
- the host still used the powersave governor with turbo and SMT enabled and
  reached approximately 99 C on the hottest observed sensor.

For Viénot, after first taking the median across the three blocks for each
logical scalar/deficiency/size/direction case, the padding-to-p0 ratios were:

| family | scalar | p8 | p16 | p24 | p32 | p40 | p48 | p56 |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| indexed | float | 1.013 | 0.682 | 0.674 | 1.008 | 1.008 | 0.677 | 0.685 |
| indexed | double | 1.000 | 0.673 | 0.674 | 1.000 | 0.984 | 0.680 | 0.673 |
| reference | float | 1.000 | 1.000 | 1.000 | 0.997 | 0.997 | 1.000 | 1.000 |
| reference | double | 1.005 | 0.655 | 0.666 | 1.004 | 1.000 | 0.662 | 0.663 |

Thus the affected Viénot kernels have a broad fast window at +16/+24 bytes and
again at +48/+56 bytes, separated by slow/baseline windows at +0/+8 and
+32/+40. This is consistent with a 32-byte-periodic layout effect with an
approximately 16-byte-wide favorable phase.

However the fine sweep also shows that the global text padding affects other
kernels. In particular Brettel exhibits a related 32-byte-periodic movement in
several scalar/family combinations, while lookup, prepared and lookup+apply are
mostly much less sensitive. Therefore the current evidence supports a
front-end/code-layout effect but does not establish that the Viénot batch
function itself is the sole responsible code region.

Decision: do not introduce a production alignment workaround. The next probe
must vary one measured kernel's local layout while keeping downstream/global
text layout as constant as practical, and must verify the resulting symbol
addresses and normalized code before timing.
