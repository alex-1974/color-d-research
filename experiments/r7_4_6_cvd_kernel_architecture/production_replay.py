#!/usr/bin/env python3
"""Replay exact color-d production CVD scalar/prepared APIs against matched C++."""

import argparse
from collections import defaultdict
import csv
import datetime as dt
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import statistics
import subprocess
import sys
import tarfile
import tempfile
import time

PRODUCTION_REVISION = "7a7550d44b3133b1145562c6ca8483fe6b0f668c"
EXPERIMENT = Path("experiments/r7_4_6_cvd_kernel_architecture")
RESEARCH_FILES = [
    EXPERIMENT / "production_bench.d",
    EXPERIMENT / "production_reference.cpp",
    EXPERIMENT / "production_replay.py",
]
PRODUCTION_FILES = [
    Path("source/color/cvd.d"),
    Path("source/color/rgb.d"),
]


def capture(argv, cwd):
    return subprocess.check_output(
        [str(x) for x in argv],
        cwd=cwd,
        stderr=subprocess.STDOUT,
    )


def observe(cpu):
    result = {
        "time_utc": dt.datetime.now(
            dt.timezone.utc
        ).isoformat(),
        "affinity": sorted(
            os.sched_getaffinity(0)
        ),
    }

    paths = list(
        Path(
            f"/sys/devices/system/cpu/cpu{cpu}/cpufreq"
        ).glob("*")
    )

    paths += list(
        Path("/sys/class/thermal").glob(
            "thermal_zone*/temp"
        )
    )

    paths += [
        Path(
            "/sys/devices/system/cpu/intel_pstate/no_turbo"
        ),
        Path(
            "/sys/devices/system/cpu/cpufreq/boost"
        ),
        Path(
            "/sys/devices/system/cpu/smt/active"
        ),
    ]

    accepted = {
        "scaling_governor",
        "scaling_cur_freq",
        "scaling_min_freq",
        "scaling_max_freq",
        "temp",
        "no_turbo",
        "boost",
        "active",
    }

    for path in paths:
        if path.name not in accepted:
            continue

        try:
            result[str(path)] = (
                path.read_text().strip()
            )
        except OSError:
            pass

    return result


def parse_args():
    parser = argparse.ArgumentParser(
        description=__doc__
    )

    parser.add_argument(
        "--revision",
        default="HEAD",
    )

    parser.add_argument(
        "--color-d",
        type=Path,
        required=True,
    )

    parser.add_argument(
        "--compilers",
        nargs="+",
        default=["dmd", "ldc2"],
    )

    parser.add_argument(
        "--sizes",
        nargs="+",
        type=int,
        default=[1024, 8191, 65536],
    )

    parser.add_argument(
        "--blocks",
        type=int,
        default=3,
    )

    parser.add_argument(
        "--cpu",
        type=int,
    )

    parser.add_argument(
        "--output",
        type=Path,
    )

    parser.add_argument(
        "--notes",
        default="",
    )

    args = parser.parse_args()

    if args.blocks < 1:
        parser.error("blocks must be positive")

    if any(
        size < 32 or size > 1_048_576
        for size in args.sizes
    ):
        parser.error(
            "sizes must be 32..1048576"
        )

    if len(args.sizes) != len(set(args.sizes)):
        parser.error("duplicate size")

    if (
        len(args.compilers) !=
        len(set(args.compilers))
    ):
        parser.error("duplicate compiler")

    allowed = os.sched_getaffinity(0)

    args.cpu = (
        min(allowed)
        if args.cpu is None
        else args.cpu
    )

    if args.cpu not in allowed:
        parser.error(
            "CPU is outside current affinity"
        )

    args.color_d = (
        args.color_d
        .expanduser()
        .resolve()
    )

    return args


