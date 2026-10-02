#!/usr/bin/env python3
"""Retain only Viénot batch disassembly from fixed replay binaries; never run them."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import subprocess

def inspect(binary, output):
    table = subprocess.check_output(['objdump','-t',str(binary)], text=True)
    symbols = []
    for line in table.splitlines():
        parts = line.split()
        if len(parts) < 6 or parts[2:4] != ['F','.text']:
            continue
        name = parts[-1]
        if re.search(r'_D5bench__T5batchT[fd]VEQt4Modei1Z',name):
            scalar = 'float' if 'batchTf' in name else 'double'
        elif re.search(r'_Z5batchI[fd]L4Mode1E',name):
            scalar = 'float' if 'batchIf' in name else 'double'
        else:
            continue
        symbols.append((scalar,name,int(parts[0],16),int(parts[-2],16)))
    assert len(symbols) == 2 and {s[0] for s in symbols} == {'float','double'}, symbols
    record = {'binary':str(binary),'sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'functions':[]}
    for scalar,name,address,size in symbols:
        asm = subprocess.check_output(['objdump','-d','--no-show-raw-insn','-M','intel','--disassemble='+name,str(binary)], text=True)
        mnemonics = Counter()
        for line in asm.splitlines():
            match = re.match(r'^\s*[0-9a-f]+:\s+(.+)$',line)
            if match:
                tokens = match[1].split()
                while tokens and tokens[0] in ('rex.W','rex','data16','addr32','rep','repz','repnz','bnd','cs','ds','es','ss'):
                    tokens.pop(0)
                if tokens:
                    mnemonics[tokens[0]] += 1
        assert mnemonics, name
        filename = binary.name+'-'+scalar+'.txt'
        (output/filename).write_text(asm)
        record['functions'].append({'scalar':scalar,'symbol':name,'address':address,'bytes':size,
            'instruction_count':sum(mnemonics.values()),'mnemonics':dict(sorted(mnemonics.items())),
            'disassembly':filename})
    return record

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('binaries',type=Path,nargs='+')
    args = parser.parse_args()
    assert len({p.name for p in args.binaries}) == len(args.binaries)
    args.output.mkdir(parents=True,exist_ok=False)
    records = [inspect(path,args.output) for path in args.binaries]
    (args.output/'inspection.json').write_text(json.dumps(records,indent=2)+'\n')

if __name__ == '__main__':
    main()
