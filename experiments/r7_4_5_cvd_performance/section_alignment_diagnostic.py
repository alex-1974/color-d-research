#!/usr/bin/env python3
"""Function-local ELF section-alignment probe for indexed float Viénot."""
import argparse, csv, hashlib, json, os, re, shutil, statistics, subprocess, time
from pathlib import Path
import replay

ALIGNMENTS=[4,16,32,64]
EVENTS=["cycles","instructions"]
TARGET_TOKEN="_D10candidates__T18indexedVienotBatchTf"
OUTER_TOKEN="bench.batch!(float, 1)"

def capture(argv,cwd):
    return subprocess.check_output(list(map(str,argv)),cwd=cwd)

def symbol_addr(binary, needle, cwd):
    text=capture(["nm","-n","-C",binary],cwd).decode(errors="replace")
    rows=[line for line in text.splitlines() if needle in line]
    if len(rows)!=1:
        raise RuntimeError(f"expected one symbol for {needle}, got {len(rows)}")
    return int(rows[0].split()[0],16),rows[0].split(None,2)[2]

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--compiler",required=True)
    p.add_argument("--expected-dmd",default="2.113.0")
    p.add_argument("--cc",default="gcc")
    p.add_argument("--objcopy",default="objcopy")
    p.add_argument("--perf",default="perf")
    p.add_argument("--output",type=Path,required=True)
    a=p.parse_args()

    root=a.output.resolve(); root.mkdir(parents=True,exist_ok=False)
    repo=Path(capture(["git","rev-parse","--show-toplevel"],Path(__file__).parent).decode().strip())
    rev=capture(["git","rev-parse","HEAD"],repo).decode().strip()
    work=repo/replay.EXPERIMENT
    cpu=min(os.sched_getaffinity(0))
    compiler=shutil.which(a.compiler); cc=shutil.which(a.cc)
    objcopy=shutil.which(a.objcopy); perf=shutil.which(a.perf)
    if not all((compiler,cc,objcopy,perf)):
        raise RuntimeError("compiler, cc, objcopy or perf missing")
    version=capture([compiler,"--version"],repo).decode()
    m=re.search(r"Compiler v([0-9]+(?:[.][0-9]+)+)",version)
    if "DMD" not in version.upper() or not m or m.group(1)!=a.expected_dmd:
        raise RuntimeError("unexpected DMD version")

    meta={"revision":rev,"cpu":cpu,"compiler_version":version,"alignments":ALIGNMENTS,
          "events":EVENTS,"purpose":"function-local ELF section alignment for indexed float Viénot",
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
        if check and q.returncode: raise RuntimeError("command failed: "+" ".join(item["argv"]))
        return q.returncode

    try:
        q=subprocess.run(["env","LC_ALL=C",perf,"stat","-x,","-e",",".join(EVENTS),"--","true"],
                         stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,text=True)
        (root/"perf-preflight.stderr").write_text(q.stderr)
        if q.returncode or "<not supported>" in q.stderr or "<not counted>" in q.stderr:
            raise RuntimeError("perf counters unavailable")

        run([os.sys.executable,"prepare.py"],work,"prepare.txt")
        fpobj=root/"fp_state.o"
        run([cc,"-O2","-c","fp_state.c","-o",fpobj],work,"build-fp-state.txt")

        seed=root/"seed"
        sources=["bench.d","candidates.d","machado_candidates.d","bv_policy.d","_generated/bv.d","_generated/ma.d"]
        run([compiler,"-O","-inline","-release","-boundscheck=on",
             "-version=FpStateDiagnostic","-version=PerfVienotOnly","-version=PerfFloatOnly",
             "-version=IndexedVienot","-of="+str(seed),fpobj,*sources],
            work,"build-seed.txt")
        seedobj=Path(str(seed)+".o")
        if not seedobj.exists(): raise RuntimeError("DMD seed object missing")

        sections=capture(["readelf","-SW",seedobj],work).decode(errors="replace")
        target_sections=[]
        for line in sections.splitlines():
            if TARGET_TOKEN in line:
                fields=line.split()
                # readelf formatting: [N] name type ...
                name=next((x for x in fields if x.startswith(".text."+TARGET_TOKEN)),None)
                if name: target_sections.append(name)
        target_sections=sorted(set(target_sections))
        if len(target_sections)!=1:
            raise RuntimeError("unable to resolve unique indexedVienotBatch!float section")
        section=target_sections[0]
        meta["target_section"]=section
        (root/"seed-sections.txt").write_text(sections)

        placements=[]; hashes={}
        outer_addrs=set()
        for align in ALIGNMENTS:
            obj=root/f"candidate-align-{align}.o"
            shutil.copy2(seedobj,obj)
            run([objcopy,"--set-section-alignment",f"{section}={align}",obj],work,f"objcopy-align-{align}.txt")
            sec_after=capture(["readelf","-SW",obj],work).decode(errors="replace")
            (root/f"sections-align-{align}.txt").write_text(sec_after)
            binary=root/f"benchmark-align-{align}"
            run([compiler,"-of="+str(binary),obj,fpobj],work,f"link-align-{align}.txt")
            run(["objdump","-d","--no-show-raw-insn","-M","intel",binary],work,f"codegen/align-{align}.txt")
            cand_addr,cand_name=symbol_addr(binary,"candidates.indexedVienotBatch!(float)",work)
            outer_addr,outer_name=symbol_addr(binary,OUTER_TOKEN,work)
            outer_addrs.add(outer_addr)
            placements.append([align,cand_name,f"0x{cand_addr:x}",cand_addr%64,cand_addr%4096,
                               outer_name,f"0x{outer_addr:x}",outer_addr%64,outer_addr%4096])
            hashes[str(align)]=hashlib.sha256(binary.read_bytes()).hexdigest()
        if len(outer_addrs)!=1:
            raise RuntimeError("outer bench.batch address changed; probe is not function-local enough")
        if len({r[3] for r in placements})<2:
            raise RuntimeError("candidate mod64 placement did not change")
        meta["binary_sha256"]=hashes
        with (root/"placement.csv").open("w",newline="") as f:
            w=csv.writer(f);w.writerow(["alignment","candidate_symbol","candidate_address","candidate_mod64","candidate_mod4096",
                                        "outer_symbol","outer_address","outer_mod64","outer_mod4096"]);w.writerows(placements)

        rows=[]
        orders=[ALIGNMENTS,list(reversed(ALIGNMENTS)),ALIGNMENTS[2:]+ALIGNMENTS[:2],list(reversed(ALIGNMENTS[2:]+ALIGNMENTS[:2]))]
        for reverse in (False,True):
            for rep,order in enumerate(orders):
                for align in order:
                    binary=root/f"benchmark-align-{align}"
                    outpath=root/"program"/f"align-{align}-r{int(reverse)}-rep{rep}.txt"
                    argv=["env","LC_ALL=C",perf,"stat","-x,","-e",",".join(EVENTS),"--",
                          "taskset","-c",str(cpu),binary,"65536"]
                    if reverse: argv.append("reverse")
                    rc=run(argv,work,str(outpath.relative_to(root)),check=False)
                    if rc: raise RuntimeError("perf run failed")
                    err=Path(str(outpath)+".stderr").read_text(errors="replace")
                    vals={}
                    for rr in csv.reader(err.splitlines()):
                        if len(rr)>=3 and rr[2].strip() in EVENTS:
                            vals[rr[2].strip()]=float(rr[0].strip().replace(" ",""))
                    if set(vals)!=set(EVENTS): raise RuntimeError("missing perf counters")
                    samples=[rr for rr in csv.reader(outpath.read_text().splitlines()) if rr and rr[0]=="sample"]
                    if len(samples)!=18: raise RuntimeError("unexpected Viénot sample count")
                    ns=statistics.median(float(rr[8]) for rr in samples)
                    rows.append([align,int(reverse),rep,ns,vals["cycles"],vals["instructions"]])
        with (root/"samples.csv").open("w",newline="") as f:
            w=csv.writer(f);w.writerow(["alignment","reverse","rep","median_ns","cycles","instructions"]);w.writerows(rows)

        ratios=[]
        for reverse in (0,1):
            for rep in range(len(orders)):
                sub=[r for r in rows if r[1]==reverse and r[2]==rep]
                base=next(r for r in sub if r[0]==4)
                for r in sub:
                    ratios.append([r[0],reverse,rep,r[3]/base[3],r[4]/base[4],r[5]/base[5]])
        with (root/"ratios.csv").open("w",newline="") as f:
            w=csv.writer(f);w.writerow(["alignment","reverse","rep","ns_ratio","cycles_ratio","instructions_ratio"]);w.writerows(ratios)

        summary=[]
        for align in ALIGNMENTS:
            s=[r for r in ratios if r[0]==align]
            summary.append([align,
                            statistics.median(x[3] for x in s),
                            statistics.median(x[4] for x in s),
                            statistics.median(x[5] for x in s)])
        with (root/"summary.csv").open("w",newline="") as f:
            w=csv.writer(f);w.writerow(["alignment","median_ns_ratio","median_cycles_ratio","median_instructions_ratio"]);w.writerows(summary)

        meta.update(status="passed",sample_rows=len(rows),summary_rows=len(summary),
                    interpretation="function-local section-alignment diagnostic only")
    except BaseException as e:
        meta.update(status="failed",error=str(e)); raise
    finally:
        save()
        files=sorted(p for p in root.rglob("*") if p.is_file())
        (root/"files.sha256").write_text("".join(hashlib.sha256(p.read_bytes()).hexdigest()+"  "+str(p.relative_to(root))+"\n" for p in files))
if __name__=="__main__": main()
