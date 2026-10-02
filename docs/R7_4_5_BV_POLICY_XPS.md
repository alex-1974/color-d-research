# R7.4.5 — Integrated BV XPS replay, 2026-10-02

The returned consumer archive completes the planned integrated-policy replay.
The compiler-selected form preserves the combined-kernel gains on this XPS,
with approximately unchanged performance against the split control. It remains
a research candidate: material DMD/C++ gaps and incomplete control of machine
conditions keep production performance acceptance open.

## Identity and raw inspection

- Source: `e948f48b71bea374702d79ae8bf9a4aba0010e56`; all eleven tracked Git blob hashes match GitHub at that revision. Full source/generated hashes match CI run 36971582787.
- Intel Core i7-9750H, CPU affinity 0; Linux 6.17.0-22-generic.
- DMD 2.111.0; LDC 1.41.0, frontend 2.111.0, LLVM 19.1.7; GCC 15.2.0.
- Variants default / bv_split / bv_compiler; sizes 1024 / 8191 / 65536; three balanced blocks, 54 samples per language/case.
- All 733 manifest entries verify. All 291 recorded commands succeed, including 216 timed processes pinned to CPU 0.
- Every one of the 54,432 raw samples is finite and the complete matrix is present. All 1,512 block reports and 504 pooled reports are exactly reconstructed from raw min/median/max and D/C++ ratios.
- Matched sampled D/C++ checksum differences are zero for float and double. No uploaded executable was run during inspection.
- Both compilers pass their 5,839-input-per-scalar Debug and Release qualifications, including IEEE, in-place, CTFE and attribute probes. Recorded policy labels select direct double Viénot on DMD and original double Viénot on LDC; Debug preflight and release component checks pass.

Returned archive: `color-cvd-xps-_o0btmdv.tar.gz`, 8,879,989 bytes.

SHA-256: `867ce974fa94d1ba397c467059a9f9a379c0876aefe21fdda332d05e953daede`.

## Results across every deficiency and size

Speedup is original D median divided by `bv_compiler` median, so values above 1
are faster. Ranges cover every deficiency within the indicated scalar/kernel.
Block ranges compare matching block/deficiency/size, but separate timed variant
processes. They are descriptive ranges, not confidence intervals. C++ is the
fresh paired scalar baseline with shared coefficients, not a scientific oracle.

| Compiler | Scalar / kernel | Speedup 1024 | Speedup 8191 | Speedup 65536 | All block speedups | Paired D/C++ |
|---|---|---:|---:|---:|---:|---:|
| DMD 2.111.0 | float / brettel | 28.16–28.37 | 18.13–18.55 | 16.29–16.48 | 15.92–28.79 | 2.59–4.55 |
| DMD 2.111.0 | float / vienot | 4.27–4.37 | 4.25–4.39 | 4.37–4.47 | 3.62–4.50 | 5.61–6.07 |
| DMD 2.111.0 | double / brettel | 4.08–4.36 | 2.94–3.07 | 2.74–2.92 | 2.70–4.39 | 1.26–2.09 |
| DMD 2.111.0 | double / vienot | 4.28–4.32 | 4.30–4.35 | 4.39–4.44 | 4.28–4.44 | 3.85–4.16 |
| LDC 1.41.0 | float / brettel | 2.01–3.32 | 3.47–3.57 | 3.57–3.65 | 1.98–3.87 | 0.98–1.01 |
| LDC 1.41.0 | float / vienot | 5.57–5.60 | 5.93–5.94 | 5.77–5.82 | 5.56–6.42 | 1.07–1.15 |
| LDC 1.41.0 | double / brettel | 1.57–2.30 | 2.38–2.50 | 2.49–2.62 | 1.47–2.66 | 0.84–0.85 |
| LDC 1.41.0 | double / vienot | 0.99–1.00 | 0.99–1.00 | 1.00–1.00 | 0.85–1.03 | 0.74–0.85 |

## Interpretation of the integration

Brettel and float Viénot retain the split control's pooled performance, with
integrated/control factors approximately 0.98–1.01 across both compilers.
Double Viénot is also approximately unchanged against split on this machine.
The compiler-specific double choice carries no demonstrated XPS benefit versus
all-direct LDC in this run; its material justification remains the reproducible
CI double-Viénot regression, which the original-form selection avoids.

