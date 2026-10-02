#!/usr/bin/env python3
"""Replay tracked CVD research kernels on Linux without changing the checkout."""
import argparse
from collections import defaultdict
import csv
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import shutil
import statistics
import subprocess
import sys
import tarfile
import tempfile
import time

VARIANTS = {
    'default': None, 'prepared': 'PreparedCvd', 'inline': 'InlineCvd',
    'bv_direct': 'DirectCvd', 'bv_split': 'SplitCvd',
    'ma_fixed': 'FixedMachado', 'ma_bounded': 'BoundedMachado',
    'ma_direct': 'DirectMachado',
    'bv_portable': 'PortableBvPolicy', 'bv_compiler': 'CompilerBvPolicy',
    'bv_vienot_index': 'IndexedVienot', 'bv_vienot_static': 'StaticVienot',
    'bv_vienot_ref': 'ReferenceVienot',
}
EXPERIMENT = Path('experiments/r7_4_5_cvd_performance')
FILES = [EXPERIMENT / name for name in (
    'bench.d', 'candidates.d', 'machado_candidates.d', 'prepare.py',
    'reference.cpp', 'summarize.py', 'replay.py', 'bv_policy.d', 'bv_qualification.d')]
FILES += [Path('experiments') / name / 'source/app.d' for name in (
    'r7_2_brettel_vienot_reference', 'r7_3_machado_2009_reference')]


def capture(args, cwd):
    return subprocess.check_output(args, cwd=cwd, stderr=subprocess.STDOUT)


def observe(cpu):
    """Read controls and thermal observations; never alter machine policy."""
    result = {'time_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
              'affinity': sorted(os.sched_getaffinity(0))}
    paths = list(Path(f'/sys/devices/system/cpu/cpu{cpu}/cpufreq').glob('*'))
    paths += list(Path('/sys/class/thermal').glob('thermal_zone*/temp'))
    paths += [Path('/sys/devices/system/cpu/intel_pstate/no_turbo'),
              Path('/sys/devices/system/cpu/cpufreq/boost'),
              Path('/sys/devices/system/cpu/smt/active')]
    for path in paths:
        if path.name not in ('scaling_governor', 'scaling_cur_freq', 'scaling_min_freq',
                             'scaling_max_freq', 'temp', 'no_turbo', 'boost', 'active'):
            continue
        try:
            result[str(path)] = path.read_text().strip()
        except OSError:
            pass
    return result


def parse_args():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--revision', default='HEAD')
    p.add_argument('--compilers', nargs='+', default=['dmd', 'ldc2'])
    p.add_argument('--variants', nargs='+', choices=VARIANTS, default=list(VARIANTS))
    p.add_argument('--sizes', nargs='+', type=int, default=[1024, 8191, 65536])
    p.add_argument('--blocks', type=int, default=3)
    p.add_argument('--cpu', type=int)
    p.add_argument('--output', type=Path)
    p.add_argument('--notes', default='')
    args = p.parse_args()
    if args.blocks < 1 or any(n < 32 or n > 1048576 for n in args.sizes):
        p.error('blocks must be positive; sizes must be 32..1048576')
    for values in (args.compilers, args.variants, args.sizes):
        if len(values) != len(set(values)):
            p.error('duplicate compiler, variant or size')
    allowed = os.sched_getaffinity(0)
    args.cpu = min(allowed) if args.cpu is None else args.cpu
    if args.cpu not in allowed:
        p.error('CPU is outside the current allowed affinity')
    return args


