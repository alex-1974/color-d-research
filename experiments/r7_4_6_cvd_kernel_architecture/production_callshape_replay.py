#!/usr/bin/env python3
"""Isolate exact-production prepared CVD call-shape effects."""

import argparse
from collections import defaultdict
import csv
import datetime as dt
import hashlib
import json
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
    EXPERIMENT / "production_callshape_bench.d",
    EXPERIMENT / "production_callshape_replay.py",
]
PRODUCTION_FILES = [
    Path("source/color/cvd.d"),
    Path("source/color/rgb.d"),
]
SHAPES = [
    "ref-wrapper",
    "value-wrapper",
    "local-copy-wrapper",
    "direct",
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

            if len(row) != 9:
                raise RuntimeError(
                    f"unexpected sample row in {path}: {row}"
                )

            rows.append(
                {
                    "scalar": row[1],
                    "model": row[2],
                    "shape": row[3],
                    "n": int(row[4]),
                    "reverse": row[5],
                    "round": int(row[6]),
                    "ns": float(row[7]),
                    "checksum": float(row[8]),
                }
            )

    expected = (
        2 *  # scalar types
        2 *  # models
        4 *  # shapes
        11
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
            "production revision mismatch"
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
            str(EXPERIMENT / "production_callshape_replay.py")
        ] !=
        Path(__file__).read_bytes()
    ):
        raise SystemExit(
            "driver differs from selected revision"
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
                "unsupported compiler"
            )

        compilers.append(
            (
                executable,
                family,
                version,
            )
        )

    taskset = shutil.which("taskset")
    objdump = shutil.which("objdump")

    if not taskset:
        raise SystemExit(
            "taskset is required"
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
                prefix="color-cvd-callshape-",
                dir=downloads,
            )
        )

    archive = Path(
        str(output) + ".tar.gz"
    )

    metadata = {
        "research_revision": research_revision,
        "production_revision": PRODUCTION_REVISION,
        "cpu": args.cpu,
        "sizes": args.sizes,
        "blocks": args.blocks,
        "models": [
            "vienot",
            "machado",
        ],
        "shapes": SHAPES,
        "purpose": (
            "separate public prepared API cost from "
            "benchmark wrapper alias/call shape"
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
        "observations": [
            observe(args.cpu)
        ],
        "status": "running",
    }

    ledger = []

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

            binary = build / "benchmark"

            run(
                [
                    compiler,
                    *optimize,
                    "-release",
                    "-boundscheck=on",
                    "-I" + str(production_source),
                    "-of=" + str(binary),
                    "production_callshape_bench.d",
                    production_source / "color" / "cvd.d",
                    production_source / "color" / "rgb.d",
                ],
                work,
                build / "build.txt",
            )

            binaries[index] = binary

            run(
                [
                    taskset,
                    "-c",
                    str(args.cpu),
                    binary,
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
                        binary,
                    ],
                    work,
                    output / "codegen" /
                    f"compiler-{index}-{family}.txt",
                )

        (output / "binaries.sha256").write_text(
            "".join(
                hashlib.sha256(
                    path.read_bytes()
                ).hexdigest() +
                "  " +
                str(path.relative_to(output)) +
                "\n"
                for path in binaries.values()
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

                    directions = (
                        [False, True]
                        if block % 2 == 0
                        else [True, False]
                    )

                    for reverse in directions:
                        destination = (
                            directory /
                            (
                                "reverse.csv"
                                if reverse
                                else "forward.csv"
                            )
                        )

                        argv = [
                            taskset,
                            "-c",
                            str(args.cpu),
                            binaries[
                                compiler_index
                            ],
                            str(n),
                        ]

                        if reverse:
                            argv.append("reverse")

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
                                row["shape"],
                                row["n"],
                            )

                            samples[key].append(
                                row["ns"]
                            )

                            check_id = (
                                compiler_index,
                                block,
                                row["scalar"],
                                row["model"],
                                row["n"],
                                row["reverse"],
                                row["round"],
                            )

                            checksums[
                                check_id
                            ][
                                row["shape"]
                            ] = row["checksum"]

            metadata["observations"].append(
                observe(args.cpu)
            )

        for key, values in checksums.items():
            if set(values) != set(SHAPES):
                raise RuntimeError(
                    "incomplete shape checksum set: " +
                    repr(key)
                )

            reference = values["direct"]

            for shape, value in values.items():
                if value != reference:
                    raise RuntimeError(
                        "call-shape checksum mismatch: " +
                        repr(
                            (
                                key,
                                shape,
                                value,
                                reference,
                            )
                        )
                    )

        expected = 22 * args.blocks

        with (
            output / "summary.csv"
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
                    "shape",
                    "n",
                    "samples",
                    "median_ns",
                    "vs_ref_wrapper",
                    "vs_direct",
                ]
            )

            for compiler_index, (
                _,
                family,
                _,
            ) in enumerate(compilers):
                for scalar in (
                    "float",
                    "double",
                ):
                    for model in (
                        "vienot",
                        "machado",
                    ):
                        for n in args.sizes:
                            medians = {}

                            for shape in SHAPES:
                                values = samples[
                                    (
                                        compiler_index,
                                        scalar,
                                        model,
                                        shape,
                                        n,
                                    )
                                ]

                                if len(values) != expected:
                                    raise RuntimeError(
                                        "incomplete sample matrix"
                                    )

                                medians[shape] = (
                                    statistics.median(
                                        values
                                    )
                                )

                            for shape in SHAPES:
                                value = medians[shape]

                                writer.writerow(
                                    [
                                        compiler_index,
                                        family,
                                        scalar,
                                        model,
                                        shape,
                                        n,
                                        expected,
                                        value,
                                        (
                                            value /
                                            medians["ref-wrapper"]
                                        ),
                                        (
                                            value /
                                            medians["direct"]
                                        ),
                                    ]
                                )

        metadata["status"] = "passed"
        metadata["interpretation"] = (
            "All call shapes produced identical "
            "checksums; timing interpretation separate."
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
