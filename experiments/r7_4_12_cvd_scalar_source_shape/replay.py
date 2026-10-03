#!/usr/bin/env python3
"""Qualify scalar CVD convenience-call source shapes against exact production and C++."""

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
import tarfile
import tempfile
import time

PRODUCTION_REVISION="bed36eee31fc35d0a8843ba12e55dfd7b12042e7"
EXPERIMENT=Path("experiments/r7_4_12_cvd_scalar_source_shape")
RESEARCH_FILES=[
    EXPERIMENT/"bench.d",
    EXPERIMENT/"replicas.d",
    EXPERIMENT/"reference.cpp",
    EXPERIMENT/"replay.py",
]
PRODUCTION_FILES=[
    Path("source/color/cvd.d"),
    Path("source/color/rgb.d"),
]
VARIANTS=[
    "production",
    "carrier-replica",
    "direct-return",
    "out-kernel",
    "inline-chain",
    "typed-table",
    "typed-static",
]


def capture(argv,cwd):
    return subprocess.check_output(
        [str(x) for x in argv],
        cwd=cwd,
        stderr=subprocess.STDOUT,
    )


def observe(cpu):
    result={
        "time_utc":dt.datetime.now(dt.timezone.utc).isoformat(),
        "affinity":sorted(os.sched_getaffinity(0)),
    }
    paths=list(Path(f"/sys/devices/system/cpu/cpu{cpu}/cpufreq").glob("*"))
    paths+=list(Path("/sys/class/thermal").glob("thermal_zone*/temp"))
    paths += [
        Path("/sys/devices/system/cpu/intel_pstate/no_turbo"),
        Path("/sys/devices/system/cpu/cpufreq/boost"),
        Path("/sys/devices/system/cpu/smt/active"),
    ]
    keep={
        "scaling_governor",
        "scaling_cur_freq",
        "scaling_min_freq",
        "scaling_max_freq",
        "temp",
        "no_turbo",
        "boost",
        "active",
    }
    for p in paths:
        if p.name not in keep:
            continue
        try:
            result[str(p)]=p.read_text().strip()
        except OSError:
            pass
    return result


def parse_args():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--revision",default="HEAD")
    p.add_argument("--production-revision",default=PRODUCTION_REVISION)
    p.add_argument("--color-d",type=Path,required=True)
    p.add_argument("--compilers",nargs="+",default=["dmd","ldc2"])
    p.add_argument("--sizes",nargs="+",type=int,default=[1024,8191,65536])
    p.add_argument("--blocks",type=int,default=3)
    p.add_argument("--cpu",type=int)
    p.add_argument("--output",type=Path)
    p.add_argument("--notes",default="")
    a=p.parse_args()
    if a.blocks<1:
        p.error("blocks must be positive")
    if any(n<32 or n>1048576 for n in a.sizes):
        p.error("sizes must be 32..1048576")
    if len(a.sizes)!=len(set(a.sizes)):
        p.error("duplicate size")
    allowed=os.sched_getaffinity(0)
    a.cpu=min(allowed) if a.cpu is None else a.cpu
    if a.cpu not in allowed:
        p.error("CPU outside current affinity")
    a.color_d=a.color_d.expanduser().resolve()
    return a


def parse_d(path):
    rows=[]
    with path.open() as s:
        for r in csv.reader(s):
            if not r or r[0]!="sample":
                continue
            if len(r)!=11:
                raise RuntimeError(f"unexpected D row: {r}")
            rows.append(dict(
                language=r[1],
                scalar=r[2],
                model=r[3],
                variant=r[4],
                workload=r[5],
                n=int(r[6]),
                reverse=r[7],
                round=int(r[8]),
                ns=float(r[9]),
                checksum=float(r[10]),
            ))
    if len(rows)!=420:
        raise RuntimeError(
            f"{path}: expected 420 D samples, got {len(rows)}"
        )
    return rows


def parse_cpp(path):
    rows=[]
    with path.open() as s:
        for r in csv.reader(s):
            if not r or r[0]!="sample":
                continue
            if len(r)!=10:
                raise RuntimeError(f"unexpected C++ row: {r}")
            rows.append(dict(
                language=r[1],
                scalar=r[2],
                model=r[3],
                workload=r[4],
                n=int(r[5]),
                reverse=r[6],
                round=int(r[7]),
                ns=float(r[8]),
                checksum=float(r[9]),
            ))
    if len(rows)!=60:
        raise RuntimeError(
            f"{path}: expected 60 C++ samples, got {len(rows)}"
        )
    return rows