The LDC 1.41 small-batch double-Brettel regression from the AMD EPYC 9V45 CI job
is not reproduced on the XPS. At n=1024 all three deficiencies improve over
original D (speedups 1.57–2.30; default 6.28–9.19 ns/item, integrated about
4.00 ns/item). At n=8191 and 65536 the integrated form is approximately
4.00–4.03 ns/item and improves 2.38–2.62 times. This adds platform evidence;
it does not invalidate CI or justify a new batch-size threshold.

DMD retains large gains, including 16–28 times float Brettel improvement from
its unusually slow original baseline. Do not extrapolate that baseline-specific
factor into expected application speedup. Material residual gaps remain:
DMD float Viénot is 5.61–6.07 times C++, double Viénot 3.85–4.16 times,
and large-batch Brettel also remains slower. LDC float Brettel is approximately
C++ parity (0.98–1.01), double Brettel is faster than this C++ baseline
(0.84–0.85), and float Viénot still has a smaller 1.07–1.15 gap.

## Conditions and limits

Measurement observations span 08:17:25–08:22:38 Europe/Vienna. The script records
power profile `performance`; the per-CPU scaling governor separately reports
`powersave`. These are distinct observations, not a fixed-frequency protocol.
Turbo is enabled and SMT active. Sampled scaling_cur_freq readings are about
4.10–4.27 GHz, rather than continuous clock records. One unlabelled thermal zone
starts at 48.05 degrees C, reaches 87.05 before timing, and is 82.05–84.05 at
later boundaries; sensor types are not recorded, so no CPU-temperature or
throttling conclusion follows. AC and background conditions were not supplied
in user notes and are not independently recorded.

The largest unchanged-control block max/min is 1.20 on DMD and 1.12 on LDC.
Some integrated/control block ratios differ more than their pooled medians
(for example LDC float Brettel 0.86–1.15). Narrow timing changes do not establish
a new implementation advantage. Both runs use the same XPS/GCC version, but
this archive is a separate session from the 2026-10-01 replay; do not treat their
absolute timing differences as controlled before/after optimization gains.
CI uses GCC 13.3.0 and different CPUs. Original-source and C++ comparisons both
matter, and full release RGB/matrix checks are outside timing with different
cache effects from the C++ process. Independent scientific envelopes remain open.

## Decision and next work

**Integrated consumer replay completed and inspected; production performance
acceptance remains open.** The compiler-selected BV form remains the preferred
research candidate for subsequent scalar/API composition, backed by the four
compiler CI matrix and this consumer replay. There is no production promotion,
merge or new compiler/version/size fork in this slice. The portable and original
paths remain retained and qualified.

Do not request another unchanged replay merely because the consumer stage was
previously marked pending. The next performance investigation should isolate
the material DMD Viénot matrix-application gap, preserving bounds checks,
attributes, precision/IEEE behaviour and an understandable reference path.
LDC's small-batch CI limitation remains tracked; consumer results do not close
it automatically. Independent model validation and public API/consumer review
remain separate work.

## Retained evidence

[data/r7_4_5/xps-bv-policy-20261002](../data/r7_4_5/xps-bv-policy-20261002/) retains
the complete block and pooled matrix, both candidate comparisons and all
non-targeted Machado controls, source/binary identities, build commands,
platform observations, Debug/Release and preflight logs, plus the full archive
manifest. The original uploaded archive retains all raw rounds and binaries;
the large audit payload is not duplicated into Git history, following the
workspace QUALITY_GATES tier-3 boundary. Condensed records preserve regressions
and uncertainty and do not replace that archive for a raw-round audit.

Reconstruct this fixed pinned protocol with [tools/inspect_xps_bv_policy.py](../tools/inspect_xps_bv_policy.py),
using ordinary Python without -O and a new output directory:

```bash
python3 tools/inspect_xps_bv_policy.py ARCHIVE.tar.gz NEW_OUTPUT_DIRECTORY
```

The script verifies archive integrity and report mathematics. The separate GitHub
source-identity check recorded in inspection.json is not a network operation of
that local checker; the pinned commit and per-file blob hashes are retained.
