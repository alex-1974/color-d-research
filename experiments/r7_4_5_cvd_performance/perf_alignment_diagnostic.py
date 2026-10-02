#!/usr/bin/env python3
"""Matched fast/slow hardware-counter diagnostic for the CVD alignment effect."""
import argparse, csv, hashlib, json, os, re, shutil, statistics, subprocess, time
from pathlib import Path
import replay

FAMILIES = {"index":"IndexedVienot", "reference":"ReferenceVienot"}
PADS = [0, 16]
MODES = {"vienot":"PerfVienotOnly", "brettel":"PerfBrettelOnly"}
SIZES = [65536]
CANDIDATE_EVENTS = [
    "task-clock","cycles","instructions","branches","branch-misses",
    "cache-references","cache-misses","stalled-cycles-frontend","stalled-cycles-backend"
]
REQUIRED_EVENTS = {"cycles","instructions"}

def capture(argv, cwd):
    return subprocess.check_output(list(map(str,argv)), cwd=cwd)

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--compiler", required=True)
    p.add_argument("--expected-dmd", default="2.113.0")
    p.add_argument("--cc", default="gcc")
    p.add_argument("--perf", default="perf")
    p.add_argument("--output", type=Path, required=True)
    a=p.parse_args()

    root=a.output.resolve(); root.mkdir(parents=True,exist_ok=False)
    repo=Path(capture(["git","rev-parse","--show-toplevel"],Path(__file__).parent).decode().strip())
    rev=capture(["git","rev-parse","HEAD"],repo).decode().strip()
    work=repo/replay.EXPERIMENT
    cpu=min(os.sched_getaffinity(0))
    compiler=shutil.which(a.compiler); cc=shutil.which(a.cc); perf=shutil.which(a.perf)
    if not compiler or not cc or not perf:
        raise RuntimeError("compiler, C compiler or perf missing")
    version=capture([compiler,"--version"],repo).decode()
    match=re.search(r"Compiler v([0-9]+(?:[.][0-9]+)+)",version)
    if "DMD" not in version.upper() or not match or match.group(1)!=a.expected_dmd:
        raise RuntimeError(f"expected DMD {a.expected_dmd}, got: {version.splitlines()[0] if version else 'unknown'}")

    meta={"revision":rev,"cpu":cpu,"compiler_version":version,"candidate_events":CANDIDATE_EVENTS,
          "pads":PADS,"families":FAMILIES,"modes":MODES,
          "purpose":"matched slow/fast hardware-counter comparison for CVD alignment effect",
          "status":"running","observations":[replay.observe(cpu)]}
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
        if check and q.returncode:
            raise RuntimeError("command failed: "+" ".join(item["argv"]))
        return q.returncode

    try:
        # Permission and event preflight before expensive builds. Force C locale so
        # comma remains a reliable field separator independent of desktop locale.
        supported=[]
        preflight={}
        for event in CANDIDATE_EVENTS:
            target=root/f"perf-preflight-{event}.txt"
            with target.open("wb") as out, Path(str(target)+".stderr").open("wb") as err:
                q=subprocess.run(["env","LC_ALL=C",perf,"stat","-x,","-e",event,"--","true"],stdout=out,stderr=err)
            errtext=Path(str(target)+".stderr").read_text(errors="replace")
            ok=(q.returncode==0 and "<not supported>" not in errtext and "<not counted>" not in errtext)
            preflight[event]={"returncode":q.returncode,"supported":ok}
            if ok: supported.append(event)
        meta["perf_event_preflight"]=preflight
        meta["events"]=supported
        missing=sorted(REQUIRED_EVENTS-set(supported))
        if missing:
            raise RuntimeError("required perf counters unavailable: "+", ".join(missing)+"; inspect perf-preflight-*.txt.stderr")

        run(["lscpu"],work,"lscpu.txt")
        run([os.sys.executable,"prepare.py"],work,"prepare.txt")
        fpobj=root/"fp_state.o"
        run([cc,"-O2","-c","fp_state.c","-o",fpobj],work,"build-fp-state.txt")

        pad_objects={}
        for pad in PADS:
            asm=root/f"placement-pad-{pad}.S"
            asm.write_text(".text\n.p2align 6\n.globl colorDPlacementPad\n.type colorDPlacementPad,@function\n"
                           "colorDPlacementPad:\n"+f".fill {pad},1,0x90\nret\n"
                           ".size colorDPlacementPad,.-colorDPlacementPad\n")
            obj=root/f"placement-pad-{pad}.o"
            run([cc,"-c",asm,"-o",obj],work,f"build-pad-{pad}.txt")
            pad_objects[pad]=obj

        sources=["bench.d","candidates.d","machado_candidates.d","bv_policy.d","_generated/bv.d","_generated/ma.d"]
        binaries={}
        for mode,mode_define in MODES.items():
            for family,family_define in FAMILIES.items():
                for pad in PADS:
                    name=f"{mode}-{family}-p{pad}"
                    binary=root/("benchmark-"+name)
                    run([compiler,"-O","-inline","-release","-boundscheck=on",
                         "-version=FpStateDiagnostic","-version="+mode_define,"-version="+family_define,
                         "-of="+str(binary),pad_objects[pad],fpobj,*sources],
                        work,"build-"+name+".txt")
                    run(["objdump","-d","--no-show-raw-insn","-M","intel",binary],work,"codegen/"+name+".txt")
                    binaries[name]=hashlib.sha256(binary.read_bytes()).hexdigest()

        meta["binary_sha256"]=binaries
        event_arg=",".join(supported)
        rows=[]
        # Four balanced repetitions in each direction. perf itself executes one process per sample.
        orders=[
            [0,16],[16,0],[16,0],[0,16]
        ]
        for mode in MODES:
            for family in FAMILIES:
                for reverse in (False,True):
                    for rep,order in enumerate(orders):
                        for pad in order:
                            name=f"{mode}-{family}-p{pad}"
                            stderr=f"perf/{mode}-{family}-p{pad}-r{int(reverse)}-rep{rep}.csv"
                            argv=["env","LC_ALL=C",perf,"stat","-x,","-e",event_arg,"--",
                                  "taskset","-c",str(cpu),root/("benchmark-"+name),"65536"]
                            if reverse: argv.append("reverse")
                            rc=run(argv,work,"program/"+f"{mode}-{family}-p{pad}-r{int(reverse)}-rep{rep}.txt",check=False)
                            # perf writes counters to stderr, copied from the command ledger sidecar.
                            side=Path(str(root/"program"/f"{mode}-{family}-p{pad}-r{int(reverse)}-rep{rep}.txt")+".stderr")
                            target=root/stderr; target.parent.mkdir(parents=True,exist_ok=True); target.write_bytes(side.read_bytes())
                            if rc: raise RuntimeError("perf measurement failed: "+name)

        # Parse perf CSV. Format is value,unit,event,...; tolerate unsupported fields by rejecting them.
        for path in sorted((root/"perf").glob("*.csv")):
            m=re.match(r"(vienot|brettel)-(index|reference)-p(0|16)-r([01])-rep([0-9]+)[.]csv$",path.name)
            if not m: raise RuntimeError("unexpected perf filename: "+path.name)
            mode,family,pad,reverse,rep=m.groups()
            for r in csv.reader(path.open()):
                if len(r)<3: continue
                value=r[0].strip(); event=r[2].strip()
                if event not in supported: continue
                if value in ("<not supported>","<not counted>") or not value:
                    raise RuntimeError(f"counter unavailable: {event} in {path.name}")
                value=float(value.replace(" ",""))
                rows.append([mode,family,int(pad),int(reverse),int(rep),event,value])

        with (root/"perf.csv").open("w",newline="") as f:
            w=csv.writer(f); w.writerow(["mode","family","pad","reverse","rep","event","value"]); w.writerows(rows)

        # Aggregate p16/p0 within matched mode/family/direction/repetition, then median ratios.
        values={(m,f,p,r,rep,e):v for m,f,p,r,rep,e,v in rows}
        ratios=[]
        for mode in MODES:
            for family in FAMILIES:
                for reverse in (0,1):
                    for event in supported:
                        rr=[]
                        for rep in range(len(orders)):
                            a0=values[(mode,family,0,reverse,rep,event)]
                            a16=values[(mode,family,16,reverse,rep,event)]
                            rr.append(a16/a0)
                        ratios.append([mode,family,reverse,event,*rr,statistics.median(rr)])

        with (root/"ratios.csv").open("w",newline="") as f:
            w=csv.writer(f); w.writerow(["mode","family","reverse","event","rep0","rep1","rep2","rep3","median_p16_over_p0"]); w.writerows(ratios)

        meta.update(status="passed",perf_rows=len(rows),ratio_rows=len(ratios),
                    interpretation="Hardware-counter diagnostic only; no production optimization selected")
    except BaseException as e:
        meta.update(status="failed",error=str(e)); raise
    finally:
        save()
        files=sorted(p for p in root.rglob("*") if p.is_file())
        (root/"files.sha256").write_text("".join(hashlib.sha256(p.read_bytes()).hexdigest()+"  "+str(p.relative_to(root))+"\n" for p in files))

if __name__=="__main__": main()
