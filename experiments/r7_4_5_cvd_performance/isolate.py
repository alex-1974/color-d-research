#!/usr/bin/env python3
"""Fixed-binary, balanced process isolation diagnostic; no performance acceptance."""
import argparse
from collections import defaultdict
import csv
import hashlib
import json
from pathlib import Path
import shutil
import statistics
import subprocess
import sys
import time
import replay

VARIANTS = {'index': 'IndexedVienot', 'reference': 'ReferenceVienot',
            'lookup': 'IsolateLookup', 'prepared': 'IsolatePrepared',
            'oldindex': 'IndexedVienot', 'oldreference': 'ReferenceVienot'}
ORIGINAL = 'bc2c387e933469901cd8c2d2cedfe0b700db9f5f'

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--compiler', required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    root = args.output.resolve()
    root.mkdir(parents=True, exist_ok=False)
    repo = Path(replay.capture(['git', 'rev-parse', '--show-toplevel'], Path(__file__).parent).decode().strip())
    revision = replay.capture(['git', 'rev-parse', 'HEAD'], repo).decode().strip()
    paths = [*replay.FILES, replay.EXPERIMENT / 'isolate.py']
    ledger = []
    cpu = min(__import__('os').sched_getaffinity(0))
    meta = {'revision': revision, 'cpu': cpu, 'blocks': 3,
            'sizes': [1024,8191,65536], 'variants': VARIANTS, 'original_revision': ORIGINAL,
            'observations': [replay.observe(cpu)], 'status': 'running'}
    def save():
        (root/'metadata.json').write_text(json.dumps(meta, indent=2))
        (root/'commands.json').write_text(json.dumps(ledger, indent=2))
    def run(argv, cwd, target):
        target = root/target
        target.parent.mkdir(parents=True, exist_ok=True)
        item = {'argv': list(map(str,argv)), 'stdout': str(target.relative_to(root)),
                'cwd': str(cwd), 'start_ns': time.time_ns()}
        ledger.append(item)
        with target.open('wb') as out, Path(str(target)+'.stderr').open('wb') as err:
            proc = subprocess.run(item['argv'],cwd=cwd,stdout=out,stderr=err)
        item.update(returncode=proc.returncode,end_ns=time.time_ns())
        save()
        if proc.returncode: raise RuntimeError('command failed: '+str(argv[0]))
    try:
        source = root/'source'
        for path in paths:
            content = replay.capture(['git','show',revision+':'+str(path)],repo)
            if path.name == 'isolate.py' and content != Path(__file__).read_bytes():
                raise RuntimeError('driver differs from tracked source')
            target = source/path
            target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes(content)
        work = source/replay.EXPERIMENT
        # Rebuild the measured original source on this same host. Other experiment
        # inputs must be byte-identical, so this comparison changes bench.d only.
        for path in replay.FILES:
            original = replay.capture(['git','show',ORIGINAL+':'+str(path)],repo)
            if path.name == 'bench.d':
                historical = work/'historical'/'bench.d'
                historical.parent.mkdir()
                historical.write_bytes(original)
            elif original != (source/path).read_bytes():
                raise RuntimeError('original dependency changed: '+str(path))
        compiler = shutil.which(args.compiler)
        if not compiler: raise RuntimeError('compiler missing')
        version = replay.capture([compiler,'--version'],repo).decode()
        meta['compiler_version'] = version
        ldc = 'ldc' in version.lower()
        optimize = ['-O3','-fp-contract=off'] if ldc else ['-O','-inline']
        flag = '-d-version=' if ldc else '-version='
        run(['lscpu'], work, 'lscpu.txt')
        run([sys.executable,'prepare.py'],work,'prepare.txt')
        sources=['bench.d','candidates.d','machado_candidates.d','bv_policy.d','_generated/bv.d','_generated/ma.d']
        for variant,define in VARIANTS.items():
            binary=root/('benchmark-'+variant)
            selected_sources = ['historical/bench.d', *sources[1:]] if variant.startswith('old') else sources
            run([compiler,*optimize,'-release','-boundscheck=on',flag+define,'-of='+str(binary),*selected_sources],work,'build-'+variant+'.txt')
            run(['objdump','-d','--no-show-raw-insn','-M','intel',binary],work,'codegen/'+variant+'.txt')
        binaries={v:hashlib.sha256((root/('benchmark-'+v)).read_bytes()).hexdigest() for v in VARIANTS}
        meta['binary_sha256']=binaries
        # Same binary is invoked again after other processes; no per-block rebuild.
        orders=[['oldindex','lookup','reference','oldreference','prepared','index'],
                ['index','prepared','oldreference','reference','lookup','oldindex'],
                ['reference','oldreference','prepared','index','oldindex','lookup']]
        for block,order in enumerate(orders):
            meta['observations'].append(replay.observe(cpu))
            sizes=meta['sizes'] if block%2==0 else list(reversed(meta['sizes']))
            for n in sizes:
                for reverse in (False,True):
                    for variant in (list(reversed(order)) if reverse else order):
                        argv=['taskset','-c',str(cpu),root/('benchmark-'+variant),str(n)]
                        if reverse: argv.append('reverse')
                        run(argv,work,f'raw/{block}-{n}-{variant}-{int(reverse)}.csv')
            meta['observations'].append(replay.observe(cpu))
        if any(hashlib.sha256((root/('benchmark-'+v)).read_bytes()).hexdigest()!=h for v,h in binaries.items()):
            raise RuntimeError('fixed binary changed')
        groups=defaultdict(list)
        checks=defaultdict(list)
        for path in sorted((root/'raw').glob('*.csv')):
            block,n,variant,reverse=path.stem.split('-')
            rows=[r for r in csv.reader(path.open()) if r and r[0]=='sample']
            expected=6 if variant in ('lookup','prepared') else 28
            if len(rows)!=expected*9: raise RuntimeError('missing raw rows')
            for r in rows:
                if r[1]!='D' or r[5]!=n or r[6] != ('true' if reverse=='1' else 'false'):
                    raise RuntimeError('sample identity mismatch')
                key=(variant,r[2],r[3],r[4],n,block,reverse)
                groups[key].append(float(r[8]))
                checks[(r[2],r[3],r[4],n,block,reverse,r[7])].append(float(r[9]))
        if any(len(v)!=9 for v in groups.values()): raise RuntimeError('round count')
        # Unchanged prepared/lookup outputs must agree across integrated and isolated programs.
        if any(max(v)!=min(v) for k,v in checks.items() if k[1] in ('lookup','prepared')):
            raise RuntimeError('unchanged control checksum mismatch')
        header=['variant','scalar','mode','deficiency','n','block','reverse','samples','min_ns','median_ns','max_ns']
        with (root/'summary.csv').open('w',newline='') as f:
            writer=csv.writer(f);writer.writerow(header)
            for k,v in sorted(groups.items()):
                writer.writerow([*k,len(v),min(v),statistics.median(v),max(v)])
        meta.update(status='passed',raw_rows=sum(map(len,groups.values())),summary_rows=len(groups),
                    control_checksums='exact agreement; sampled outputs only',
                    interpretation='Placement and prior-case diagnostic; no C++ performance acceptance claim')
    except BaseException as error:
        meta.update(status='failed',error=str(error));raise
    finally:
        save()
        files=sorted(p for p in root.rglob('*') if p.is_file())
        (root/'files.sha256').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+str(p.relative_to(root))+'\n' for p in files))

if __name__=='__main__': main()
