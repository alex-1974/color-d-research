#!/usr/bin/env python3
"""Qualify safe Viénot source forms across the supported DMD/LDC baseline matrix."""
import argparse, json, os, re, shutil, subprocess, sys
from pathlib import Path

EXPECTED = {
    "dmd-2.111.0": ("dmd", "2.111.0"),
    "dmd-2.112.1": ("dmd", "2.112.1"),
    "dmd-2.113.0": ("dmd", "2.113.0"),
    "ldc-1.41.0": ("ldc", "1.41.0"),
}

def version_of(exe):
    out=subprocess.check_output([exe,"--version"],text=True)
    family="ldc" if "ldc" in out.lower() else "dmd" if "dmd" in out.lower() else None
    if family=="dmd":
        m=re.search(r"Compiler v([0-9]+(?:[.][0-9]+)+)",out)
    else:
        m=re.search(r"LDC - the LLVM D compiler \(([0-9]+(?:[.][0-9]+)+)",out)
    return family,(m.group(1) if m else None),out

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--dmd-211",required=True)
    p.add_argument("--dmd-212",required=True)
    p.add_argument("--dmd-213",required=True)
    p.add_argument("--ldc-141",required=True)
    p.add_argument("--output",type=Path,required=True)
    p.add_argument("--cpu",type=int)
    p.add_argument("--blocks",type=int,default=3)
    p.add_argument("--sizes",nargs="+",type=int,default=[1024,8191,65536])
    a=p.parse_args()

    repo=Path(subprocess.check_output(["git","rev-parse","--show-toplevel"],text=True).strip())
    work=repo/"experiments/r7_4_5_cvd_performance"
    supplied={
        "dmd-2.111.0":a.dmd_211,
        "dmd-2.112.1":a.dmd_212,
        "dmd-2.113.0":a.dmd_213,
        "ldc-1.41.0":a.ldc_141,
    }
    resolved=[]
    matrix={}
    for label,command in supplied.items():
        exe=shutil.which(command) if "/" not in command else str(Path(command).expanduser().resolve())
        if not exe or not Path(exe).exists():
            raise SystemExit("compiler unavailable: "+command)
        family,version,raw=version_of(exe)
        efam,ever=EXPECTED[label]
        if family!=efam or version!=ever:
            raise SystemExit(f"{label}: expected {efam} {ever}, found {family} {version}: {exe}")
        resolved.append(exe)
        matrix[label]={"executable":exe,"family":family,"version":version,"raw_version":raw}

    a.output=a.output.expanduser().resolve()
    if a.output.exists():
        raise SystemExit("output already exists: "+str(a.output))
    manifest=a.output.parent/(a.output.name+"-requested-matrix.json")
    manifest.write_text(json.dumps({
        "purpose":"safe reference-bound Viénot qualification",
        "boundscheck":"on (enforced by replay.py)",
        "variants":["bv_vienot_index","bv_vienot_ref"],
        "compiler_matrix":matrix,
        "sizes":a.sizes,"blocks":a.blocks,
        "cpp":"g++ -O3 -ffp-contract=off -fno-fast-math via replay.py",
        "interpretation":"research qualification only; no production change"
    },indent=2))

    cmd=[sys.executable,str(work/"replay.py"),
         "--revision","HEAD",
         "--compilers",*resolved,
         "--variants","bv_vienot_index","bv_vienot_ref",
         "--sizes",*[str(n) for n in a.sizes],
         "--blocks",str(a.blocks),
         "--output",str(a.output),
         "--notes","reference-bound qualification after bounds/alignment root-cause investigation"]
    if a.cpu is not None:
        cmd += ["--cpu",str(a.cpu)]
    print("RUN="+" ".join(cmd),flush=True)
    rc=subprocess.call(cmd,cwd=repo)
    raise SystemExit(rc)

if __name__=="__main__":
    main()