def main():
    args = parse_args()
    repo = Path(capture(['git', 'rev-parse', '--show-toplevel'], Path(__file__).parent).decode().strip())
    revision = capture(['git', 'rev-parse', '--verify', args.revision + '^{commit}'], repo).decode().strip()
    snapshot = {str(path): capture(['git', 'show', revision + ':' + str(path)], repo) for path in FILES}
    # Do not silently pair a modified driver with an older tracked experiment.
    if snapshot[str(EXPERIMENT / 'replay.py')] != Path(__file__).read_bytes():
        raise SystemExit('replay.py differs from the selected revision; use its tracked driver')
    compilers = []
    for command in args.compilers:
        executable = shutil.which(command)
        if not executable:
            raise SystemExit('compiler unavailable: ' + command)
        version = capture([executable, '--version'], repo).decode()
        family = 'ldc' if 'ldc' in version.lower() else 'dmd' if 'dmd' in version.lower() else None
        if family is None:
            raise SystemExit('unsupported compiler: ' + command)
        compilers.append((str(Path(executable).resolve()), family, version))
    gcc = shutil.which('g++')
    if not gcc or not shutil.which('taskset'):
        raise SystemExit('g++ and taskset are required')
    if args.output:
        output = args.output.expanduser().resolve()
        output.mkdir(parents=True, exist_ok=False)
    else:
        downloads = Path.home() / 'Downloads'
        downloads.mkdir(exist_ok=True)
        output = Path(tempfile.mkdtemp(prefix='color-cvd-xps-', dir=downloads))
    archive = Path(str(output) + '.tar.gz')
    ledger = []
    metadata = {'revision': revision, 'cpu': args.cpu, 'sizes': args.sizes,
                'blocks': args.blocks, 'variants': args.variants, 'notes': args.notes,
                'compilers': [{'executable': x, 'family': f, 'version': v} for x, f, v in compilers],
                'gcc_version': capture([gcc, '--version'], repo).decode(),
                'uname': os.uname()._asdict() if hasattr(os.uname(), '_asdict') else list(os.uname()),
                'controls': 'CPU affinity applied; frequency/turbo/SMT/thermals observed, not changed',
                'observations': [observe(args.cpu)], 'status': 'running'}

    def save():
        (output / 'metadata.json').write_text(json.dumps(metadata, indent=2))
        (output / 'commands.json').write_text(json.dumps(ledger, indent=2))

    def run(argv, cwd, destination):
        destination.parent.mkdir(parents=True, exist_ok=True)
        entry = {'argv': [str(x) for x in argv], 'cwd': str(cwd),
                 'stdout': str(destination.relative_to(output)), 'start_ns': time.time_ns()}
        ledger.append(entry)
        with destination.open('wb') as stdout, Path(str(destination) + '.stderr').open('wb') as stderr:
            process = subprocess.run(entry['argv'], cwd=cwd, stdout=stdout, stderr=stderr)
        entry.update(end_ns=time.time_ns(), returncode=process.returncode)
        save()
        if process.returncode:
            raise RuntimeError(f'command failed ({process.returncode}): {argv[0]}; see {destination}')

    try:
        source = output / 'source'
        for path, content in snapshot.items():
            target = source / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
        work = source / EXPERIMENT
        if shutil.which('lscpu'):
            run(['lscpu'], work, output / 'lscpu.txt')
        run([sys.executable, 'prepare.py'], work, output / 'prepare.txt')
        cpp = output / 'cpp-benchmark'
        run([gcc, '-std=c++17', '-O3', '-ffp-contract=off', '-fno-fast-math',
             'reference.cpp', '-o', cpp], work, output / 'build-cpp.txt')
        sources = ['bench.d', 'candidates.d', 'machado_candidates.d', 'bv_policy.d', '_generated/bv.d', '_generated/ma.d']
        binaries = {}
        for ci, (compiler, family, _) in enumerate(compilers):
            build = output / f'compiler-{ci}-{family}'
            build.mkdir()
            version_flag = '-d-version=' if family == 'ldc' else '-version='
            optimize = ['-O3', '-fp-contract=off'] if family == 'ldc' else ['-O', '-inline']
            qualification_sources = ['bv_qualification.d', 'candidates.d', 'bv_policy.d', '_generated/bv.d']
            for mode, qualification_flags in [('debug', ['-g']), ('release', [*optimize, '-release'])]:
                qualification = build / ('bv-qualification-' + mode)
                run([compiler, *qualification_flags, '-boundscheck=on',
                     '-of=' + str(qualification), *qualification_sources], work, build / ('build-bv-qualification-' + mode + '.txt'))
                run([qualification], work, build / ('bv-qualification-' + mode + '.txt'))
            preflight = build / 'preflight'
            run([compiler, '-g', '-boundscheck=on', version_flag + 'Preflight',
                 '-of=' + str(preflight), *sources], work, build / 'build-preflight.txt')
            run([preflight, '32'], work, build / 'preflight.txt')
            for variant in args.variants:
                binary = build / ('benchmark-' + variant)
                flags = [] if VARIANTS[variant] is None else [version_flag + VARIANTS[variant]]
                run([compiler, *optimize, *flags, '-release', '-boundscheck=on',
                     '-of=' + str(binary), *sources], work, build / ('build-' + variant + '.txt'))
                binaries[ci, variant] = binary
        # Preserve fixed binaries and hashes before any measurements.
        binary_files = [cpp, *binaries.values()]
        (output / 'binaries.sha256').write_text(''.join(
            hashlib.sha256(path.read_bytes()).hexdigest() + '  ' + str(path.relative_to(output)) + '\n'
            for path in binary_files))
        for block in range(args.blocks):
            metadata['observations'].append(observe(args.cpu))
            compiler_order = list(range(len(compilers)))
            if block % 2:
                compiler_order.reverse()
            variants = args.variants[block % len(args.variants):] + args.variants[:block % len(args.variants)]
            sizes = list(args.sizes) if block % 2 == 0 else list(reversed(args.sizes))
            for ci in compiler_order:
                for n in sizes:
                    print(f'block {block+1}/{args.blocks}, compiler {ci}, n={n}', flush=True)
                    directories = {}
                    for variant in variants:
                        directory = output / f'compiler-{ci}-{compilers[ci][1]}' / f'n-{n}' / f'block-{block}' / variant
                        directory.mkdir(parents=True)
                        directories[variant] = directory
                        shutil.copyfile(work / 'summarize.py', directory / 'summarize.py')
                        for language, binary in [('d', binaries[ci, variant]), ('cpp', cpp)]:
                            run(['taskset', '-c', str(args.cpu), binary, str(n)], work, directory / (language + '-forward.csv'))
                    for variant in reversed(variants):
                        directory = directories[variant]
                        for language, binary in [('cpp', cpp), ('d', binaries[ci, variant])]:
                            run(['taskset', '-c', str(args.cpu), binary, str(n), 'reverse'], work, directory / (language + '-reverse.csv'))
                        run([sys.executable, 'summarize.py'], directory, directory / 'summary.txt')
            metadata['observations'].append(observe(args.cpu))
        with (output / 'pooled-summary.csv').open('w', newline='') as report:
            writer = csv.writer(report)
            writer.writerow(['compiler', 'variant', 'scalar', 'mode', 'deficiency', 'n',
                             'samples_per_language', 'D_min_ns', 'D_median_ns', 'D_max_ns',
                             'CPP_min_ns', 'CPP_median_ns', 'CPP_max_ns', 'D_over_CPP'])
            for ci in range(len(compilers)):
                for n in args.sizes:
                    for variant in args.variants:
                        pooled = defaultdict(list)
                        for block in range(args.blocks):
                            directory = output / f'compiler-{ci}-{compilers[ci][1]}' / f'n-{n}' / f'block-{block}' / variant
                            for name in ('d-forward.csv', 'd-reverse.csv', 'cpp-forward.csv', 'cpp-reverse.csv'):
                                with (directory / name).open() as stream:
                                    for row in csv.reader(stream):
                                        if row and row[0] == 'sample':
                                            pooled[tuple(row[1:5])].append(float(row[8]))
                        if len(pooled) != 56 or any(len(v) != 18*args.blocks for v in pooled.values()):
                            raise RuntimeError('incomplete pooled sample matrix')
                        for key in sorted(k[1:] for k in pooled if k[0] == 'D'):
                            d, c = pooled['D', *key], pooled['CPP', *key]
                            writer.writerow([ci, variant, *key, n, len(d), min(d), statistics.median(d),
                                             max(d), min(c), statistics.median(c), max(c),
                                             statistics.median(d)/statistics.median(c)])
        metadata['status'] = 'passed'
        metadata['interpretation'] = 'Replay checks passed; performance acceptance and independent model qualification remain separate.'
    except BaseException as error:
        metadata['status'] = 'failed'
        metadata['error'] = str(error)
        raise
    finally:
        save()
        files = sorted(path for path in output.rglob('*') if path.is_file())
        (output / 'files.sha256').write_text(''.join(
            hashlib.sha256(path.read_bytes()).hexdigest() + '  ' + str(path.relative_to(output)) + '\n'
            for path in files))
        with tarfile.open(archive, 'x:gz') as bundle:
            bundle.add(output, arcname=output.name)
        print('RESULT_DIRECTORY=' + str(output), flush=True)
        print('RESULT_ARCHIVE=' + str(archive), flush=True)


if __name__ == '__main__':
    main()
