"""Reconstruct combined-BV replay reports from a CI artifact ZIP, without execution."""
import csv
import hashlib
import io
import json
import math
from pathlib import Path
import statistics
import sys
import tarfile
import zipfile
from collections import defaultdict


def inspect(artifact, destination, expected_variants=None):
    if expected_variants is None:
        expected_variants=['default','prepared','bv_direct','bv_split']
    destination.mkdir(parents=True, exist_ok=False)
    codegen_files={}
    with zipfile.ZipFile(artifact) as z:
        tar_names=[n for n in z.namelist() if n.endswith('/bv-replay.tar.gz') or n=='bv-replay.tar.gz']
        assert len(tar_names)==1
        archive=z.read(tar_names[0])
        for mode in ['debug','release']:
            names=[n for n in z.namelist() if n.endswith('/'+mode+'.txt')]
            assert len(names)==1
            log=z.read(names[0])
            for scalar in ['float','double']:
                assert f'qualification,{scalar},inputs=5839,'.encode() in log
            shape_variants={'bv_vienot_index','bv_vienot_static','bv_vienot_ref'} & set(expected_variants)
            if shape_variants:
                assert b'vienot,indexed/static,empty/tails/batch-in-place/CTFE/attributes=PASS' in log
            shape_log=b'vienot,indexed/static,empty/tails/batch-in-place/CTFE/attributes=PASS'
            reference_log=b'vienot,reference,empty/tails/batch-in-place/CTFE/attributes=PASS'
            if 'bv_vienot_ref' in expected_variants: assert reference_log in log
            assert log.count(b'=PASS')==2+int(shape_log in log)+int(reference_log in log)
            (destination/(mode+'.txt')).write_bytes(log)
        codegen_variants={'bv_vienot_index','bv_vienot_static','bv_vienot_ref'} & set(expected_variants)
        if codegen_variants:
            names=[n for n in z.namelist() if '/codegen/' in n and not n.endswith('/')]
            expected_files=1+2*(2+len(codegen_variants))
            assert len(names)==expected_files and len({Path(n).name for n in names})==expected_files
            codegen_files={Path(n).name:z.read(n) for n in names}
    with tarfile.open(fileobj=io.BytesIO(archive),mode='r:gz') as t:
        assert all(m.isdir() or m.isfile() for m in t.getmembers())
        roots={m.name.split('/')[0] for m in t.getmembers()}
        assert len(roots)==1
        root=next(iter(roots))+'/'
        files={m.name[len(root):]:t.extractfile(m).read() for m in t.getmembers() if m.isfile()}
    manifest={p:h for h,p in (line.split('  ',1) for line in files['files.sha256'].decode().splitlines())}
    assert set(manifest)==set(files)-{'files.sha256'}
    assert all(hashlib.sha256(files[p]).hexdigest()==h for p,h in manifest.items())
    metadata=json.loads(files['metadata.json'])
    assert metadata['status']=='passed' and len(metadata['compilers'])==1
    assert metadata['sizes']==[1024,8191,65536] and metadata['blocks']==3
    assert metadata['variants']==expected_variants
    if 'bv_compiler' in expected_variants:
        selected='direct' if metadata['compilers'][0]['family']=='dmd' else 'original'
        for mode in ['debug','release']:
            assert f'policy,portable,double-vienot=original,compilerSelected,double-vienot={selected}' in (destination/(mode+'.txt')).read_text()
    commands=json.loads(files['commands.json'])
    assert all(c['returncode']==0 for c in commands)
    timed=[c for c in commands if c['stdout'].endswith(('d-forward.csv','d-reverse.csv','cpp-forward.csv','cpp-reverse.csv'))]
    assert len(timed)==len(expected_variants)*len(metadata['sizes'])*metadata['blocks']*4
    assert all(c['argv'][:3]==['taskset','-c',str(metadata['cpu'])] for c in timed)
    keys={(s,m,str(d)) for s in ['float','double'] for m,ds in [('brettel',range(3)),('vienot',range(2)),('prepared',range(3)),('lookup',range(3)),('lookupApply',range(3))] for d in ds}
    all_samples=defaultdict(list); block_rows=[]; checksum_max={'float':0.,'double':0.}
    def csv_rows(name): return csv.reader(io.StringIO(files[name].decode()))
    def check_summary(row, samples):
        for language in ['D','CPP']:
            values=samples[language]
            for label,func in [('min',min),('median',statistics.median),('max',max)]:
                assert float(row[f'{language}_{label}_ns'])==func(values)
        assert float(row['D_over_CPP'])==statistics.median(samples['D'])/statistics.median(samples['CPP'])
    for n in metadata['sizes']:
      for block in range(metadata['blocks']):
       for variant in metadata['variants']:
        prefix=f'compiler-0-{metadata["compilers"][0]["family"]}/n-{n}/block-{block}/{variant}/'
        samples={}
        for language,stem in [('D','d'),('CPP','cpp')]:
         for direction in ['forward','reverse']:
          rows=[r for r in csv_rows(prefix+stem+'-'+direction+'.csv') if r[0]=='sample']
          assert len(rows)==252
          for r in rows:
           assert r[1]==language and int(r[5])==n and r[6]==str(direction=='reverse').lower()
           key=(r[2],r[3],r[4]); assert key in keys
           round_index=int(r[7]); assert 0<=round_index<9
           sample_key=(language,*key,direction,round_index)
           assert sample_key not in samples
           ns,checksum=float(r[8]),float(r[9]); assert ns>0 and math.isfinite(ns) and math.isfinite(checksum)
           samples[sample_key]=(ns,checksum)
           all_samples[(variant,*key,str(n),language)].append(ns)
        for key in {k[1:] for k in samples}:
            diff=abs(samples[('D',*key)][1]-samples[('CPP',*key)][1])
            checksum_max[key[0]]=max(checksum_max[key[0]],diff)
            assert diff<=48*({'float':2e-6,'double':1e-12}[key[0]])
        summaries=list(csv.DictReader(io.StringIO(files[prefix+'summary.csv'].decode())))
        assert {tuple(r[k] for k in ['scalar','mode','deficiency']) for r in summaries}==keys and len(summaries)==28
        for row in summaries:
            key=tuple(row[k] for k in ['scalar','mode','deficiency'])
            values={lang:[v[0] for k,v in samples.items() if k[0]==lang and k[1:4]==key] for lang in ['D','CPP']}
            assert all(len(v)==18 for v in values.values())
            check_summary(row,values)
            block_rows.append(dict(variant=variant,block=str(block),**row))
    pooled=list(csv.DictReader(io.StringIO(files['pooled-summary.csv'].decode())))
    expected_rows=len(expected_variants)*len(metadata['sizes'])*len(keys)
    assert len(pooled)==expected_rows
    assert len({tuple(r[k] for k in ['variant','scalar','mode','deficiency','n']) for r in pooled})==expected_rows
    for row in pooled:
        values={lang:all_samples[tuple(row[k] for k in ['variant','scalar','mode','deficiency','n'])+(lang,)] for lang in ['D','CPP']}
        assert all(len(v)==54 for v in values.values()) and row['samples_per_language']=='54'
        check_summary(row,values)
    (destination/'pooled-summary.csv').write_bytes(files['pooled-summary.csv'])
    for name in ['lscpu.txt','prepare.txt','binaries.sha256']:
        if name in files: (destination/name).write_bytes(files[name])
    with (destination/'block-summary.csv').open('w') as f:
        w=csv.DictWriter(f,fieldnames=list(block_rows[0]));w.writeheader();w.writerows(block_rows)
    evidence=dict(archive_sha256=hashlib.sha256(archive).hexdigest(),archive_bytes=len(archive),manifest_entries=len(manifest),commands=len(commands),raw_sample_rows=sum(map(len,all_samples.values())),checksum_max_abs=checksum_max,metadata=metadata,source_hashes={p:h for p,h in manifest.items() if p.startswith('source/')},binary_hashes={p:h for p,h in manifest.items() if ('/benchmark-' in p and not p.endswith('.o')) or p=='cpp-benchmark'})
    if codegen_files:
        records=json.loads(codegen_files['inspection.json'])
        assert len(records)==2+len(codegen_variants)
        family=metadata['compilers'][0]['family']
        expected_binaries={'cpp-benchmark','benchmark-bv_compiler'} | {'benchmark-'+v for v in codegen_variants}
        assert {Path(r['binary']).name for r in records}==expected_binaries
        for record in records:
            name=Path(record['binary']).name
            path=name if name=='cpp-benchmark' else 'compiler-0-'+family+'/'+name
            assert record['sha256']==evidence['binary_hashes'][path]
            assert len(record['functions'])==2
            assert {f['scalar'] for f in record['functions']}=={'float','double'}
            for function in record['functions']:
                assert function['instruction_count']==sum(function['mnemonics'].values())
                assert ('<'+function['symbol']+'>:').encode() in codegen_files[function['disassembly']]
        output=destination/'codegen';output.mkdir()
        for name,content in codegen_files.items(): (output/name).write_bytes(content)
        evidence['verified_codegen_binaries']=len(records)
    evidence['verified_timed_affinity_commands']=len(timed)
    evidence['build_commands']=[c['argv'] for c in commands if Path(c['stdout']).name.startswith('build-')]
    (destination/'inspection.json').write_text(json.dumps(evidence,indent=2)+'\n')
    print(artifact.name, 'PASS',len(pooled),'pooled cases;',len(block_rows),'block cases;',checksum_max)


if __name__=='__main__':
    assert len(sys.argv)>=3, 'usage: inspect_bv_replay.py ARTIFACT.zip NEW_OUTPUT_DIRECTORY [EXPECTED_VARIANT ...]'
    inspect(Path(sys.argv[1]),Path(sys.argv[2]),sys.argv[3:] or None)
