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


## Hardware-counter alignment diagnostic — phase 5

Phase 5 compares matched slow/fast global-alignment variants directly with
`perf stat`.

The probe builds p0 and p16 variants for indexed/reference and for isolated
Viénot/Brettel benchmark modes. It forces the C locale for machine-readable
counter output, preflights every requested event on the current kernel/PMU, and
requires at least `cycles` and `instructions`. Optional cache, branch and
frontend/backend-stall events are included only when the host can count them.

Each fast/slow pair is run in balanced order in forward and reverse benchmark
direction. The archive preserves binaries, disassembly, raw benchmark output,
raw perf output, parsed counters and p16/p0 counter ratios.

This phase is diagnostic only. A cycles reduction without an instruction-count
change would support a frontend/layout explanation; a corresponding movement in
frontend-stall counters would strengthen that interpretation. Absence of such a
counter signature would narrow, but not by itself disprove, the alignment
effect observed in wall-clock timing.


### XPS perf permission preflight

The first phase-5 XPS invocation did not reach benchmark execution because the
host had `kernel.perf_event_paranoid=4`. Under that policy even the required
`cycles` and `instructions` events were unavailable to the unprivileged
research process.

This is an environment/policy blocker, not a benchmark failure. For the
hardware-counter run, temporarily lower `kernel.perf_event_paranoid` to 0,
run the diagnostic as the normal user, and restore the original value
immediately afterwards. Do not make the setting persistent for this research
probe and do not run the benchmark itself under sudo, because changing the
execution user would introduce another variable.


## Hardware-counter alignment diagnostic — phase 5 result

The XPS phase-5 run completed successfully at revision
`67c403298c30bc00ff733cda770e41dba8c6953b` with DMD 2.113.0 after
temporarily lowering `kernel.perf_event_paranoid` for the measurement.

Available events were `task-clock`, `cycles`, `instructions`,
`branches`, `branch-misses`, `cache-references`, and `cache-misses`.
The generic `stalled-cycles-frontend` and `stalled-cycles-backend` aliases
were not available on this host.

The process-level matched p16/p0 result confirms that the alignment effect is
visible in hardware cycles rather than only in wall-clock accounting:

- isolated reference Viénot: task-clock/cycles median approximately 0.82
  forward and 0.85 reverse;
- instructions remained much closer to unity (approximately 0.98 and 0.99);
- isolated indexed Viénot was approximately neutral in both cycles and
  task-clock;
- isolated Brettel p16 was slower by roughly 9–11% in cycles/task-clock.

Parsing the benchmark's own per-scalar timing inside those same perf processes
shows why the reference Viénot process improves: reference-double p16 has a
median timing ratio of approximately 0.71 while reference-float is approximately
0.99. Indexed float/double are both approximately neutral in this reduced
binary. Thus the relevant phase is tied to the concrete code addresses in each
binary, not to the abstract label p16.

Because phase 5 multiplexed seven events in the same perf invocation, small
departures of the scaled instruction estimate from exactly 1.0 are not treated
as semantic/code-path changes. The next counter probe uses only cycles and
instructions to avoid unnecessary multiplexing.

Decision: the alignment effect is reflected in CPU-cycle consumption and is
compatible with a front-end/code-layout mechanism. The process-level counter
probe still contains both scalar instantiations, so the next step isolates one
kernel and one scalar per executable.

## Single-kernel/single-scalar alignment diagnostic — phase 6

`single_kernel_alignment_diagnostic.py` builds only the Viénot benchmark path
and only one scalar type per executable. It sweeps 0/8/16/24/32/40/48/56-byte
global padding, records the exact Viénot batch entry address modulo 64 and 4096,
and measures only `cycles` plus `instructions` to avoid counter
multiplexing.

The purpose is to correlate the measured fast/slow phase directly with the
active float or double Viénot kernel's concrete address. This is still research
evidence, not a production alignment workaround.


## Single-kernel/single-scalar alignment diagnostic — phase 6 result

