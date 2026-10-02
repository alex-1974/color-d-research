import hashlib,json,re,subprocess,sys,struct
from pathlib import Path
root=Path(sys.argv[1]);out=root/'targeted-code';out.mkdir(exist_ok=True)
records=[]
for binary in sorted(root.glob('benchmark-*')):
    data=binary.read_bytes()
    assert data[:6]==b'\x7fELF\x02\x01'
    shoff=struct.unpack_from('<Q',data,40)[0]
    entsize,count=struct.unpack_from('<HH',data,58)
    sections=[struct.unpack_from('<IIQQQQIIQQ',data,shoff+i*entsize) for i in range(count)]
    def constant(addr,width):
        for section in sections:
            name,kind,flags,start,offset,size,link,info,align,entry=section
            if kind==1 and flags&2 and not flags&1 and start<=addr and addr+width<=start+size:
                return data[offset+addr-start:offset+addr-start+width].hex()
        return None
    symbols=subprocess.check_output(['objdump','-t',str(binary)],text=True)
    for scalar,suffix in [('float','Tf'),('double','Td')]:
        for label,selector in [('lookup','lookupBatch'+suffix),('prepared','batch'+suffix+'VEQt4Modei2'),('matrix','matrixAtSeverity'+suffix)]:
            matches=[line.split() for line in symbols.splitlines() if selector in line and ' F ' in line]
            if not matches: continue
            assert len(matches)==1,(binary,label,scalar)
            sym=matches[0][-1];addr=int(matches[0][0],16)
            text=subprocess.check_output(['objdump','-d','--no-show-raw-insn','-M','intel','--disassemble='+sym,str(binary)],text=True)
            normalized=[];with_constants=[];constant_reads=[]
            for line in text.splitlines():
                m=re.match(r'^\s*[0-9a-f]+:\s*(.+)$',line)
                if not m:continue
                instr=m[1]
                literal=None
                target=re.search(r'#\s*([0-9a-f]+)\s+<[^>]+>',instr)
                widths={'BYTE':1,'WORD':2,'DWORD':4,'QWORD':8,'TBYTE':10,'XMMWORD':16}
                width=re.search(r'\b(BYTE|WORD|DWORD|QWORD|TBYTE|XMMWORD) PTR \[rip',instr)
                if target and width:
                    literal=constant(int(target[1],16),widths[width[1]])
                    if literal is not None:constant_reads.append(dict(address=target[1],bytes=literal))
                instr=re.sub(r'(?<=\[rip)[+-]0x[0-9a-f]+','+DISP',instr)
                instr=re.sub(r'(#\s*)[0-9a-f]+(?=\s+<)',r'\1ADDR',instr)
                instr=re.sub(r'\b((?:j[a-z]+|call)\s+)[0-9a-f]+(?=\s+<)',r'\1ADDR',instr)
                instr=re.sub(r'_TMP\d+','_TMPID',instr)
                normalized.append(instr)
                with_constants.append(re.sub(r'<[^>]+>', '<readonly-bytes:'+literal+'>', instr) if literal is not None else instr)
            assert normalized
            name=binary.name+'-'+scalar+'-'+label+'.txt'
            (out/name).write_text(text)
            records.append(dict(binary=binary.name,scalar=scalar,function=label,symbol=sym,address=hex(addr),
                address_mod64=addr%64,address_mod4096=addr%4096,instructions=len(normalized),
                normalized_sha256=hashlib.sha256('\n'.join(normalized).encode()).hexdigest(),
                binary_sha256=hashlib.sha256(data).hexdigest(),readonly_constant_reads=constant_reads,
                constants_normalized_sha256=hashlib.sha256('\n'.join(with_constants).encode()).hexdigest()))
(out/'comparison.json').write_text(json.dumps({'normalization':'Remove instruction addresses, relative branch/call target addresses and RIP displacements; retain symbols, symbol offsets, branch conditions and arithmetic. Normalize only generated _TMP numeric identifiers. Placement and execution state are not normalized equivalence claims.','constant_normalization':'Additional diagnostic hash replaces read-only RIP operand symbol labels with the exact bytes read from ELF PROGBITS sections that are allocated and not writable. Symbols on branches/calls and all other operands remain. This checks linked constant content without asserting execution-state equivalence.','functions':records},indent=2))
for scalar in ('float','double'):
 for func in ('lookup','prepared','matrix'):
  rows=[r for r in records if r['scalar']==scalar and r['function']==func]
  print(scalar,func,len(rows),'functions',len(set(r['normalized_sha256'] for r in rows)),'normalized sequences',[(r['binary'],r['address_mod64']) for r in rows])
