import csv,hashlib,io,json,statistics,sys,zipfile
from collections import defaultdict
from pathlib import Path,PurePosixPath
z=zipfile.ZipFile(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=False)
assert all(not PurePosixPath(n).is_absolute() and '..' not in PurePosixPath(n).parts for n in z.namelist())
# upload-artifact puts the contents directly at the ZIP root.
def read(name): return z.read(name)
manifest=read('files.sha256').decode().splitlines()
for line in manifest:
    digest,name=line.split('  ',1)
    assert hashlib.sha256(read(name)).hexdigest()==digest,name
meta=json.loads(read('metadata.json'));assert meta['status']=='passed'
assert meta['revision']==(sys.argv[3] if len(sys.argv)>3 else 'bb8f2a9bb129ac58e0ff23653145375b2af0b085')
assert meta['blocks']==3 and meta['sizes']==[1024,8191,65536]
paired='oldindex' in meta['variants']
assert set(meta['variants'])==({'index','reference','lookup','prepared','oldindex','oldreference'} if paired else {'index','reference','lookup','prepared'})
commands=json.loads(read('commands.json'));assert len(commands)==(123 if paired else 82)
assert all(c['returncode']==0 for c in commands)
pinned=[c for c in commands if c['argv'][0]=='taskset'];assert len(pinned)==(108 if paired else 72)
assert all(c['argv'][1:3]==['-c',str(meta['cpu'])] for c in pinned)
for v,digest in meta['binary_sha256'].items(): assert hashlib.sha256(read('benchmark-'+v)).hexdigest()==digest
source=[]
for n in z.namelist():
    if n.startswith('source/'):
        data=read(n);source.append({'path':n[7:],'sha':hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()})
assert len(source)==15 # 12 tracked files and three generated files
G=defaultdict(list);checks=defaultdict(list)
for c in pinned:
    name=c['stdout'];block,n,v,reverse=PurePosixPath(name).stem.split('-')
    rows=[r for r in csv.reader(io.StringIO(read(name).decode())) if r and r[0]=='sample']
    assert len(rows)==(6 if v in ('lookup','prepared') else 28)*9
    for r in rows:
        assert r[1]=='D' and r[5]==n and r[6]==('true' if reverse=='1' else 'false')
        k=(v,r[2],r[3],r[4],n,block,reverse)
        G[k].append((int(r[7]),float(r[8])))
        if r[3] in ('lookup','prepared'):checks[r[2],r[3],r[4],n,block,reverse,r[7]].append(float(r[9]))
for v in G.values(): assert sorted(i for i,t in v)==list(range(9))
assert all(len(v)==(5 if paired else 3) and max(v)==min(v) for v in checks.values())
summary=list(csv.DictReader(io.StringIO(read('summary.csv').decode())))
assert len(summary)==len(G)==(2232 if paired else 1224)
for r in summary:
    k=tuple(r[x] for x in ('variant','scalar','mode','deficiency','n','block','reverse'))
    vals=[v for i,v in G[k]]
    assert int(r['samples'])==9
    assert all(float(r[label])==func(vals) for label,func in [('min_ns',min),('median_ns',statistics.median),('max_ns',max)])
assert meta['raw_rows']==sum(map(len,G.values()))==(20088 if paired else 11016)
for filename,fields in [('block-summary.csv',('variant','scalar','mode','deficiency','n','block')),('pooled-summary.csv',('variant','scalar','mode','deficiency','n'))]:
    regrouped=defaultdict(list)
    for k,values in G.items():regrouped[k[:len(fields)]].extend(t for i,t in values)
    with (out/filename).open('w',newline='') as stream:
        writer=csv.writer(stream);writer.writerow([*fields,'samples','min_ns','median_ns','max_ns'])
        for k,values in sorted(regrouped.items()):writer.writerow([*k,len(values),min(values),statistics.median(values),max(values)])

for name in ('metadata.json','summary.csv','lscpu.txt','prepare.txt'):
    (out/name).write_bytes(read(name))
verification={'manifest_entries':len(manifest),'commands':len(commands),'pinned_processes':len(pinned),
'raw_rows':sum(map(len,G.values())),'reconstructed_summary_rows':len(G),'control_checksum_differences':0,
'binary_hashes':meta['binary_sha256'],'source_blobs':source,'archive_sha256':hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest()}
if paired:
    assert meta['original_revision']=='bc2c387e933469901cd8c2d2cedfe0b700db9f5f'
    original=read('original-source/experiments/r7_4_5_cvd_performance/bench.d')
    verification['original_bench_blob']=hashlib.sha1(b'blob '+str(len(original)).encode()+b'\0'+original).hexdigest()
    prefix='source/experiments/r7_4_5_cvd_performance/'
    original_names=[n for n in z.namelist() if n.startswith('original-source/')]
    assert len(original_names)==15
    for n in original_names:
        if n!='original-source/experiments/r7_4_5_cvd_performance/bench.d':assert read(n)==read('source/'+n[len('original-source/'):])
(out/'verification.json').write_text(json.dumps(verification,indent=2))
# Preserve diagnostic binaries only locally; never execute these files.
for v in meta['variants']:(out/('benchmark-'+v)).write_bytes(read('benchmark-'+v))
# Pooled comparison from raw samples, with blocks/directions retained separately.
P=defaultdict(list)
for k,v in G.items(): P[k[:5]].extend(t for i,t in v)
ratios=[]
for mode in ('lookup','prepared'):
    for scalar in ('float','double'):
        for d in map(str,range(3)):
            for n in map(str,meta['sizes']):
                for base,target in ([('index','reference'),('index',mode),('reference',mode)]+([('oldindex','oldreference'),('oldindex',mode),('oldreference',mode),('oldindex','index'),('oldreference','reference')] if paired else [])):
                    key=(scalar,mode,d,n)
                    ratios.append(dict(scalar=scalar,mode=mode,deficiency=d,n=n,base=base,target=target,
                        base_ns=statistics.median(P[base,*key]),target_ns=statistics.median(P[target,*key]),
                        speedup=statistics.median(P[base,*key])/statistics.median(P[target,*key])))
(out/'comparisons.json').write_text(json.dumps(ratios,indent=2))
print(json.dumps({k:v for k,v in verification.items() if k not in ('source_blobs','binary_hashes')}))
for mode in ('lookup','prepared'):
    for scalar in ('float','double'):
        for base,target in ([('index','reference'),('index',mode),('reference',mode)]+([('oldindex','oldreference'),('oldindex',mode),('oldreference',mode),('oldindex','index'),('oldreference','reference')] if paired else [])):
            values=[r['speedup'] for r in ratios if (r['mode'],r['scalar'],r['base'],r['target'])==(mode,scalar,base,target)]
            print(mode,scalar,base,target,min(values),max(values))