The XPS phase-6 run completed successfully at revision
`b7f2d4e1392688c77284bb35cfd1c7eb71a6e375` with DMD 2.113.0.

The reduced executables materially improve localization because each benchmark
contains only Viénot and one scalar type. Two hardware events were measured:
`cycles` and `instructions`.

The strongest result is indexed-float. Its active function is
`candidates.indexedVienotBatch!float`, not `bv.vienotProbe` and not merely
the outer `bench.batch` wrapper. Its candidate entry phases and median ratios
were:

| candidate mod64 | representative pads | time / p0 | cycles / p0 | instructions / p0 |
| ---: | --- | ---: | ---: | ---: |
| 8  | p0/p8   | ~1.00 | ~1.00 | ~1.000 |
| 24 | p16/p24 | ~1.47 | ~1.42 | ~1.000 |
| 40 | p32/p40 | ~1.01 | ~1.00 | ~1.000 |
| 56 | p48/p56 | ~1.48 | ~1.43 | ~1.001 |

This is a repeatable 32-byte-periodic cycle-cost change with effectively
unchanged dynamic instruction count.

The outer `bench.batch!float` entry cannot explain the effect by itself:
indexed-float and reference-float have the same outer entry addresses under each
padding variant, yet reference-float remains approximately invariant. Their
active candidate kernels differ in source shape and generated size.

Disassembly localization strengthens the candidate-kernel interpretation.
`indexedVienotBatch!float` is 784 bytes in this build, whereas
`referenceVienotBatch!float` is 712 bytes. The indexed hot-loop backward
branch moves from mod64 63 in the p0 form to mod64 15 in p16 while the
instruction sequence is otherwise shifted with the section. The p16 form is the
slow form. This does not prove that the branch itself is causal, but identifies
the internal loop/code-region alignment as the next target.

DMD emits the candidate specialization into its own COMDAT text section, for
example the indexed-float specialization appears as a dedicated
`.text.<mangled indexedVienotBatch!float name>` section. This makes a
section-local alignment experiment possible without globally padding all text.

Other phase-6 combinations do not show one universal entry-address rule:
reference-float is largely insensitive; indexed-double is also near neutral in
this reduced build; reference-double shows smaller and noisier cycle movements
that do not track wall time as cleanly as indexed-float. Therefore no global
alignment rule is promoted.

Decision: the best-supported phenomenon is a code-layout sensitivity of the
indexed-float candidate kernel on DMD 2.113.0/x86-64. The next experiment should
alter only that candidate's COMDAT-section alignment and verify that the outer
wrapper and unrelated sections retain their addresses as far as the linker
permits.


## Function-local COMDAT-section alignment diagnostic — phase 7

DMD emits `candidates.indexedVienotBatch!float` into its own COMDAT text
section in the relocatable object. Phase 7 exploits that ELF structure instead
of adding global text padding.

The probe:

1. builds one indexed-float Viénot seed object with DMD 2.113.0;
2. identifies the unique `.text.<indexedVienotBatch!float>` section;
3. copies the exact same relocatable object;
4. changes only that section's ELF alignment requirement to 4, 16, 32 or 64
   bytes with `objcopy --set-section-alignment`;
5. relinks each object without recompiling the D source;
6. requires the outer `bench.batch!float` address to remain identical across
   all variants;
7. requires the candidate kernel's mod-64 address to change;
8. measures only cycles, instructions and the internal benchmark timing.

This is the narrowest experiment so far: source, candidate machine code and the
outer wrapper remain fixed, while only the link placement requirement of the
active candidate section changes. It is still research-only and does not imply
a production linker/alignment policy.


### Phase-7 first attempt rejected by control-address guard

The first COMDAT-alignment attempt changed the candidate section alignment
directly in the DMD object. The candidate moved, but the outer
`bench.batch!float` address also moved. The probe therefore aborted before
timing, as intended.

