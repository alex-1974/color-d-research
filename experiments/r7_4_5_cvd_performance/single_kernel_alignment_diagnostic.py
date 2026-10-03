#!/usr/bin/env python3
"""Single-kernel/single-scalar hardware-counter alignment probe."""
import argparse, csv, hashlib, json, os, re, shutil, statistics, subprocess, time
from pathlib import Path
import replay

PADS=[0,8,16,24,32,40,48,56]
EVENTS=["cycles","instructions"]
SCALARS={"float":"PerfFloatOnly","double":"PerfDoubleOnly"}
FAMILIES={"index":"IndexedVienot","reference":"ReferenceVienot"}

def capture(argv,cwd):
    return subprocess.check_output(list(map(str,argv)),cwd=cwd)

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--compiler",required=True)
    p.add_argument("--expected-dmd",default="2.113.0")
    p.add_argument("--cc",default="gcc")
    p.add_argument("--perf",default="perf")
    p.add_argument("--output",type=Path,required=True)
    a=p.parse_args()
    root=a.output.resolve(); root.mkdir(parents=True,exist_ok=False)
    repo=Path(capture(["git","rev-parse","--show-toplevel"],Path(__file__).parent).decode().strip())
    rev=capture(["git","rev-parse","HEAD"],repo).decode().strip()
    work=repo/replay.EXPERIMENT
    cpu=min(os.sched_getaffinity(0))
    compiler=shutil.which(a.compiler); cc=shutil.which(a.cc); perf=shutil.which(a.perf)
    if not compiler or not cc or not perf: raise RuntimeError("compiler, C compiler or perf missing")
    version=capture([compiler,"--version"],repo).decode()
    m=re.search(r"Compiler v([0-9]+(?:[.][0-9]+)+)",version)
    if "DMD" not in version.upper() or not m or m.group(1)!=a.expected_dmd:
        raise RuntimeError("unexpected DMD version")
    meta={"revision":rev,"cpu":cpu,"compiler_version":version,"pads":PADS,"events":EVENTS,
          "purpose":"single-kernel single-scalar CVD alignment/counter probe","status":"running",
          "observations":[replay.observe(cpu)]}
    ledger=[]
    def save():
        (root/"metadata.json").write_text(json.dumps(meta,indent=2))
        (root/"commands.json").write_text(json.dumps(ledger,indent=2))
    def run(argv,cwd,target,check=True):
        target=root/target; target.parent.mkdir(parents=True,exist_ok=True)
        item={"argv":list(map(str,argv)),"cwd":str(cwd),"stdout":str(target.relative_to(root)),"start_ns":time.time_ns()}
        ledger.append(item)
        with target.open("wb") as out, Path(str(target)+".stderr").open("wb") as err:
            q=subprocess.run(item["argv"],cwd=cwd,stdout=out,stderr=err)
        item.update(returncode=q.returncode,end_ns=time.time_ns()); save()
        if check and q.returncode: raise RuntimeError("command failed: "+" ".join(item["argv"]))
        return q.returncode
    try:
        # cheap perf permission preflight
        q=subprocess.run(["env","LC_ALL=C",perf,"stat","-x,","-e",",".join(EVENTS),"--","true"],
                         stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,text=True)
        (root/"perf-preflight.stderr").write_text(q.stderr)
        if q.returncode or "<not supported>" in q.stderr or "<not counted>" in q.stderr:
            raise RuntimeError("perf counters unavailable; inspect perf-preflight.stderr")

        run([os.sys.executable,"prepare.py"],work,"prepare.txt")
        fpobj=root/"fp_state.o"
        run([cc,"-O2","-c","fp_state.c","-o",fpobj],work,"build-fp-state.txt")
        padobjs={}
        for pad in PADS:
            asm=root/f"pad-{pad}.S"
            asm.write_text(".text\n.p2align 6\n.globl colorDPlacementPad\n.type colorDPlacementPad,@function\n"
                           "colorDPlacementPad:\n"+f".fill {pad},1,0x90\nret\n"
                           ".size colorDPlacementPad,.-colorDPlacementPad\n")
            obj=root/f"pad-{pad}.o"; run([cc,"-c",asm,"-o",obj],work,f"build-pad-{pad}.txt"); padobjs[pad]=obj

        sources=["bench.d","candidates.d","machado_candidates.d","bv_policy.d","_generated/bv.d","_generated/ma.d"]
        placements=[]; hashes={}
        for fam,fdef in FAMILIES.items():
            for scalar,sdef in SCALARS.items():
                for pad in PADS:
                    name=f"vienot-{fam}-{scalar}-p{pad}"
                    binary=root/("benchmark-"+name)
                    run([compiler,"-O","-inline","-release","-boundscheck=on",
                         "-version=FpStateDiagnostic","-version=PerfVienotOnly","-version="+sdef,
                         "-version="+fdef,"-of="+str(binary),padobjs[pad],fpobj,*sources],
                        work,"build-"+name+".txt")
                    hashes[name]=hashlib.sha256(binary.read_bytes()).hexdigest()
                    nm=capture(["nm","-n","-C",binary],work).decode(errors="replace")
                    target=[line for line in nm.splitlines() if "bench.batch!" in line and f"({scalar}, 1)" in line]
                    if len(target)!=1: raise RuntimeError("unable to resolve unique Viénot batch symbol: "+name)
                    addr=int(target[0].split()[0],16)
                    placements.append([name,fam,scalar,pad,target[0].split(None,2)[2],f"0x{addr:x}",addr%64,addr%4096])
        meta["binary_sha256"]=hashes
        with (root/"placement.csv").open("w",newline="") as f:
            w=csv.writer(f); w.writerow(["variant","family","scalar","pad","symbol","address","mod64","mod4096"]);w.writerows(placements)

        rows=[]
        orders=[PADS,list(reversed(PADS)),PADS[4:]+PADS[:4],list(reversed(PADS[4:]+PADS[:4]))]
        for fam in FAMILIES:
            for scalar in SCALARS:
                for reverse in (False,True):
                    for rep,order in enumerate(orders):
                        for pad in order:
                            name=f"vienot-{fam}-{scalar}-p{pad}"
                            outpath=root/"program"/f"{name}-r{int(reverse)}-rep{rep}.txt"
                            argv=["env","LC_ALL=C",perf,"stat","-x,","-e",",".join(EVENTS),"--",
                                  "taskset","-c",str(cpu),root/("benchmark-"+name),"65536"]
                            if reverse: argv.append("reverse")
                            rc=run(argv,work,str(outpath.relative_to(root)),check=False)
                            err=Path(str(outpath)+".stderr").read_text(errors="replace")
                            if rc: raise RuntimeError("perf run failed: "+name)
                            values={}
                            for r in csv.reader(err.splitlines()):
                                if len(r)>=3 and r[2].strip() in EVENTS:
                                    values[r[2].strip()]=float(r[0].strip().replace(" ",""))
                            if set(values)!=set(EVENTS): raise RuntimeError("missing counters: "+name)
                            # wall timing from program's sample rows
                            sample_rows=[r for r in csv.reader(outpath.read_text().splitlines()) if r and r[0]=="sample"]
                            ns=statistics.median(float(r[8]) for r in sample_rows)
                            rows.append([fam,scalar,pad,int(reverse),rep,ns,values["cycles"],values["instructions"]])

        with (root/"samples.csv").open("w",newline="") as f:
            w=csv.writer(f); w.writerow(["family","scalar","pad","reverse","rep","median_ns","cycles","instructions"]);w.writerows(rows)

        # normalize each repetition/direction to p0
        ratios=[]
        for fam in FAMILIES:
            for scalar in SCALARS:
                for reverse in (0,1):
                    for rep in range(len(orders)):
                        subset=[r for r in rows if r[0]==fam and r[1]==scalar and r[3]==reverse and r[4]==rep]
                        base=next(r for r in subset if r[2]==0)
                        for r in subset:
                            ratios.append([fam,scalar,r[2],reverse,rep,r[5]/base[5],r[6]/base[6],r[7]/base[7]])
        with (root/"ratios.csv").open("w",newline="") as f:
            w=csv.writer(f);w.writerow(["family","scalar","pad","reverse","rep","ns_ratio","cycles_ratio","instructions_ratio"]);w.writerows(ratios)

        summary=[]
        for fam in FAMILIES:
            for scalar in SCALARS:
                for pad in PADS:
                    s=[r for r in ratios if r[0]==fam and r[1]==scalar and r[2]==pad]
                    summary.append([fam,scalar,pad,
                                    statistics.median(x[5] for x in s),
                                    statistics.median(x[6] for x in s),
                                    statistics.median(x[7] for x in s)])
        with (root/"summary.csv").open("w",newline="") as f:
            w=csv.writer(f);w.writerow(["family","scalar","pad","median_ns_ratio","median_cycles_ratio","median_instructions_ratio"]);w.writerows(summary)
        meta.update(status="passed",sample_rows=len(rows),summary_rows=len(summary),
                    interpretation="single-kernel/single-scalar diagnostic only")
    except BaseException as e:
        meta.update(status="failed",error=str(e)); raise
    finally:
        save()
        files=sorted(p for p in root.rglob("*") if p.is_file())
        (root/"files.sha256").write_text("".join(hashlib.sha256(p.read_bytes()).hexdigest()+"  "+str(p.relative_to(root))+"\n" for p in files))
if __name__=="__main__": main()
