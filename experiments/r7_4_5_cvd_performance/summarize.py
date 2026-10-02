import csv, math, statistics, sys
from collections import defaultdict
from pathlib import Path

root = Path(__file__).resolve().parent
data = defaultdict(list)
checks = {}
for filename in ['d-forward.csv', 'd-reverse.csv', 'cpp-forward.csv', 'cpp-reverse.csv']:
    for row in csv.reader((root / filename).open()):
        if not row or row[0] != 'sample':
            continue
        _, language, scalar, mode, deficiency, n, reverse, round_, ns, checksum = row
        ns, checksum = float(ns), float(checksum)
        if not (math.isfinite(ns) and ns > 0 and math.isfinite(checksum)):
            raise SystemExit('non-finite result or invalid elapsed time')
        key = scalar, mode, deficiency, n
        data[language, *key].append(ns)
        sample = *key, reverse, round_
        if (language, sample) in checks:
            raise SystemExit('duplicate sample')
        checks[language, sample] = checksum

if len(data) != 56 or any(len(v) != 18 for v in data.values()):
    raise SystemExit('incomplete 28-case x 2-language x 18-sample matrix')
max_difference = defaultdict(float)
for (language, sample), value in checks.items():
    if language != 'D':
        continue
    other = checks['CPP', sample]
    error = abs(value - other)
    max_difference[sample[0]] = max(max_difference[sample[0]], error)
    tolerance = 48 * (2e-6 if sample[0] == 'float' else 1e-12)
    if error > tolerance:
        raise SystemExit(f'cross-language checksum mismatch {sample}: {error}')

with (root / 'summary.csv').open('w') as output:
    writer = csv.writer(output)
    writer.writerow(['scalar', 'mode', 'deficiency', 'n', 'D_min_ns', 'D_median_ns', 'D_max_ns', 'CPP_min_ns', 'CPP_median_ns', 'CPP_max_ns', 'D_over_CPP'])
    for key in sorted(k[1:] for k in data if k[0] == 'D'):
        dv, cv = data['D', *key], data['CPP', *key]
        row = [*key, min(dv), statistics.median(dv), max(dv), min(cv), statistics.median(cv), max(cv), statistics.median(dv)/statistics.median(cv)]
        writer.writerow(row)
        print('summary,' + ','.join(str(x) for x in row))
print('cross_language_checksum_max', dict(max_difference))
print('R7.4.5 benchmark matrix and checksum preflight: PASS')
