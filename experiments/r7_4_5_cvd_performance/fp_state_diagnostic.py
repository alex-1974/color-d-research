#!/usr/bin/env python3
"""XPS phase-1 diagnostic: A/A rebuild reproducibility and per-case FP-state capture."""
import argparse, csv, hashlib, json, os, re, shutil, statistics, subprocess, time
from collections import defaultdict
from pathlib import Path
import replay

VARIANTS = {
    "index-a": "IndexedVienot", "index-b": "IndexedVienot",
    "reference-a": "ReferenceVienot", "reference-b": "ReferenceVienot",
}
SIZES = [1024, 8191, 65536]
ORDERS = [
    ["index-a", "reference-a", "index-b", "reference-b"],
    ["reference-b", "index-b", "reference-a", "index-a"],
    ["index-b", "index-a", "reference-b", "reference-a"],
]

def capture(argv, cwd):
    return subprocess.check_output(list(map(str, argv)), cwd=cwd)

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--compiler", default="dmd")
    p.add_argument("--cc", default="gcc")
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--expected-dmd", default="2.113.0")
    a=p.parse_args()
    root=a.output.resolve(); root.mkdir(parents=True, exist_ok=False)
    repo=Path(capture(["git","rev-parse","--show-toplevel"],Path(__file__).parent).decode().strip())
    rev=capture(["git","rev-parse","HEAD"],repo).decode().strip()
    work=repo/replay.EXPERIMENT
    cpu=min(os.sched_getaffinity(0))
    compiler=shutil.which(a.compiler); cc=shutil.which(a.cc)
    if not compiler or not cc: raise RuntimeError("compiler or C compiler missing")
    version=capture([compiler,"--version"],repo).decode()
    match=re.search(r"Compiler v([0-9]+(?:[.][0-9]+)+)", version)
    if "DMD" not in version.upper() or not match:
        raise RuntimeError("phase 1 is intentionally pinned to DMD")
    dmd_version=match.group(1)
    if dmd_version != a.expected_dmd:
        raise RuntimeError(f"expected DMD {a.expected_dmd}, found {dmd_version}: {compiler}")
    meta={"revision":rev,"cpu":cpu,"compiler_version":version,"variants":VARIANTS,
          "sizes":SIZES,"blocks":3,"purpose":"A/A reproducibility + read-only MXCSR/x87 capture",
          "expected_dmd":a.expected_dmd,"status":"running","observations":[replay.observe(cpu)]}
    ledger=[]
    def save():
        (root/"metadata.json").write_text(json.dumps(meta,indent=2))
        (root/"commands.json").write_text(json.dumps(ledger,indent=2))
    def run(argv,cwd,target):
        target=root/target; target.parent.mkdir(parents=True,exist_ok=True)
        item={"argv":list(map(str,argv)),"cwd":str(cwd),"stdout":str(target.relative_to(root)),"start_ns":time.time_ns()}
        ledger.append(item)
        with target.open("wb") as out, Path(str(target)+".stderr").open("wb") as err:
            q=subprocess.run(item["argv"],cwd=cwd,stdout=out,stderr=err)
        item.update(returncode=q.returncode,end_ns=time.time_ns()); save()
        if q.returncode: raise RuntimeError("command failed: "+" ".join(item["argv"]))
    try:
        run(["lscpu"],work,"lscpu.txt")
        run([os.sys.executable,"prepare.py"],work,"prepare.txt")
        fpobj=root/"fp_state.o"
        run([cc,"-O2","-c","fp_state.c","-o",fpobj],work,"build-fp-state.txt")
        sources=["bench.d","candidates.d","machado_candidates.d","bv_policy.d","_generated/bv.d","_generated/ma.d",str(fpobj)]
        for name,define in VARIANTS.items():
            binary=root/("benchmark-"+name)
            run([compiler,"-O","-inline","-release","-boundscheck=on",
                 "-version=FpStateDiagnostic","-version="+define,"-of="+str(binary),*sources],
                work,"build-"+name+".txt")
            run(["objdump","-d","--no-show-raw-insn","-M","intel",binary],work,"codegen/"+name+".txt")
        hashes={v:hashlib.sha256((root/("benchmark-"+v)).read_bytes()).hexdigest() for v in VARIANTS}
        meta["binary_sha256"]=hashes
        meta["aa_binary_identical"]={
            "index":hashes["index-a"]==hashes["index-b"],
            "reference":hashes["reference-a"]==hashes["reference-b"],
        }
        for block,order in enumerate(ORDERS):
            meta["observations"].append(replay.observe(cpu))
            sizes=SIZES if block%2==0 else list(reversed(SIZES))
            for n in sizes:
                for reverse in (False,True):
                    seq=list(reversed(order)) if reverse else order
                    for variant in seq:
                        argv=["taskset","-c",str(cpu),root/("benchmark-"+variant),str(n)]
                        if reverse: argv.append("reverse")
                        run(argv,work,f"raw/{block}-{n}-{variant}-{int(reverse)}.csv")
            meta["observations"].append(replay.observe(cpu))
        groups=defaultdict(list); fp_rows=[]; fp_changes=[]
        for path in sorted((root/"raw").glob("*.csv")):
            block,n,variant,reverse=path.stem.split("-")
            rows=list(csv.reader(path.open()))
            for r in rows:
                if not r: continue
                if r[0]=="sample":
                    groups[(variant,r[2],r[3],r[4],n,block,reverse)].append(float(r[8]))
                elif r[0]=="fpstate":
                    # fpstate,phase,scalar,mode,deficiency,n,reverse,mxcsr,x87
                    fp_rows.append([path.name,*r[1:]])
            # Pair adjacent before/after records by case identity.
            states=[r for r in rows if r and r[0]=="fpstate"]
            pending={}
            for r in states:
                key=tuple(r[2:7])
                if r[1]=="before": pending[key]=(r[7],r[8])
                elif r[1]=="after":
                    before=pending.pop(key,None)
                    if before is None: raise RuntimeError("FP-state after without before")
                    if before!=(r[7],r[8]): fp_changes.append([path.name,*key,*before,r[7],r[8]])
            if pending: raise RuntimeError("FP-state before without after")
        if any(len(v)!=9 for v in groups.values()): raise RuntimeError("unexpected timing round count")
        with (root/"summary.csv").open("w",newline="") as f:
            w=csv.writer(f); w.writerow(["variant","scalar","mode","deficiency","n","block","reverse","samples","min_ns","median_ns","max_ns"])
            for k,v in sorted(groups.items()): w.writerow([*k,len(v),min(v),statistics.median(v),max(v)])
        with (root/"fp-state.csv").open("w",newline="") as f:
            w=csv.writer(f); w.writerow(["file","phase","scalar","mode","deficiency","n","reverse","mxcsr","x87"]); w.writerows(fp_rows)
        with (root/"fp-state-changes.csv").open("w",newline="") as f:
            w=csv.writer(f); w.writerow(["file","scalar","mode","deficiency","n","reverse","before_mxcsr","before_x87","after_mxcsr","after_x87"]); w.writerows(fp_changes)
        meta.update(status="passed",timing_groups=len(groups),fp_state_rows=len(fp_rows),
                    fp_state_changes=len(fp_changes),
                    interpretation="Phase-1 diagnostic only; no performance winner or production policy selected")
    except BaseException as e:
        meta.update(status="failed",error=str(e)); raise
    finally:
        save()
        files=sorted(p for p in root.rglob("*") if p.is_file())
        (root/"files.sha256").write_text("".join(hashlib.sha256(p.read_bytes()).hexdigest()+"  "+str(p.relative_to(root))+"\n" for p in files))

if __name__=="__main__": main()
