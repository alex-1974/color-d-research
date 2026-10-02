#!/usr/bin/env python3
"""XPS phase-2 diagnostic: deliberately vary executable text placement only."""
import argparse, csv, hashlib, json, os, re, shutil, statistics, subprocess, time
from collections import defaultdict
from pathlib import Path
import replay

FAMILIES = {"index": "IndexedVienot", "reference": "ReferenceVienot"}
PADS = [0, 64, 128, 256, 512, 1024]
SIZES = [1024, 8191, 65536]
TARGET_SYMBOLS = ("bench.lookupBatch!", "bench.batch!", "bv.vienotProbe!")

def capture(argv, cwd):
    return subprocess.check_output(list(map(str, argv)), cwd=cwd)

def parse_symbols(binary, cwd):
    text=capture(["nm","-n","-C",binary],cwd).decode(errors="replace")
    found={}
    for line in text.splitlines():
        parts=line.split(None,2)
        if len(parts)!=3 or not re.fullmatch(r"[0-9a-fA-F]+",parts[0]):
            continue
        name=parts[2]
        if any(token in name for token in TARGET_SYMBOLS):
            found[name]=int(parts[0],16)
    if not found:
        raise RuntimeError("no target benchmark symbols found")
    return found, text

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--compiler", required=True)
    p.add_argument("--expected-dmd", default="2.113.0")
    p.add_argument("--cc", default="gcc")
    p.add_argument("--output", type=Path, required=True)
    a=p.parse_args()

    root=a.output.resolve(); root.mkdir(parents=True,exist_ok=False)
    repo=Path(capture(["git","rev-parse","--show-toplevel"],Path(__file__).parent).decode().strip())
    rev=capture(["git","rev-parse","HEAD"],repo).decode().strip()
    work=repo/replay.EXPERIMENT
    cpu=min(os.sched_getaffinity(0))
    compiler=shutil.which(a.compiler); cc=shutil.which(a.cc)
    if not compiler or not cc: raise RuntimeError("compiler or C compiler missing")
    version=capture([compiler,"--version"],repo).decode()
    match=re.search(r"Compiler v([0-9]+(?:[.][0-9]+)+)",version)
    if "DMD" not in version.upper() or not match:
        raise RuntimeError("phase 2 is intentionally pinned to DMD")
    if match.group(1)!=a.expected_dmd:
        raise RuntimeError(f"expected DMD {a.expected_dmd}, found {match.group(1)}: {compiler}")

    variants=[f"{family}-p{pad}" for family in FAMILIES for pad in PADS]
    meta={"revision":rev,"cpu":cpu,"compiler_version":version,"expected_dmd":a.expected_dmd,
          "families":FAMILIES,"pads":PADS,"sizes":SIZES,"blocks":3,
          "purpose":"deliberate code-placement variation with unchanged kernels and FP control state",
          "status":"running","observations":[replay.observe(cpu)]}
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

        # Each object contributes the same global function with N additional NOP bytes
        # in the ordinary .text section. It is linked before the D sources. The script
        # verifies target symbol addresses changed before accepting any timing evidence.
        pad_objects={}
        for pad in PADS:
            asm=root/f"placement-pad-{pad}.S"
            asm.write_text(
                ".text\n"
                ".p2align 6\n"
                ".globl colorDPlacementPad\n"
                ".type colorDPlacementPad,@function\n"
                "colorDPlacementPad:\n"
                f".fill {pad},1,0x90\n"
                "ret\n"
                ".size colorDPlacementPad,.-colorDPlacementPad\n")
            obj=root/f"placement-pad-{pad}.o"
            run([cc,"-c",asm,"-o",obj],work,f"build-pad-{pad}.txt")
            pad_objects[pad]=obj

        sources=["bench.d","candidates.d","machado_candidates.d","bv_policy.d","_generated/bv.d","_generated/ma.d"]
        binary_hashes={}; placements={}; placement_rows=[]
        symbol_sets={}
        for family,define in FAMILIES.items():
            for pad in PADS:
                name=f"{family}-p{pad}"
                binary=root/("benchmark-"+name)
                run([compiler,"-O","-inline","-release","-boundscheck=on",
                     "-version=FpStateDiagnostic","-version="+define,"-of="+str(binary),
                     pad_objects[pad],fpobj,*sources],work,"build-"+name+".txt")
                run(["objdump","-d","--no-show-raw-insn","-M","intel",binary],work,"codegen/"+name+".txt")
                syms,nmtext=parse_symbols(binary,work)
                (root/"symbols").mkdir(exist_ok=True)
                (root/"symbols"/(name+".txt")).write_text(nmtext)
                symbol_sets[name]=set(syms)
                placements[name]=syms
                binary_hashes[name]=hashlib.sha256(binary.read_bytes()).hexdigest()
                for sym,addr in sorted(syms.items()):
                    placement_rows.append([name,family,pad,sym,f"0x{addr:x}",addr%64,addr%4096])

        # Same family must expose the same target symbol set under every placement.
        for family in FAMILIES:
            names=[f"{family}-p{pad}" for pad in PADS]
            first=symbol_sets[names[0]]
            if any(symbol_sets[n]!=first for n in names[1:]):
                raise RuntimeError("target symbol set changed across placement variants: "+family)

        with (root/"placement.csv").open("w",newline="") as f:
            w=csv.writer(f); w.writerow(["variant","family","pad_bytes","symbol","address","mod64","mod4096"]); w.writerows(placement_rows)

        shifted={}
        for family in FAMILIES:
            names=[f"{family}-p{pad}" for pad in PADS]
            base=placements[names[0]]
            changed=set()
            for n in names[1:]:
                for sym,addr in placements[n].items():
                    if (addr%4096)!=(base[sym]%4096):
                        changed.add(sym)
            shifted[family]=len(changed)
            if not changed:
                raise RuntimeError("padding did not change target symbol page offsets: "+family)

        meta["binary_sha256"]=binary_hashes
        meta["shifted_target_symbols"]=shifted

        # Rotate full variant order so pad size is not confounded with elapsed time.
        base_order=[f"{family}-p{pad}" for pad in PADS for family in ("index","reference")]
        orders=[
            base_order,
            list(reversed(base_order)),
            base_order[len(base_order)//2:]+base_order[:len(base_order)//2],
        ]
        for block,order in enumerate(orders):
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

        groups=defaultdict(list); fp_control_changes=[]; fp_flag_changes=[]; observed_controls=set()
        for path in sorted((root/"raw").glob("*.csv")):
            block,n,tail=path.stem.split("-",2)
            variant,reverse=tail.rsplit("-",1)
            rows=list(csv.reader(path.open()))
            for r in rows:
                if r and r[0]=="sample":
                    groups[(variant,r[2],r[3],r[4],n,block,reverse)].append(float(r[8]))
            states=[r for r in rows if r and r[0]=="fpstate"]; pending={}
            for r in states:
                key=tuple(r[2:7])
                if r[1]=="before": pending[key]=(r[7],r[8])
                elif r[1]=="after":
                    before=pending.pop(key,None)
                    if before is None: raise RuntimeError("FP-state after without before")
                    bm,bx=int(before[0],16),int(before[1],16); am,ax=int(r[7],16),int(r[8],16)
                    observed_controls.add((bm & 0xffffffc0,bx)); observed_controls.add((am & 0xffffffc0,ax))
                    if (bm & 0xffffffc0)!=(am & 0xffffffc0) or bx!=ax:
                        fp_control_changes.append([path.name,*key,before[0],before[1],r[7],r[8]])
                    if (bm & 0x3f)!=(am & 0x3f):
                        fp_flag_changes.append([path.name,*key,before[0],r[7]])
            if pending: raise RuntimeError("FP-state before without after")
        if any(len(v)!=9 for v in groups.values()): raise RuntimeError("unexpected timing round count")

        with (root/"summary.csv").open("w",newline="") as f:
            w=csv.writer(f); w.writerow(["variant","scalar","mode","deficiency","n","block","reverse","samples","min_ns","median_ns","max_ns"])
            for k,v in sorted(groups.items()): w.writerow([*k,len(v),min(v),statistics.median(v),max(v)])
        with (root/"fp-control-changes.csv").open("w",newline="") as f:
            w=csv.writer(f); w.writerow(["file","scalar","mode","deficiency","n","reverse","before_mxcsr","before_x87","after_mxcsr","after_x87"]); w.writerows(fp_control_changes)
        with (root/"fp-flag-changes.csv").open("w",newline="") as f:
            w=csv.writer(f); w.writerow(["file","scalar","mode","deficiency","n","reverse","before_mxcsr","after_mxcsr"]); w.writerows(fp_flag_changes)

        meta.update(status="passed",timing_groups=len(groups),
                    fp_control_changes=len(fp_control_changes),fp_flag_changes=len(fp_flag_changes),
                    observed_fp_controls=[{"mxcsr_control":f"0x{m:08x}","x87_control":f"0x{x:04x}"} for m,x in sorted(observed_controls)],
                    interpretation="Placement diagnostic only; no production performance winner selected")
    except BaseException as e:
        meta.update(status="failed",error=str(e)); raise
    finally:
        save()
        files=sorted(p for p in root.rglob("*") if p.is_file())
        (root/"files.sha256").write_text("".join(hashlib.sha256(p.read_bytes()).hexdigest()+"  "+str(p.relative_to(root))+"\n" for p in files))

if __name__=="__main__": main()