def compiler_label(family,version):
    first=version.splitlines()[0]
    if family=="dmd":
        marker="DMD64 D Compiler v"
        if marker in first:
            return "dmd-"+first.split(marker,1)[1].strip()
    else:
        marker="LDC - the LLVM D compiler ("
        if marker in first:
            return "ldc-"+first.split(marker,1)[1].split(")",1)[0]
    return family


def main():
    a=parse_args()
    repo=Path(
        capture(
            ["git","rev-parse","--show-toplevel"],
            Path(__file__).parent,
        ).decode().strip()
    )
    revision=capture(
        ["git","rev-parse","--verify",a.revision+"^{commit}"],
        repo,
    ).decode().strip()
    production=capture(
        ["git","-C",a.color_d,"rev-parse","--verify",a.production_revision+"^{commit}"],
        repo,
    ).decode().strip()

    rsnap={
        str(p):capture(["git","show",revision+":"+str(p)],repo)
        for p in RESEARCH_FILES
    }
    if rsnap[str(EXPERIMENT/"replay.py")]!=Path(__file__).read_bytes():
        raise SystemExit("replay.py differs from selected revision")

    psnap={
        str(p):capture(
            ["git","-C",a.color_d,"show",production+":"+str(p)],
            repo,
        )
        for p in PRODUCTION_FILES
    }

    compilers=[]
    labels=set()
    for cmd in a.compilers:
        exe=(
            str(Path(cmd).expanduser().resolve())
            if "/" in cmd
            else shutil.which(cmd)
        )
        if not exe:
            raise SystemExit("compiler unavailable: "+cmd)
        version=capture([exe,"--version"],repo).decode()
        low=version.lower()
        family="ldc" if "ldc" in low else ("dmd" if "dmd" in low else None)
        if not family:
            raise SystemExit("unsupported compiler: "+cmd)
        label=compiler_label(family,version)
        if label in labels:
            raise SystemExit("duplicate compiler label: "+label)
        labels.add(label)
        compilers.append((exe,family,label,version))

    gpp=shutil.which("g++")
    taskset=shutil.which("taskset")
    objdump=shutil.which("objdump")
    if not gpp or not taskset:
        raise SystemExit("g++ and taskset required")

    if a.output:
        out=a.output.expanduser().resolve()
        out.mkdir(parents=True,exist_ok=False)
    else:
        d=Path.home()/"Downloads"
        d.mkdir(exist_ok=True)
        out=Path(
            tempfile.mkdtemp(
                prefix="color-cvd-scalar-source-",
                dir=d,
            )
        )
    archive=Path(str(out)+".tar.gz")
    ledger=[]

    metadata={
        "research_revision":revision,
        "production_revision":production,
        "cpu":a.cpu,
        "sizes":a.sizes,
        "blocks":a.blocks,
        "notes":a.notes,
        "variants":VARIANTS,
        "workloads":["fixed","dynamic"],
        "semantic_work":"scalar CVD convenience calls; exact production versus source-shape replicas",
        "safety":"@safe pure nothrow @nogc; bounds checks enabled; no SIMD",
        "compilers":[
            {
                "executable":e,
                "family":f,
                "label":label,
                "version":v,
            }
            for e,f,label,v in compilers
        ],
        "gcc_version":capture([gpp,"--version"],repo).decode(),
        "observations":[observe(a.cpu)],
        "status":"running",
    }

    def save():
        (out/"metadata.json").write_text(
            json.dumps(metadata,indent=2)
        )
        (out/"commands.json").write_text(
            json.dumps(ledger,indent=2)
        )

    def run(argv,cwd,dst):
        dst.parent.mkdir(parents=True,exist_ok=True)
        ent={
            "argv":[str(x) for x in argv],
            "cwd":str(cwd),
            "stdout":str(dst.relative_to(out)),
            "start_ns":time.time_ns(),
        }
        ledger.append(ent)
        err=Path(str(dst)+".stderr")
        with dst.open("wb") as so, err.open("wb") as se:
            p=subprocess.run(
                ent["argv"],
                cwd=cwd,
                stdout=so,
                stderr=se,
            )
        ent.update(
            end_ns=time.time_ns(),
            returncode=p.returncode,
        )
        save()
        if p.returncode:
            raise RuntimeError(
                f"command failed ({p.returncode}): {argv[0]}; see {dst}"
            )

    try:
        source=out/"source"
        for p,b in rsnap.items():
            t=source/"research"/p
            t.parent.mkdir(parents=True,exist_ok=True)
            t.write_bytes(b)
        for p,b in psnap.items():
            t=source/"production"/p
            t.parent.mkdir(parents=True,exist_ok=True)
            t.write_bytes(b)

        work=source/"research"/EXPERIMENT
        prodsrc=source/"production"/"source"

        cpp=out/"cpp-scalar"
        run(
            [
                gpp,
                "-std=c++17",
                "-O3",
                "-ffp-contract=off",
                "-fno-fast-math",
                "reference.cpp",
                "-o",
                cpp,
            ],
            work,
            out/"build-cpp.txt",
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
                out/"codegen"/"cpp.txt",
            )

        binaries={}
        for compiler,family,label,_ in compilers:
            flags=(
                ["-O3","-fp-contract=off"]
                if family=="ldc"
                else ["-O","-inline"]
            )
            b=out/(label+"-benchmark")
            run(
                [
                    compiler,
                    *flags,
                    "-release",
                    "-boundscheck=on",
                    "-I"+str(prodsrc),
                    "-of="+str(b),
                    "bench.d",
                    "replicas.d",
                    prodsrc/"color"/"cvd.d",
                    prodsrc/"color"/"rgb.d",
                ],
                work,
                out/f"build-{label}.txt",
            )
            binaries[label]=b
            run(
                [
                    taskset,
                    "-c",
                    str(a.cpu),
                    b,
                    "preflight",
                ],
                work,
                out/f"preflight-{label}.txt",
            )
            if objdump:
                run(
                    [
                        objdump,
                        "-d",
                        "--no-show-raw-insn",
                        "-M",
                        "intel",
                        b,
                    ],
                    work,
                    out/"codegen"/f"{label}.txt",
                )

        allbins={"cpp":cpp,**binaries}
        (out/"binaries.sha256").write_text(
            "".join(
                hashlib.sha256(p.read_bytes()).hexdigest()
                +"  "
                +str(p.relative_to(out))
                +"\n"
                for p in allbins.values()
            )
        )

        dsamples=defaultdict(list)
        csamples=defaultdict(list)
        checks=defaultdict(dict)

        for block in range(a.blocks):
            metadata["observations"].append(observe(a.cpu))
            sizes=(
                list(a.sizes)
                if block%2==0
                else list(reversed(a.sizes))
            )
            dmodes=(
                list(binaries)
                if block%2==0
                else list(reversed(list(binaries)))
            )

            for n in sizes:
                order=(
                    dmodes+["cpp"]
                    if block%2==0
                    else ["cpp"]+dmodes
                )

                for mode in order:
                    binary=cpp if mode=="cpp" else binaries[mode]
                    directions=(
                        [False,True]
                        if block%2==0
                        else [True,False]
                    )

                    for reverse in directions:
                        dst=(
                            out/"runs"/f"n-{n}"/f"block-{block}"/
                            f"{mode}-{'reverse' if reverse else 'forward'}.csv"
                        )
                        argv=[
                            taskset,
                            "-c",
                            str(a.cpu),
                            binary,
                            str(n),
                        ]
                        if reverse:
                            argv.append("reverse")
                        run(argv,work,dst)

                        if mode=="cpp":
                            for row in parse_cpp(dst):
                                key=(
                                    row["scalar"],
                                    row["model"],
                                    row["workload"],
                                    row["n"],
                                )
                                csamples[key].append(row["ns"])
                                cid=(
                                    block,
                                    row["scalar"],
                                    row["model"],
                                    row["workload"],
                                    row["n"],
                                    row["reverse"],
                                    row["round"],
                                )
                                checks[cid]["cpp"]=row["checksum"]
                        else:
                            for row in parse_d(dst):
                                key=(
                                    mode,
                                    row["variant"],
                                    row["scalar"],
                                    row["model"],
                                    row["workload"],
                                    row["n"],
                                )
                                dsamples[key].append(row["ns"])
                                cid=(
                                    block,
                                    row["scalar"],
                                    row["model"],
                                    row["workload"],
                                    row["n"],
                                    row["reverse"],
                                    row["round"],
                                )
                                checks[cid][
                                    f"{mode}:{row['variant']}"
                                ]=row["checksum"]

            metadata["observations"].append(observe(a.cpu))

        expected_check={
            "cpp",
            *(
                f"{mode}:{variant}"
                for mode in binaries
                for variant in VARIANTS
            ),
        }
        for key,vals in checks.items():
            if set(vals)!=expected_check:
                raise RuntimeError(
                    "incomplete checksum set: "+repr(key)
                )
            ref=vals["cpp"]
            tolerance=(
                5e-5
                if key[1]=="float"
                else 1e-10
            )
            for mode,val in vals.items():
                if not math.isclose(
                    val,
                    ref,
                    rel_tol=tolerance,
                    abs_tol=tolerance,
                ):
                    raise RuntimeError(
                        "checksum mismatch: "
                        +repr((key,mode,val,ref))
                    )

        expected=10*a.blocks
        dmed={}
        for key,vals in dsamples.items():
            if len(vals)!=expected:
                raise RuntimeError(
                    "incomplete D samples: "+repr((key,len(vals)))
                )
            dmed[key]=statistics.median(vals)

        cmed={}
        for key,vals in csamples.items():
            if len(vals)!=expected:
                raise RuntimeError(
                    "incomplete C++ samples: "+repr((key,len(vals)))
                )
            cmed[key]=statistics.median(vals)

        with (out/"summary.csv").open("w",newline="") as s:
            w=csv.writer(s)
            w.writerow([
                "compiler",
                "variant",
                "scalar",
                "model",
                "workload",
                "n",
                "samples",
                "median_ns",
                "speedup_vs_production",
                "D_over_CPP",
            ])

            for compiler in binaries:
                for scalar in ("float","double"):
                    for model in ("vienot","machado","brettel"):
                        for workload in ("fixed","dynamic"):
                            for n in a.sizes:
                                base=dmed[
                                    (
                                        compiler,
                                        "production",
                                        scalar,
                                        model,
                                        workload,
                                        n,
                                    )
                                ]
                                cppns=cmed[
                                    (
                                        scalar,
                                        model,
                                        workload,
                                        n,
                                    )
                                ]
                                for variant in VARIANTS:
                                    value=dmed[
                                        (
                                            compiler,
                                            variant,
                                            scalar,
                                            model,
                                            workload,
                                            n,
                                        )
                                    ]
                                    w.writerow([
                                        compiler,
                                        variant,
                                        scalar,
                                        model,
                                        workload,
                                        n,
                                        expected,
                                        value,
                                        base/value,
                                        value/cppns,
                                    ])

        with (out/"attribution.csv").open("w",newline="") as s:
            w=csv.writer(s)
            w.writerow([
                "compiler",
                "scalar",
                "model",
                "workload",
                "variant",
                "speedup_vs_production",
                "D_over_CPP",
            ])

            for compiler in binaries:
                for scalar in ("float","double"):
                    for model in ("vienot","machado","brettel"):
                        for workload in ("fixed","dynamic"):
                            for variant in VARIANTS:
                                speedups=[]
                                ratios=[]
                                for n in a.sizes:
                                    base=dmed[
                                        (
                                            compiler,
                                            "production",
                                            scalar,
                                            model,
                                            workload,
                                            n,
                                        )
                                    ]
                                    value=dmed[
                                        (
                                            compiler,
                                            variant,
                                            scalar,
                                            model,
                                            workload,
                                            n,
                                        )
                                    ]
                                    cppns=cmed[
                                        (
                                            scalar,
                                            model,
                                            workload,
                                            n,
                                        )
                                    ]
                                    speedups.append(base/value)
                                    ratios.append(value/cppns)

                                w.writerow([
                                    compiler,
                                    scalar,
                                    model,
                                    workload,
                                    variant,
                                    statistics.median(speedups),
                                    statistics.median(ratios),
                                ])

        metadata["status"]="passed"
        metadata["interpretation"]=(
            "All D source-shape candidates are checksum-equivalent "
            "to exact production and matched C++ for valid timed inputs; "
            "performance selection is separate."
        )
    except BaseException as e:
        metadata["status"]="failed"
        metadata["error"]=str(e)
        raise
    finally:
        save()
        files=sorted(
            p
            for p in out.rglob("*")
            if p.is_file()
        )
        (out/"files.sha256").write_text(
            "".join(
                hashlib.sha256(p.read_bytes()).hexdigest()
                +"  "
                +str(p.relative_to(out))
                +"\n"
                for p in files
            )
        )
        with tarfile.open(archive,"x:gz") as t:
            t.add(out,arcname=out.name)

        print("RESULT_DIRECTORY="+str(out),flush=True)
        print("RESULT_ARCHIVE="+str(archive),flush=True)


if __name__=="__main__":
    main()