That method is superseded by a fixed-envelope linker experiment. The candidate
COMDAT section is renamed to `.text.colorD.target` and placed between
`.text.colorD.pre` and `.text.colorD.post` inside a dedicated output
section. Pre/post padding always totals 64 bytes while the split is varied
0/64, 16/48, 32/32 and 48/16. The complete probe section therefore has
constant size while the candidate moves locally inside it.

The revised probe rejects the run unless:

- the fixed-envelope output-section size is identical in all variants;
- `candidates.indexedVienotBatch!float` changes mod-64 placement;
- the outer `bench.batch!float` address is identical in every variant.

Only after those controls pass are cycles, instructions and wall-clock samples
collected.


## Function-local fixed-envelope placement diagnostic — phase 7 result

The revised phase-7 XPS run completed successfully at revision
`5df34b770b21d9e932a8478e4a36c8a90ab87e4e` with DMD 2.113.0.

All archive hashes verified.

The fixed-envelope controls passed:

- candidate addresses were 0x66800, 0x66810, 0x66820 and 0x66830,
  corresponding to mod-64 positions 0, 16, 32 and 48;
- the outer `bench.batch!float` address remained exactly 0x876c4
  (mod-64 4) in every variant;
- the generated `.color_d_probe` output section was constant at 0x350 bytes
  (848 bytes) in every variant.

The CSV `envelope_size` field incorrectly recorded zero because the first
parser version selected the wrong hexadecimal token from `readelf -SW`.
The raw section records show the correct invariant size of 0x350. This is a
harness-reporting bug only and does not affect placement or timing evidence.

With the outer wrapper fixed and only the candidate moved locally, the large
alignment effect disappeared:

| candidate mod64 | time / baseline | cycles / baseline | instructions / baseline |
| ---: | ---: | ---: | ---: |
| 0  | 1.0000 | 1.0000 | 1.0000 |
| 16 | ~0.9957 | ~0.9994 | ~1.0000 |
| 32 | ~0.9950 | ~0.9999 | ~1.0002 |
| 48 | ~1.0013 | ~0.9988 | ~0.9998 |

Therefore the previously observed ~1.47x indexed-float movement is **not**
caused by the entry address or local placement of
`indexedVienotBatch!float` alone.

This falsifies the narrow candidate-entry hypothesis. The earlier global
padding experiments moved the caller, candidate and other text sections
together; the causal factor must depend on some broader layout relationship.
Plausible remaining targets include caller/call-site placement, relative
caller-to-callee geometry, another inlined/out-of-line code region, or a
front-end interaction involving multiple code regions.

Decision: do not add function-alignment attributes or linker workarounds to
production. The next experiment should hold the candidate fixed and vary only
the outer `bench.batch!float`/call-site section (or vice versa), using the same
fixed-envelope technique. This directly tests whether the effect follows the
caller/call-site geometry rather than the callee entry.


## Caller-local fixed-envelope diagnostic — phase 8

Phase 7 falsified the narrow callee-entry hypothesis: moving only
`indexedVienotBatch!float` through mod-64 positions 0/16/32/48 while holding
`bench.batch!float` fixed did not reproduce the earlier ~1.47x effect.

Phase 8 therefore inverts the experiment. It moves only the
`bench.batch!float` COMDAT section inside the same fixed-size linker envelope
while requiring `candidates.indexedVienotBatch!float` to retain exactly the
same address in every variant.

Acceptance guards:

- fixed envelope size must be invariant;
- caller mod-64 position must change;
- candidate address must be identical across variants;
- only then are wall time, cycles and instructions recorded.

This directly tests whether the previously observed alignment sensitivity follows
caller/call-site placement rather than the callee entry.


## Caller-local fixed-envelope diagnostic — phase 8 result

The XPS phase-8 run completed successfully with the fixed-envelope caller probe.

All isolation guards passed:

- `candidates.indexedVienotBatch!float` remained fixed at address `0x97824`
  (mod-64 36) in all variants;