def parse_samples(path):
    rows = []

    with path.open() as stream:
        for row in csv.reader(stream):
            if not row or row[0] != "sample":
                continue

            if len(row) != 11:
                raise RuntimeError(
                    f"unexpected sample row in {path}: {row}"
                )

            rows.append(
                {
                    "language": row[1],
                    "scalar": row[2],
                    "model": row[3],
                    "variant": row[4],
                    "deficiency": int(row[5]),
                    "n": int(row[6]),
                    "reverse": row[7],
                    "round": int(row[8]),
                    "ns": float(row[9]),
                    "checksum": float(row[10]),
                }
            )

    expected = (
        # 7 model/deficiency cases * 2 variants
        # * 2 scalar types * 9 rounds.
        7 * 2 * 2 * 9
    )

    if len(rows) != expected:
        raise RuntimeError(
            f"{path}: expected {expected} samples, "
            f"found {len(rows)}"
        )

    return rows


def main():
    args = parse_args()

    research_repo = Path(
        capture(
            [
                "git",
                "rev-parse",
                "--show-toplevel",
            ],
            Path(__file__).parent,
        ).decode().strip()
    )

    research_revision = capture(
        [
            "git",
            "rev-parse",
            "--verify",
            args.revision + "^{commit}",
        ],
        research_repo,
    ).decode().strip()

    if not (args.color_d / ".git").exists():
        # Worktrees can use a .git file rather than directory.
        if not (args.color_d / ".git").is_file():
            raise SystemExit(
                "--color-d must be a color-d Git checkout"
            )

    production_resolved = capture(
        [
            "git",
            "-C",
            args.color_d,
            "rev-parse",
            "--verify",
            PRODUCTION_REVISION + "^{commit}",
        ],
        research_repo,
    ).decode().strip()

    if production_resolved != PRODUCTION_REVISION:
        raise SystemExit(
            "production revision mismatch: " +
            production_resolved
        )

    research_snapshot = {
        str(path): capture(
            [
                "git",
                "show",
                research_revision + ":" + str(path),
            ],
            research_repo,
        )
        for path in RESEARCH_FILES
    }

    if (
        research_snapshot[
            str(EXPERIMENT / "production_replay.py")
        ] !=
        Path(__file__).read_bytes()
    ):
        raise SystemExit(
            "production_replay.py differs from selected "
            "research revision"
        )

    production_snapshot = {
        str(path): capture(
            [
                "git",
                "-C",
                args.color_d,
                "show",
                PRODUCTION_REVISION + ":" + str(path),
            ],
            research_repo,
        )
        for path in PRODUCTION_FILES
    }

    compilers = []

    for command in args.compilers:
        if "/" in command:
            executable = str(
                Path(command)
                .expanduser()
                .resolve()
            )
        else:
            executable = shutil.which(command)

        if (
            not executable or
            not Path(executable).exists()
        ):
            raise SystemExit(
                "compiler unavailable: " +
                command
            )

        version = capture(
            [executable, "--version"],
            research_repo,
        ).decode()

        lower = version.lower()

        if "ldc" in lower:
            family = "ldc"
        elif "dmd" in lower:
            family = "dmd"
        else:
            raise SystemExit(
                "unsupported compiler: " +
                command
            )

        compilers.append(
            (
                executable,
                family,
                version,
            )
        )

    gpp = shutil.which("g++")
    taskset = shutil.which("taskset")
    objdump = shutil.which("objdump")

    if not gpp or not taskset:
        raise SystemExit(
            "g++ and taskset are required"
        )

    if args.output:
        output = (
            args.output
            .expanduser()
            .resolve()
        )

        output.mkdir(
            parents=True,
            exist_ok=False,
        )
    else:
        downloads = Path.home() / "Downloads"
        downloads.mkdir(exist_ok=True)

        output = Path(
            tempfile.mkdtemp(
                prefix="color-cvd-production-",
                dir=downloads,
            )
        )

    archive = Path(
        str(output) + ".tar.gz"
    )

    ledger = []

    metadata = {
        "research_revision": research_revision,
        "production_repository": str(args.color_d),
        "production_revision": PRODUCTION_REVISION,
        "cpu": args.cpu,
        "sizes": args.sizes,
        "blocks": args.blocks,
        "notes": args.notes,
        "models": [
            "vienot",
            "machado",
            "brettel",
        ],
        "variants": [
            "scalar",
            "prepared",
        ],
        "machado_severity": 0.65,
        "semantic_work": (
            "exact color-d scalar/prepared public CVD API "
            "over linear-light RGB; matched C++ model work"
        ),
        "d_safety": (
            "production source; boundscheck=on; "
            "@safe pure nothrow @nogc public path"
        ),
        "cpp_flags": (
            "-O3 -ffp-contract=off -fno-fast-math"
        ),
        "controls": (
            "CPU affinity applied; frequency/turbo/SMT/"
            "thermals observed, not changed"
        ),
        "compilers": [
            {
                "executable": executable,
                "family": family,
                "version": version,
            }
            for executable, family, version
            in compilers
        ],
        "gcc_version": capture(
            [gpp, "--version"],
            research_repo,
        ).decode(),
        "uname": list(os.uname()),
        "observations": [
            observe(args.cpu)
        ],
        "status": "running",
    }

    def save():
        (output / "metadata.json").write_text(
            json.dumps(
                metadata,
                indent=2,
            )
        )

        (output / "commands.json").write_text(
            json.dumps(
                ledger,
                indent=2,
            )
        )

    def run(argv, cwd, destination):
        destination.parent.mkdir(
            parents=True,
            exist_ok=True,
        )

        entry = {
            "argv": [str(x) for x in argv],
            "cwd": str(cwd),
            "stdout": str(
                destination.relative_to(output)
            ),
            "start_ns": time.time_ns(),
        }

        ledger.append(entry)

        stderr_path = Path(
            str(destination) + ".stderr"
        )

        with (
            destination.open("wb") as stdout,
            stderr_path.open("wb") as stderr
        ):
            process = subprocess.run(
                entry["argv"],
                cwd=cwd,
                stdout=stdout,
                stderr=stderr,
            )

        entry.update(
            end_ns=time.time_ns(),
            returncode=process.returncode,
        )

        save()

        if process.returncode:
            raise RuntimeError(
                f"command failed ({process.returncode}): "
                f"{argv[0]}; see {destination}"
            )

    try:
        source = output / "source"

        for path, content in research_snapshot.items():
            target = source / "research" / path
            target.parent.mkdir(
                parents=True,
                exist_ok=True,
            )
            target.write_bytes(content)

        for path, content in production_snapshot.items():
            target = source / "production" / path
            target.parent.mkdir(
                parents=True,
                exist_ok=True,
            )
            target.write_bytes(content)

        work = source / "research" / EXPERIMENT
        production_source = (
            source / "production" / "source"
        )

        if shutil.which("lscpu"):
            run(
                ["lscpu"],
                work,
                output / "lscpu.txt",
            )

        production_hashes = {
            path: hashlib.sha256(content).hexdigest()
            for path, content
            in production_snapshot.items()
        }

        metadata["production_source_sha256"] = (
            production_hashes
        )

        cpp = output / "cpp-benchmark"

        run(
            [
                gpp,
                "-std=c++17",
                "-O3",
                "-ffp-contract=off",
                "-fno-fast-math",
                "production_reference.cpp",
                "-o",
                cpp,
            ],
            work,
            output / "build-cpp.txt",
        )

        if objdump:
            run(
                [
                    objdump,
                    "-d",
                    "--no-show-raw-insn",
                    "-M",
                    "intel",
                    cpp,
                ],
                work,
                output / "codegen" / "cpp.txt",
            )

        binaries = {}

        for index, (
            compiler,
            family,
            _,
        ) in enumerate(compilers):
            build = (
                output /
                f"compiler-{index}-{family}"
            )

            build.mkdir()

            optimize = (
                [
                    "-O3",
                    "-fp-contract=off",
                ]
                if family == "ldc"
                else [
                    "-O",
                    "-inline",
                ]
            )

            benchmark = build / "benchmark"

            run(
                [
                    compiler,
                    *optimize,
                    "-release",
                    "-boundscheck=on",
                    "-I" + str(production_source),
                    "-of=" + str(benchmark),
                    "production_bench.d",
                    production_source / "color" / "cvd.d",
                    production_source / "color" / "rgb.d",
                ],
                work,
                build / "build-benchmark.txt",
            )

            binaries[index] = benchmark

            # Small correctness/preflight execution before the real matrix.
            run(
                [
                    taskset,
                    "-c",
                    str(args.cpu),
                    benchmark,
                    "32",
                ],
                work,
                build / "preflight.txt",
            )

            if objdump:
                run(
                    [
                        objdump,
                        "-d",
                        "--no-show-raw-insn",
                        "-M",
                        "intel",
                        benchmark,
                    ],
                    work,
                    output / "codegen" /
                    f"compiler-{index}-{family}.txt",
                )

        binary_files = [
            cpp,
            *binaries.values(),
        ]

        (output / "binaries.sha256").write_text(
            "".join(
                hashlib.sha256(
                    path.read_bytes()
                ).hexdigest() +
                "  " +
                str(path.relative_to(output)) +
                "\n"
                for path in binary_files
            )
        )

        samples = defaultdict(list)
        checksums = defaultdict(dict)

        for block in range(args.blocks):
            metadata["observations"].append(
                observe(args.cpu)
            )

            compiler_order = list(
                range(len(compilers))
            )

            if block % 2:
                compiler_order.reverse()

            sizes = (
                list(args.sizes)
                if block % 2 == 0
                else list(reversed(args.sizes))
            )

            for compiler_index in compiler_order:
                family = compilers[
                    compiler_index
                ][1]

                for n in sizes:
                    directory = (
                        output /
                        f"compiler-{compiler_index}-{family}" /
                        f"n-{n}" /
                        f"block-{block}"
                    )

                    directory.mkdir(
                        parents=True
                    )

                    pairs = (
                        [
                            ("d-forward.csv", binaries[compiler_index], False),
                            ("cpp-forward.csv", cpp, False),
                            ("cpp-reverse.csv", cpp, True),
                            ("d-reverse.csv", binaries[compiler_index], True),
                        ]
                        if block % 2 == 0
                        else [
                            ("cpp-forward.csv", cpp, False),
                            ("d-forward.csv", binaries[compiler_index], False),
                            ("d-reverse.csv", binaries[compiler_index], True),
                            ("cpp-reverse.csv", cpp, True),
                        ]
                    )

                    for (
                        filename,
                        binary,
                        reverse,
                    ) in pairs:
                        argv = [
                            taskset,
                            "-c",
                            str(args.cpu),
                            binary,
                            str(n),
                        ]

                        if reverse:
                            argv.append("reverse")

                        destination = (
                            directory /
                            filename
                        )

                        run(
                            argv,
                            work,
                            destination,
                        )

                        for row in parse_samples(
                            destination
                        ):
                            key = (
                                compiler_index,
                                row["scalar"],
                                row["model"],
                                row["variant"],
                                row["deficiency"],
                                row["n"],
                            )

                            samples[
                                (
                                    *key,
                                    row["language"],
                                )
                            ].append(
                                row["ns"]
                            )

                            sample_id = (
                                compiler_index,
                                block,
                                row["scalar"],
                                row["model"],
                                row["variant"],
                                row["deficiency"],
                                row["n"],
                                row["reverse"],
                                row["round"],
                            )

                            checksums[
                                sample_id
                            ][
                                row["language"]
                            ] = row["checksum"]

            metadata["observations"].append(
                observe(args.cpu)
            )

        missing_checksum = [
            key
            for key, values
            in checksums.items()
            if set(values) != {"D", "CPP"}
        ]

        if missing_checksum:
            raise RuntimeError(
                "incomplete D/C++ checksum pairing"
            )

        for key, values in checksums.items():
            scalar = key[2]

            tolerance = (
                5e-5
                if scalar == "float"
                else 1e-10
            )

            if not math.isclose(
                values["D"],
                values["CPP"],
                rel_tol=tolerance,
                abs_tol=tolerance,
            ):
                raise RuntimeError(
                    "D/C++ checksum mismatch: " +
                    repr(
                        (
                            key,
                            values,
                        )
                    )
                )

        expected_samples = (
            18 *
            args.blocks
        )

        with (
            output /
            "pooled-summary.csv"
        ).open(
            "w",
            newline="",
        ) as stream:
            writer = csv.writer(stream)

            writer.writerow(
                [
                    "compiler",
                    "family",
                    "scalar",
                    "model",
                    "variant",
                    "deficiency",
                    "n",
                    "samples_per_language",
                    "D_median_ns",
                    "CPP_median_ns",
                    "D_over_CPP",
                    "D_speedup_vs_scalar",
                    "CPP_speedup_vs_scalar",
                ]
            )

            for compiler_index in range(
                len(compilers)
            ):
                family = compilers[
                    compiler_index
                ][1]

                for n in args.sizes:
                    for scalar in (
                        "float",
                        "double",
                    ):
                        for model, count in (
                            ("vienot", 2),
                            ("machado", 2),
                            ("brettel", 3),
                        ):
                            for deficiency in range(
                                count
                            ):
                                baseline_d = (
                                    samples[
                                        (
                                            compiler_index,
                                            scalar,
                                            model,
                                            "scalar",
                                            deficiency,
                                            n,
                                            "D",
                                        )
                                    ]
                                )

                                baseline_cpp = (
                                    samples[
                                        (
                                            compiler_index,
                                            scalar,
                                            model,
                                            "scalar",
                                            deficiency,
                                            n,
                                            "CPP",
                                        )
                                    ]
                                )

                                if (
                                    len(baseline_d) != expected_samples or
                                    len(baseline_cpp) != expected_samples
                                ):
                                    raise RuntimeError(
                                        "incomplete scalar baseline"
                                    )

                                baseline_d_median = (
                                    statistics.median(
                                        baseline_d
                                    )
                                )

                                baseline_cpp_median = (
                                    statistics.median(
                                        baseline_cpp
                                    )
                                )

                                for variant in (
                                    "scalar",
                                    "prepared",
                                ):
                                    d_values = (
                                        samples[
                                            (
                                                compiler_index,
                                                scalar,
                                                model,
                                                variant,
                                                deficiency,
                                                n,
                                                "D",
                                            )
                                        ]
                                    )

                                    cpp_values = (
                                        samples[
                                            (
                                                compiler_index,
                                                scalar,
                                                model,
                                                variant,
                                                deficiency,
                                                n,
                                                "CPP",
                                            )
                                        ]
                                    )

                                    if (
                                        len(d_values) != expected_samples or
                                        len(cpp_values) != expected_samples
                                    ):
                                        raise RuntimeError(
                                            "incomplete pooled sample matrix"
                                        )

                                    d_median = (
                                        statistics.median(
                                            d_values
                                        )
                                    )

                                    cpp_median = (
                                        statistics.median(
                                            cpp_values
                                        )
                                    )

                                    writer.writerow(
                                        [
                                            compiler_index,
                                            family,
                                            scalar,
                                            model,
                                            variant,
                                            deficiency,
                                            n,
                                            len(d_values),
                                            d_median,
                                            cpp_median,
                                            d_median / cpp_median,
                                            baseline_d_median / d_median,
                                            baseline_cpp_median / cpp_median,
                                        ]
                                    )

        metadata["status"] = "passed"
        metadata["interpretation"] = (
            "Exact production source snapshot and matched "
            "C++ checksum gates passed; performance "
            "interpretation remains separate."
        )

    except BaseException as error:
        metadata["status"] = "failed"
        metadata["error"] = str(error)
        raise

    finally:
        save()

        files = sorted(
            path
            for path in output.rglob("*")
            if path.is_file()
        )

        (output / "files.sha256").write_text(
            "".join(
                hashlib.sha256(
                    path.read_bytes()
                ).hexdigest() +
                "  " +
                str(path.relative_to(output)) +
                "\n"
                for path in files
            )
        )

        with tarfile.open(
            archive,
            "x:gz",
        ) as bundle:
            bundle.add(
                output,
                arcname=output.name,
            )

        print(
            "RESULT_DIRECTORY=" +
            str(output),
            flush=True,
        )

        print(
            "RESULT_ARCHIVE=" +
            str(archive),
            flush=True,
        )


if __name__ == "__main__":
    main()
