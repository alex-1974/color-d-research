from pathlib import Path
import hashlib, re

root = Path(__file__).resolve().parent
experiments = root.parent
generated = root / '_generated'
generated.mkdir(exist_ok=True)
sources = {}
for name, directory in [('bv', 'r7_2_brettel_vienot_reference'), ('ma', 'r7_3_machado_2009_reference')]:
    path = experiments / directory / 'source/app.d'
    content = path.read_text()
    print(name, 'source_sha256', hashlib.sha256(path.read_bytes()).hexdigest())
    assert content.count('void main()') == 1
    (generated / (name + '.d')).write_text('module ' + name + ';\n' + content.replace('void main()', 'void referenceMain()'))
    sources[name] = content

# Coefficient sharing is only a fair arithmetic benchmark baseline, not an
# independent scientific oracle. No expected test values are generated here.
names = ['brettelProtan1', 'brettelProtan2', 'brettelDeutan1', 'brettelDeutan2', 'brettelTritan1', 'brettelTritan2', 'vienotProtan', 'vienotDeutan']
header = []
for name in names:
    match = re.search(r'enum Matrix3!double ' + name + r' = Matrix3!double\((.*?)\);', sources['bv'], re.S)
    assert match, name
    header.append('static const Matrix<double> ' + name + ' = {' + match[1] + '};')
for name in ['protanTable', 'deutanTable', 'tritanTable']:
    match = re.search(r'enum Matrix3!double\[11\] ' + name + r' = \[(.*?)\];', sources['ma'], re.S)
    assert match, name
    matrices = ['{1,0,0,0,1,0,0,0,1}']
    matrices += ['{' + m + '}' for m in re.findall(r'Matrix3!double\((.*?)\)', match[1], re.S)]
    assert len(matrices) == 11
    header.append('static const Matrix<double> ' + name + '[11] = {' + ','.join(matrices) + '};')
(generated / 'coefficients.hpp').write_text('\n'.join(header))
