# R7.4.5 — Consumer-machine replay

## Purpose and boundary

The CI investigations show different winners for Brettel, Viénot and Machado
depending on scalar, compiler and operation. The replay driver measures the
existing research forms with fixed binaries, several batch sizes and repeated
balanced blocks on a consumer machine. It does not choose a production kernel,
modify color-d, close the performance gate or provide an independent model oracle.

Driver/source revision: `f5b4428af90b02f38902776d87259e5096155e0a`.
The runner snapshots tracked files from that commit through git show into a
new result directory. It does not alter the checkout or invoke a shell to build
user-supplied command strings. A driver that differs from the selected revision
is rejected. Compiler absence, invalid sizes and CPU affinity are checked first.

## Run on the XPS

Requirements: Linux, Python 3, git, g++, taskset, and locally installed dmd and
ldc2. No packages or compilers are installed by this runner. Versions and paths
are recorded. A different compiler command/path can be supplied with --compilers.

Use mains power, a stable power profile and low background load. Let the laptop
return to a similar starting temperature for an independent repeat. Record those
conditions with --notes. The runner applies CPU affinity but does not alter
governor, turbo, SMT or thermal policy; accessible controls and temperatures are
read before and after blocks. Absent sysfs observations remain unavailable.
Affinity alone does not make the measurements fully controlled.

```bash
(
    set -euo pipefail
    CVD_REPLAY_ROOT="$(mktemp -d /tmp/color-cvd-replay.XXXXXX)"
    git clone --quiet --no-checkout https://github.com/alex-1974/color-d-research.git "$CVD_REPLAY_ROOT/repo"
    git -C "$CVD_REPLAY_ROOT/repo" checkout --quiet --detach f5b4428af90b02f38902776d87259e5096155e0a
    python3 "$CVD_REPLAY_ROOT/repo/experiments/r7_4_5_cvd_performance/replay.py" \
        --revision f5b4428af90b02f38902776d87259e5096155e0a \
        --notes "XPS"
)
```

The default output is a unique color-cvd-xps-* directory in ~/Downloads.
The final RESULT_ARCHIVE line identifies its sibling .tar.gz archive to return.
The temporary clone is left available; no existing library checkout is changed.

## Default protocol

Both installed compiler binaries are built before measurement.
Each compiler runs one assertion-enabled Debug preflight covering all helper
forms, followed by optimized builds of eight independent variants:

| Variant | Targeted source form |
|---|---|
| default | Original reference probes |
| prepared | Prepared Brettel/Viénot coefficients |
| inline | Explicit value-returning BV arithmetic |
| bv_direct | Direct BV output stores |
| bv_split | Direct BV stores and split Brettel selection |
| ma_fixed | Fixed eleven-matrix table with size_t index |
| ma_bounded | Fixed table with bounded int index |
| ma_direct | Direct Machado coefficient interpolation |

The variants isolate earlier questions; this does not compose all winning forms
into one new implementation. Non-targeted operations remain measurement controls.

Default sizes are 1024, 8191 and 65536; blocks=3. The odd size probes a different
tail/layout footprint. Each block contains the established forward D/C++ and
reverse C++/D case orders, giving 18 samples per language/case/block.
Variant order rotates between blocks and reverses on the second pass.
Compiler order and size order reverse on alternate blocks.
Every D variant has fresh paired C++ measurements. All binaries remain fixed
throughout the run; pooling gives 54 samples per language/case by default.

The existing 28-case matrix, deterministic corpus, warm-ups, nine rounds,
16 repeats, severity traversal, flags, observable checksums and enabled bounds
checks are retained. Before each timed process, optimized D runs explicitly
validate full warmed RGB and Machado matrix components. These checks are outside
timing; their cache effects relative to C++ remain a limitation.
The scalar C++ baseline shares coefficients and is not a scientific oracle.

Small batches have shorter timing intervals and a larger relative harness cost.
Raw block results, min/max and per-block medians must be reviewed before treating
small changes as material. Pooled ratios alone are not a performance decision.

## Outputs and failure handling

The result directory and archive retain:
- tracked source snapshots and generated coefficient/module files;
- fixed D/C++ binaries and binary SHA-256 hashes;
- compiler/build/platform identity, notes and sysfs observations;
- exact command argument arrays, times, return codes, stdout and stderr;
- all raw D/C++ rounds, per-block checksum checks and summary CSV/text;
- pooled-summary.csv with per-case min/median/max and D/C++ ratios;
- metadata.json with passed/failed status and files.sha256.

The runner creates new output directories and opens the archive exclusively,
so it does not overwrite prior results. A failed build or measurement leaves a
failed-status archive and returns failure. Missing prerequisite/source checks
occur before a result directory is created and therefore have no archive.

A passed result means the replay completed, its component/checksum checks passed
and its reports are available. It does not automatically qualify performance,
scientific accuracy, a public CVD API or release readiness.

## Validation of the driver

Local Python syntax and argument parsing are checked. The dedicated
.github/workflows/r7-4-5-replay.yml exercises all eight variants on DMD
2.111.0/2.113.0 and LDC 1.41.0/1.43.0, with sizes 64/1024 and two blocks.
It checks the complete pooled report (448 cases, 36 samples per language/case)
and archive creation. These runner smoke tests are not XPS measurements.

The returned XPS archive is inspected in
[R7_4_5_XPS_RESULTS.md](R7_4_5_XPS_RESULTS.md). All manifest hashes, source
identities and reconstructed reports pass. Large gains replicate, but the
consumer measurements are not frequency/thermal/SMT controlled; compiler/kernel
trade-offs and residual gaps keep production performance acceptance open.

The two-block smoke [run 36920078378](https://github.com/alex-1974/color-d-research/actions/runs/36920078378)
passes all four jobs at the pinned revision above. A downloaded LDC 1.41.0
archive was also inspected without extraction: 448 pooled rows, 36 samples per
language/case, 173 successful recorded commands, and every files.sha256 entry
verified. Condensed CI evidence is retained in
[data/r7_4_5/replay-smoke-36920078378.json](../data/r7_4_5/replay-smoke-36920078378.json).

## Follow-up: integrated policies

The [integrated BV policy experiment](R7_4_5_BV_POLICY.md) adds `bv_portable` and
`bv_compiler` after the eight original variants. The current runner defaults to
ten variants, snapshots both policy and qualification source, and runs standalone
Debug/Release BV qualification for every compiler before timing. Its expanded
smoke passes all four compiler jobs. The eight-variant protocol and source pin
above remain the identity of the returned 2026-10-01 XPS archive.

For the new candidate, use the [focused pinned XPS script](../tools/run_xps_bv_policy.sh)
rather than substituting a newer driver into the earlier source revision.
The new integrated consumer replay is now [completed and inspected](R7_4_5_BV_POLICY_XPS.md)
from its own returned archive. Earlier XPS results retain their separate binary
identity. Consumer completion does not close material C++ gaps or production gates.
