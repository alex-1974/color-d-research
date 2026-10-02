"""Inspect the pinned two-compiler integrated BV XPS protocol without executing binaries."""
import csv,hashlib,io,json,math,statistics,tarfile,sys
from collections import defaultdict
from pathlib import Path

assert len(sys.argv)==3, 'usage: inspect_xps_bv_policy.py ARCHIVE.tar.gz NEW_OUTPUT_DIRECTORY'
archive=Path(sys.argv[1])
out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=False)
with tarfile.open(archive) as t:
    members=t.getmembers();assert all(m.isfile() or m.isdir() for m in members)
    assert len({m.name for m in members})==len(members)
    roots={m.name.split('/')[0] for m in members};assert len(roots)==1
    root=next(iter(roots))+'/'
    files={m.name[len(root):]:t.extractfile(m).read() for m in members if m.isfile()}
manifest_lines=files['files.sha256'].decode().splitlines()
manifest={p:h for h,p in (l.split('  ',1) for l in manifest_lines)}
assert len(manifest)==len(manifest_lines) and set(manifest)==set(files)-{'files.sha256'}
assert all(hashlib.sha256(files[p]).hexdigest()==h for p,h in manifest.items())
md=json.loads(files['metadata.json'])
assert md['status']=='passed' and md['revision']=='e948f48b71bea374702d79ae8bf9a4aba0010e56'
assert md['sizes']==[1024,8191,65536] and md['blocks']==3
assert md['variants']==['default','bv_split','bv_compiler'] and len(md['compilers'])==2
assert [c['family'] for c in md['compilers']]==['dmd','ldc']
commands=json.loads(files['commands.json']);assert len(commands)==291 and all(c['returncode']==0 for c in commands)
timed=[c for c in commands if c['stdout'].endswith(('d-forward.csv','d-reverse.csv','cpp-forward.csv','cpp-reverse.csv'))]
assert len(timed)==216 and all(c['argv'][:3]==['taskset','-c',str(md['cpu'])] for c in timed)
keys={(s,m,str(d)) for s in ['float','double'] for m,ds in [('brettel',range(3)),('vienot',range(2)),('prepared',range(3)),('lookup',range(3)),('lookupApply',range(3))] for d in ds}
samples=defaultdict(list);blocks=[];checks={'float':0.,'double':0.}
def verify(row,values):
    for lang in ['D','CPP']:
        for label,func in [('min',min),('median',statistics.median),('max',max)]:
            assert float(row[f'{lang}_{label}_ns'])==func(values[lang])
    assert float(row['D_over_CPP'])==statistics.median(values['D'])/statistics.median(values['CPP'])
for ci,c in enumerate(md['compilers']):
    prefix=f'compiler-{ci}-{c["family"]}/';selected='direct' if c['family']=='dmd' else 'original'
    for mode in ['debug','release']:
        log=files[prefix+f'bv-qualification-{mode}.txt'].decode()
        assert f'policy,portable,double-vienot=original,compilerSelected,double-vienot={selected}' in log
        assert all(f'qualification,{s},inputs=5839,' in log for s in ['float','double']) and log.count('=PASS')==2
        (out/(prefix.removesuffix('/'))).mkdir(exist_ok=True)
        (out/prefix/f'bv-qualification-{mode}.txt').write_text(log)
    (out/prefix/'preflight.txt').write_bytes(files[prefix+'preflight.txt'])
    for n in md['sizes']:
      for block in range(3):
       for variant in md['variants']:
        path=prefix+f'n-{n}/block-{block}/{variant}/';matched={}
        for lang,stem in [('D','d'),('CPP','cpp')]:
         for direction in ['forward','reverse']:
          rows=[r for r in csv.reader(io.StringIO(files[path+stem+'-'+direction+'.csv'].decode())) if r[0]=='sample'];assert len(rows)==252
          for r in rows:
           key=tuple(r[2:5]);assert key in keys and r[1]==lang and int(r[5])==n and r[6]==str(direction=='reverse').lower() and 0<=int(r[7])<9
           ident=(lang,*key,direction,int(r[7]));assert ident not in matched
           ns,ch=float(r[8]),float(r[9]);assert ns>0 and math.isfinite(ns) and math.isfinite(ch)
           matched[ident]=(ns,ch);samples[(str(ci),variant,*key,str(n),lang)].append(ns)
        for key in {k[1:] for k in matched}:
            diff=abs(matched[('D',*key)][1]-matched[('CPP',*key)][1]);checks[key[0]]=max(checks[key[0]],diff)
            assert diff<=48*({'float':2e-6,'double':1e-12}[key[0]])
        report=list(csv.DictReader(io.StringIO(files[path+'summary.csv'].decode())))
        assert len(report)==28 and {tuple(r[k] for k in ['scalar','mode','deficiency']) for r in report}==keys
        for row in report:
            key=tuple(row[k] for k in ['scalar','mode','deficiency'])
            values={lang:[v[0] for k,v in matched.items() if k[0]==lang and k[1:4]==key] for lang in ['D','CPP']};assert all(len(v)==18 for v in values.values())
            verify(row,values);blocks.append(dict(compiler=str(ci),variant=variant,block=str(block),**row))
pooled=list(csv.DictReader(io.StringIO(files['pooled-summary.csv'].decode())))
assert len(pooled)==504 and len({tuple(r[k] for k in ['compiler','variant','scalar','mode','deficiency','n']) for r in pooled})==504 and len(blocks)==1512
for row in pooled:
    key=tuple(row[k] for k in ['compiler','variant','scalar','mode','deficiency','n'])
    values={lang:samples[(*key,lang)] for lang in ['D','CPP']};assert all(len(v)==54 for v in values.values()) and row['samples_per_language']=='54';verify(row,values)
for name in ['pooled-summary.csv','files.sha256','lscpu.txt','prepare.txt','binaries.sha256']:(out/name).write_bytes(files[name])
with (out/'block-summary.csv').open('w') as f:
    w=csv.DictWriter(f,fieldnames=list(blocks[0]));w.writeheader();w.writerows(blocks)
blob_shas=[]
for p,b in files.items():
    if p.startswith('source/experiments/') and '/_generated/' not in p:
        blob_shas.append(dict(path=p.removeprefix('source/'),sha=hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()))
evidence=dict(archive_name=archive.name,archive_bytes=archive.stat().st_size,archive_sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),manifest_entries=len(manifest),commands=len(commands),verified_timed_affinity_commands=len(timed),raw_sample_rows=sum(map(len,samples.values())),pooled_rows=len(pooled),block_rows=len(blocks),checksum_max_abs=checks,metadata=md,source_hashes={p:h for p,h in manifest.items() if p.startswith('source/')},tracked_source_git_blobs=blob_shas,binary_hashes={p:h for p,h in manifest.items() if ('/benchmark-' in p and not p.endswith('.o')) or p=='cpp-benchmark'},build_commands=[c['argv'] for c in commands if Path(c['stdout']).name.startswith('build-')])
(out/'inspection.json').write_text(json.dumps(evidence,indent=2)+'\n')
print(json.dumps({k:v for k,v in evidence.items() if k not in ['metadata','source_hashes','tracked_source_git_blobs','binary_hashes','build_commands']},indent=2))