- `bench.batch!float` alone moved through mod-64 positions 0, 16, 32 and 48;
- the fixed envelope remained 852 bytes in every variant;
- only cycles and instructions were measured, avoiding counter multiplexing.

The result is strongly localized:

| caller mod64 | time / baseline | cycles / baseline | instructions / baseline |
| ---: | ---: | ---: | ---: |
| 0  | 1.0000 | 1.0000 | 1.0000 |
| 16 | ~1.0011 | ~1.0019 | ~1.0002 |
| 32 | ~0.9982 | ~0.9988 | ~1.0000 |
| 48 | ~0.8453 | ~0.7548 | ~0.9998 |

The mod-64=48 result is not a single outlier. Across four balanced repetitions
in both benchmark directions, its time ratio stayed approximately 0.823-0.851
and its cycle ratio approximately 0.729-0.767, while instructions remained
essentially unchanged.

This is the strongest causal evidence in the investigation so far. Moving only
the caller/call-site section is sufficient to reproduce a large fraction of the
earlier timing movement while the callee candidate address is held fixed.

Decision: the supported explanation is now a DMD 2.113.0/x86-64
caller/call-site code-layout sensitivity in the indexed-float Viénot benchmark
path. The callee-entry hypothesis was falsified by phase 7. No production
alignment workaround is adopted yet because the exact sensitive instruction
region inside `bench.batch!float` is still unidentified.

A final fine caller sweep should move only the caller by 8-byte increments
through the full 64-byte window, preserving the same fixed envelope and fixed
candidate address. This will map the favorable phase precisely before
instruction-level branch/fetch-boundary inspection.


## Fine caller-local alignment diagnostic — phase 9 result

The XPS fine caller sweep completed successfully at revision
`62bbc5610723fec259f90a81d85cfadd94236d3e` with DMD 2.113.0.

All isolation guards passed:

- `candidates.indexedVienotBatch!float` remained fixed at `0x97824`
  (mod-64 36);
- `bench.batch!float` moved in exact 8-byte steps through every mod-64 phase
  from 0 through 56;
- the fixed envelope remained 852 bytes;
- cycles and instructions were measured without event multiplexing.

The result maps a narrow favorable phase rather than a broad half-window:

| caller mod64 | time / p0 | cycles / p0 | instructions / p0 |
| ---: | ---: | ---: | ---: |
| 0  | 1.000 | 1.000 | 1.000 |
| 8  | 1.062 | 1.054 | 1.000 |
| 16 | 0.997 | 0.995 | 1.000 |
| 24 | 1.057 | 1.051 | 1.000 |
| 32 | 1.004 | 1.000 | 1.000 |
| 40 | 1.062 | 1.052 | 1.000 |
| 48 | **0.716** | **0.751** | **0.9995** |
| 56 | 1.058 | 1.056 | 1.000 |

Thus mod-64 48 is a singular fast phase: about 28% lower benchmark time and
25% fewer cycles with effectively identical dynamic instruction count.
The neighboring 40 and 56 phases are both about 5-6% slower than p0.

Disassembly is instruction-identical and shifted by the caller offset. In the
hot indexed-float loop, the fourth bounds-check branch at function offset
`+0x210` is located exactly on a 64-byte boundary only when the caller entry
is mod-64 48. The loop contains several bounds-check branches before the scalar
matrix arithmetic and a backward loop branch at `+0x2b9`.

This geometric coincidence is not yet proof that the `+0x210` branch itself
is causal: moving the caller shifts the whole loop. However, it provides a
specific next hypothesis. The indexed loop is bounds-check-heavy, while the
reference-bound float path was much less alignment-sensitive in earlier
experiments.

Decision: the next diagnostic should repeat the same fine caller sweep with
DMD bounds checks enabled and disabled as separate research configurations.
The comparison is not a semantic performance comparison and must not be used
to justify disabling bounds checks in production. Its sole purpose is to test
whether the narrow mod-64=48 effect depends on the bounds-check-heavy loop
shape.
