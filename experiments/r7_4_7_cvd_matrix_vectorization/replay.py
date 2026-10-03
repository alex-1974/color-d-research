#!/usr/bin/env python3
"""Attribute exact-production CVD matrix performance to loop/SLP vectorization."""

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
EXPERIMENT=Path("experiments/r7_4_7_cvd_matrix_vectorization")
RESEARCH_FILES=[EXPERIMENT/"bench.d",EXPERIMENT/"reference.cpp",EXPERIMENT/"replay.py"]
PRODUCTION_FILES=[Path("source/color/cvd.d"),Path("source/color/rgb.d")]


def capture(argv,cwd):
    return subprocess.check_output([str(x) for x in argv],cwd=cwd,stderr=subprocess.STDOUT)


def observe(cpu):
    out={"time_utc":dt.datetime.now(dt.timezone.utc).isoformat(),"affinity":sorted(os.sched_getaffinity(0))}
    paths=list(Path(f"/sys/devices/system/cpu/cpu{cpu}/cpufreq").glob("*"))
    paths+=list(Path("/sys/class/thermal").glob("thermal_zone*/temp"))
    paths += [
        Path("/sys/devices/system/cpu/intel_pstate/no_turbo"),
        Path("/sys/devices/system/cpu/cpufreq/boost"),
        Path("/sys/devices/system/cpu/smt/active"),
    ]
    keep={"scaling_governor","scaling_cur_freq","scaling_min_freq","scaling_max_freq","temp","no_turbo","boost","active"}
    for p in paths:
        if p.name not in keep: continue
        try: out[str(p)]=p.read_text().strip()
        except OSError: pass
    return out


def parse_args():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--revision",default="HEAD")
    p.add_argument("--color-d",type=Path,required=True)
    p.add_argument("--compilers",nargs="+",default=["dmd","ldc2"])
    p.add_argument("--sizes",nargs="+",type=int,default=[1024,8191,65536])
    p.add_argument("--blocks",type=int,default=3)
    p.add_argument("--cpu",type=int)
    p.add_argument("--output",type=Path)
    p.add_argument("--notes",default="")
    a=p.parse_args()
    if a.blocks<1: p.error("blocks must be positive")
    if any(n<32 or n>1048576 for n in a.sizes): p.error("sizes must be 32..1048576")
    allowed=os.sched_getaffinity(0)
    a.cpu=min(allowed) if a.cpu is None else a.cpu
    if a.cpu not in allowed: p.error("CPU outside current affinity")
    a.color_d=a.color_d.expanduser().resolve()
    return a


def parse_samples(path):
    rows=[]
    with path.open() as s:
        for r in csv.reader(s):
            if not r or r[0]!="sample": continue
            if len(r)!=10: raise RuntimeError(f"unexpected row {r}")
            rows.append(dict(language=r[1],scalar=r[2],model=r[3],deficiency=int(r[4]),
                             n=int(r[5]),reverse=r[6],round=int(r[7]),ns=float(r[8]),checksum=float(r[9])))
    if len(rows)!=88: raise RuntimeError(f"{path}: expected 88 samples, got {len(rows)}")
    return rows


def main():
    a=parse_args()
    repo=Path(capture(["git","rev-parse","--show-toplevel"],Path(__file__).parent).decode().strip())
    rev=capture(["git","rev-parse","--verify",a.revision+"^{commit}"],repo).decode().strip()
    prod=capture(["git","-C",a.color_d,"rev-parse","--verify",PRODUCTION_REVISION+"^{commit}"],repo).decode().strip()
    if prod!=PRODUCTION_REVISION: raise SystemExit("production revision mismatch")

    rsnap={str(p):capture(["git","show",rev+":"+str(p)],repo) for p in RESEARCH_FILES}
    if rsnap[str(EXPERIMENT/"replay.py")]!=Path(__file__).read_bytes():
        raise SystemExit("replay.py differs from selected revision")
    psnap={str(p):capture(["git","-C",a.color_d,"show",PRODUCTION_REVISION+":"+str(p)],repo) for p in PRODUCTION_FILES}

    compilers=[]
    for cmd in a.compilers:
        exe=str(Path(cmd).expanduser().resolve()) if "/" in cmd else shutil.which(cmd)
        if not exe: raise SystemExit("compiler unavailable: "+cmd)
        ver=capture([exe,"--version"],repo).decode()
        low=ver.lower()
        family="ldc" if "ldc" in low else ("dmd" if "dmd" in low else None)
        if not family: raise SystemExit("unsupported compiler: "+cmd)
        compilers.append((exe,family,ver))

    gpp=shutil.which("g++"); taskset=shutil.which("taskset"); objdump=shutil.which("objdump")
    if not gpp or not taskset: raise SystemExit("g++ and taskset required")

    if a.output:
        out=a.output.expanduser().resolve(); out.mkdir(parents=True,exist_ok=False)
    else:
        d=Path.home()/"Downloads"; d.mkdir(exist_ok=True)
        out=Path(tempfile.mkdtemp(prefix="color-cvd-vectorization-",dir=d))
    archive=Path(str(out)+".tar.gz")
    ledger=[]

    metadata={
        "research_revision":rev,"production_revision":PRODUCTION_REVISION,"cpu":a.cpu,
        "sizes":a.sizes,"blocks":a.blocks,"notes":a.notes,
        "semantic_work":"exact production prepared Viénot/Machado matrix batch",
        "d_safety":"boundscheck=on; public @safe pure nothrow @nogc path",
        "d_modes":["dmd-default","ldc-full","ldc-no-loop","ldc-no-slp","ldc-no-both"],
        "cpp_modes":["cpp-full","cpp-no-loop","cpp-no-slp","cpp-no-both"],
        "compilers":[{"executable":x,"family":f,"version":v} for x,f,v in compilers],
        "gcc_version":capture([gpp,"--version"],repo).decode(),
        "observations":[observe(a.cpu)],"status":"running",
    }

    def save():
        (out/"metadata.json").write_text(json.dumps(metadata,indent=2))
        (out/"commands.json").write_text(json.dumps(ledger,indent=2))

    def run(argv,cwd,dst):
        dst.parent.mkdir(parents=True,exist_ok=True)
        ent={"argv":[str(x) for x in argv],"cwd":str(cwd),"stdout":str(dst.relative_to(out)),"start_ns":time.time_ns()}
        ledger.append(ent); err=Path(str(dst)+".stderr")
        with dst.open("wb") as so, err.open("wb") as se:
            p=subprocess.run(ent["argv"],cwd=cwd,stdout=so,stderr=se)
        ent.update(end_ns=time.time_ns(),returncode=p.returncode); save()
        if p.returncode: raise RuntimeError(f"command failed ({p.returncode}): {argv[0]}; see {dst}")

    try:
        source=out/"source"
        for p,b in rsnap.items():
            t=source/"research"/p; t.parent.mkdir(parents=True,exist_ok=True); t.write_bytes(b)
        for p,b in psnap.items():
            t=source/"production"/p; t.parent.mkdir(parents=True,exist_ok=True); t.write_bytes(b)
        work=source/"research"/EXPERIMENT; prodsrc=source/"production"/"source"

        cpp_modes={
            "cpp-full":[],
            "cpp-no-loop":["-fno-tree-loop-vectorize"],
            "cpp-no-slp":["-fno-tree-slp-vectorize"],
            "cpp-no-both":["-fno-tree-loop-vectorize","-fno-tree-slp-vectorize"],
        }
        binaries={}
        for mode,extra in cpp_modes.items():
            b=out/mode
            run([gpp,"-std=c++17","-O3","-ffp-contract=off","-fno-fast-math",*extra,"reference.cpp","-o",b],
                work,out/f"build-{mode}.txt")
            binaries[mode]=b
            if objdump:
                run([objdump,"-d","--no-show-raw-insn","-M","intel",b],work,out/"codegen"/f"{mode}.txt")

        for idx,(compiler,family,_) in enumerate(compilers):
            if family=="dmd":
                modes={"dmd-default":["-O","-inline"]}
            else:
                modes={
                    "ldc-full":["-O3","-fp-contract=off"],
                    "ldc-no-loop":["-O3","-fp-contract=off","-disable-loop-vectorization"],
                    "ldc-no-slp":["-O3","-fp-contract=off","-disable-slp-vectorization"],
                    "ldc-no-both":["-O3","-fp-contract=off","-disable-loop-vectorization","-disable-slp-vectorization"],
                }
            for mode,flags in modes.items():
                b=out/f"{idx}-{mode}"
                run([compiler,*flags,"-release","-boundscheck=on","-I"+str(prodsrc),"-of="+str(b),
                     "bench.d",prodsrc/"color"/"cvd.d",prodsrc/"color"/"rgb.d"],
                    work,out/f"build-{idx}-{mode}.txt")
                binaries[f"{idx}:{mode}"]=b
                run([taskset,"-c",str(a.cpu),b,"32"],work,out/f"preflight-{idx}-{mode}.txt")
                if objdump:
                    run([objdump,"-d","--no-show-raw-insn","-M","intel",b],work,out/"codegen"/f"{idx}-{mode}.txt")

        (out/"binaries.sha256").write_text("".join(
            hashlib.sha256(p.read_bytes()).hexdigest()+"  "+str(p.relative_to(out))+"\n"
            for p in binaries.values()
        ))

        samples=defaultdict(list); checks=defaultdict(dict)
        modes_order=list(binaries.keys())

        for block in range(a.blocks):
            metadata["observations"].append(observe(a.cpu))
            sizes=list(a.sizes) if block%2==0 else list(reversed(a.sizes))
            order=modes_order[:] if block%2==0 else list(reversed(modes_order))
            for n in sizes:
                for key in order:
                    b=binaries[key]
                    for reverse in ([False,True] if block%2==0 else [True,False]):
                        dst=out/"runs"/f"n-{n}"/f"block-{block}"/f"{key.replace(':','-')}-{'reverse' if reverse else 'forward'}.csv"
                        argv=[taskset,"-c",str(a.cpu),b,str(n)]
                        if reverse: argv.append("reverse")
                        run(argv,work,dst)
                        for row in parse_samples(dst):
                            sk=(key,row["scalar"],row["model"],row["deficiency"],row["n"])
                            samples[sk].append(row["ns"])
                            ck=(block,row["scalar"],row["model"],row["deficiency"],row["n"],row["reverse"],row["round"])
                            checks[ck][key]=row["checksum"]
            metadata["observations"].append(observe(a.cpu))

        expected_modes=set(binaries)
        for key,vals in checks.items():
            if set(vals)!=expected_modes: raise RuntimeError("incomplete checksum modes: "+repr(key))
            ref=vals["cpp-full"]
            tol=5e-5 if key[1]=="float" else 1e-10
            for mode,v in vals.items():
                if not math.isclose(v,ref,rel_tol=tol,abs_tol=tol):
                    raise RuntimeError("checksum mismatch: "+repr((key,mode,v,ref)))

        expected=22*a.blocks
        med={}
        for key,vals in samples.items():
            if len(vals)!=expected: raise RuntimeError("incomplete sample matrix: "+repr(key))
            med[key]=statistics.median(vals)

        with (out/"summary.csv").open("w",newline="") as s:
            w=csv.writer(s)
            w.writerow(["mode","scalar","model","deficiency","n","samples","median_ns","vs_cpp_full","vs_cpp_no_both","vs_family_full"])
            for key in sorted(med):
                mode,scalar,model,deficiency,n=key
                cppfull=med[("cpp-full",scalar,model,deficiency,n)]
                cppscalar=med[("cpp-no-both",scalar,model,deficiency,n)]
                if mode.startswith("ldc-"): familyfull=med[("ldc-full",scalar,model,deficiency,n)]
                elif mode.startswith("cpp-"): familyfull=cppfull
                else: familyfull=med[key]
                w.writerow([mode,scalar,model,deficiency,n,expected,med[key],
                            med[key]/cppfull,med[key]/cppscalar,med[key]/familyfull])

        def agg_ratio(num_mode,den_mode,scalar,model):
            vals=[]
            for deficiency in (0,1):
                for n in a.sizes:
                    nk=(num_mode,scalar,model,deficiency,n)
                    dk=(den_mode,scalar,model,deficiency,n)
                    if nk in med and dk in med: vals.append(med[nk]/med[dk])
            return statistics.median(vals) if vals else None

        with (out/"attribution.csv").open("w",newline="") as s:
            w=csv.writer(s)
            w.writerow(["scalar","model","gcc_no_loop_over_full","gcc_no_slp_over_full","gcc_no_both_over_full",
                        "ldc_no_loop_over_full","ldc_no_slp_over_full","ldc_no_both_over_full",
                        "dmd_over_cpp_no_both","ldc_full_over_cpp_full","ldc_no_both_over_cpp_no_both"])
            for scalar in ("float","double"):
                for model in ("vienot","machado"):
                    row=[scalar,model]
                    for num,den in [
                        ("cpp-no-loop","cpp-full"),("cpp-no-slp","cpp-full"),("cpp-no-both","cpp-full"),
                        ("ldc-no-loop","ldc-full"),("ldc-no-slp","ldc-full"),("ldc-no-both","ldc-full"),
                        ("dmd-default","cpp-no-both"),("ldc-full","cpp-full"),("ldc-no-both","cpp-no-both")
                    ]:
                        row.append(agg_ratio(num,den,scalar,model))
                    w.writerow(row)

        metadata["status"]="passed"
        metadata["interpretation"]="Vectorization modes produced matched checksums; performance interpretation is separate."
    except BaseException as e:
        metadata["status"]="failed"; metadata["error"]=str(e); raise
    finally:
        save()
        files=sorted(p for p in out.rglob("*") if p.is_file())
        (out/"files.sha256").write_text("".join(
            hashlib.sha256(p.read_bytes()).hexdigest()+"  "+str(p.relative_to(out))+"\n" for p in files
        ))
        with tarfile.open(archive,"x:gz") as t: t.add(out,arcname=out.name)
        print("RESULT_DIRECTORY="+str(out),flush=True)
        print("RESULT_ARCHIVE="+str(archive),flush=True)


if __name__=="__main__":
    main()
