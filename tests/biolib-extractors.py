"""Known-output fixtures for the exact published Bio.cs clients (Windows).

Only generated data is extracted; no installer or extracted payload is executed.
Python 3 standard library only. See docs/BIOLIB-FIXTURES.md for coverage limits.
"""
import argparse
import hashlib
import io
import json
import lzma
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import zipfile
import zlib


def pack(fmt, *values):
    return struct.pack('<' + fmt, *values)


PAYLOAD = b'UniExtract2 fixture\r\n' + bytes(range(256))


def pck(files, base=0):
    names = [('res://' + name).encode('utf-8') for name in files]
    offset = base + 88 + sum(36 + len(name) for name in names)
    index = b''
    for name, data in zip(names, files.values()):
        index += pack('I', len(name)) + name + pack('QQ', offset, len(data))
        index += hashlib.md5(data).digest()
        offset += len(data)
    return b'GDPC' + pack('4I', 1, 3, 2, 0) + bytes(64) + pack('I', len(files)) + index + b''.join(files.values())


def sgb(files, current):
    file_key = bytes([0, 14, 8, 30, 24, 55, 18, 0, 72, 135, 70, 11, 156, 104, 168, 75])
    archive_key = bytes([72, 9, 20, 154, 48, 169, 84, 225, 0, 8, 14, 9, 20, 60, 66, 70])
    output = io.BytesIO()
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for name, data in files.items():
            if current:
                data = bytes((b + file_key[i % 16]) % 256 for i, b in enumerate(data))
            entry = zipfile.ZipInfo(name, (2020, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry, data)
    data = output.getvalue()
    if current:
        data = bytes((b + archive_key[(i + 8) % 16]) % 256 for i, b in enumerate(data))
    return (b'SGBDAT\x00\x01' if current else b'YUKARPKG') + data[8:]


def lzma_block(data):
    block = lzma.compress(data, format=lzma.FORMAT_ALONE, filters=[
        {'id': lzma.FILTER_LZMA1, 'dict_size': 8388608, 'lc': 3, 'lp': 0, 'pb': 2}])
    return block[:5] + pack('Q', len(data)) + block[13:]


def cabinet(name, data):
    # One folder, one uncompressed CFDATA block, one CFFILE; no checksum.
    entry = pack('IIHHHH', len(data), 0, 0, 0x5021, 0, 0x20) + name.encode('ascii') + b'\0'
    data_offset = 44 + len(entry)
    size = data_offset + 8 + len(data)
    header = b'MSCF' + pack('5I', 0, size, 0, 44, 0) + pack('BB5H', 3, 1, 1, 1, 0, 0, 0)
    return header + pack('IHH', data_offset, 1, 0) + entry + pack('IHH', 0, len(data), len(data)) + data


def sim():
    config = b'UniExtract2 synthetic SIM'.ljust(28, b' ') + b'\0note.txt\x00\x32\x00\x31\x00X'
    runtime = cabinet('$inst\\15.tmp', b'Synthetic license\r\n')[4:]
    data = cabinet('0', PAYLOAD)[4:]
    trailer = pack('4QHh', 0, len(runtime), len(config), len(config) + len(runtime), 0, -3720)
    return config + runtime + data + trailer, {
        '_runtime/installer.config': config, '_runtime/license.rtf': b'Synthetic license\r\n', 'note.txt': PAYLOAD}


def cic(compressed):
    content = zlib.compress(PAYLOAD) if compressed else PAYLOAD
    method = 1 if compressed else 0
    filename = b'nested\\note.txt\0'
    node = pack('IH', 56 + len(filename), 0) + bytes(14)
    node += pack('III', len(PAYLOAD), 0, len(content) + 12)
    node += pack('3Q', *([132223104000000000] * 3)) + filename
    listing = pack('I', 1) + node
    block = pack('I', len(listing)) + b'\0' + listing
    # The scanner examines another block only when at least 64 bytes remain.
    file_data = bytes(4) + bytes([method]) + content
    return b'wwgT)H' + pack('HHI', 0x143a, 0, len(block)) + block + pack('HHI', 0x7f7f, 0, len(file_data)) + file_data


def fixtures():
    files = {'nested/note.txt': PAYLOAD, 'empty.bin': b''}
    yield 'godot-pck', 'godotdec', pck(files), files, [], False
    unicode_files = {'nested/日本語.txt': PAYLOAD, 'empty.bin': b''}
    yield 'godot-unicode', 'godotdec', pck(unicode_files), unicode_files, [], False
    prefix = b'Synthetic inert stub'.ljust(128, b'!')
    package = pck(files, len(prefix))
    yield 'godot-embedded', 'godotdec', prefix + package + pack('Q', len(package)) + b'GDPC', files, [], False
    audio = b'OggS' + PAYLOAD
    yield 'godot-convert', 'godotdec', pck({'audio.oggstr': bytes(279) + audio + bytes(4)}), {'audio.ogg': audio}, ['-c'], False
    yield 'sgb-legacy', 'sgbdec', sgb(files, False), files, [], False
    yield 'sgb-current', 'sgbdec', sgb(files, True), files, [], False
    script = b'[CopyFile]\r\n<Destination>\\nested\\note.txt\r\n'
    spoon_files = {'#SetupImage.bmp': b'BMfixture', '#License.txt': b'Synthetic license',
                   'nested/note.txt': PAYLOAD, '#InstallerScript.ini': script}
    yield 'spoon-lzma', 'spoondec', b''.join(lzma_block(x) for x in spoon_files.values()), spoon_files, [], False
    data, expected = sim()
    yield 'sim-cab', 'simdec', data, expected, [], False
    for compressed in (False, True):
        yield 'cic-' + ('deflate' if compressed else 'stored'), 'cicdec', cic(compressed), {'nested/note.txt': PAYLOAD}, ['-v', '20'], False
    key = bytes(range(16))
    encrypted = bytes(a ^ b for a, b in zip(PAYLOAD[:16], key)) + PAYLOAD[16:]
    yield 'rmv-key', 'rmvdec', b'RPGMV' + bytes(11) + encrypted, {'input.png': PAYLOAD}, ['-k', key.hex()], False
    for client in ('cicdec', 'godotdec', 'rmvdec', 'sgbdec', 'simdec', 'spoondec'):
        yield client + '-invalid', client, b'Invalid archive fixture'.ljust(128, b'!'), {}, [], True


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def snapshot(directory):
    return {p.relative_to(directory).as_posix(): digest(p) for p in sorted(directory.rglob('*')) if p.is_file()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bin', required=True, type=Path)
    parser.add_argument('--candidate', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--godot-candidate', type=Path, help='Test repaired executable with both Bio.cs versions')
    mode.add_argument('--expect-godot-corruption', action='store_true', help='Negative control: require exact shipped Godot corruption')
    args = parser.parse_args()
    pins = json.loads(Path(__file__).with_name('biolib-client-pins.json').read_text())
    for name, sha in pins.items():
        if digest(args.bin / name) != sha:
            raise RuntimeError('Unexpected published binary: ' + name)
    args.output.mkdir(parents=True, exist_ok=True)
    root = Path(tempfile.mkdtemp(prefix='extractors 日本 & ', dir=args.output.resolve()))
    results = []
    errors = []
    for variant, dll in [('baseline', args.bin / 'Bio.cs.dll'), ('candidate', args.candidate)]:
        runtime = root / variant / 'bin'
        runtime.mkdir(parents=True)
        for name in pins:
            shutil.copy2(dll if name == 'Bio.cs.dll' else args.bin / name, runtime / name)
        if args.godot_candidate:
            shutil.copy2(args.godot_candidate, runtime / 'godotdec.exe')
        for name, client, data, expected, options, failure in fixtures():
            case = root / variant / name
            case.mkdir()
            input_path = case / ('input.rpgmvp' if client == 'rmvdec' else 'input.bin')
            input_path.write_bytes(data)
            output = case / 'out'
            if client == 'rmvdec':
                # This helper expects a directory to preserve relative output paths.
                inputs = case / 'inputs'
                inputs.mkdir()
                input_path.rename(inputs / input_path.name)
                input_path = inputs
            command = [str(runtime / (client + '.exe'))]
            command += options if client == 'cicdec' else []
            command += [str(input_path), str(output)]
            command += options if client != 'cicdec' else []
            try:
                run = subprocess.run(command, cwd=case, input=b'', stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                     timeout=20, creationflags=subprocess.CREATE_NO_WINDOW)
                (case / 'stdout.txt').write_bytes(run.stdout)
                (case / 'stderr.txt').write_bytes(run.stderr)
                actual = snapshot(output)
                expected_hashes = {p: hashlib.sha256(b).hexdigest() for p, b in expected.items()}
                valid = actual == expected_hashes and ((run.returncode != 0) if failure else (run.returncode == 0))
                correct = valid
                known_corruption = args.expect_godot_corruption and client == 'godotdec' and not failure
                if known_corruption:
                    # This is a negative control, never a successful extraction.
                    corrupt = {p: hashlib.sha256(data[:len(b)]).hexdigest() for p, b in expected.items()}
                    valid = not correct and actual == corrupt and run.returncode == 0
                result = dict(variant=variant, case=name, exit_code=run.returncode, files=actual, passed=valid,
                              correct=correct, expected_corruption=known_corruption,
                              fixture_sha256=hashlib.sha256(data).hexdigest())
            except subprocess.TimeoutExpired:
                result = dict(variant=variant, case=name, passed=False, error='20 second timeout')
            results.append(result)
            if not result['passed']:
                errors.append(variant + '/' + name)
            status = 'EXPECTED CORRUPTION' if result.get('expected_corruption') and result['passed'] else ('PASS' if result['passed'] else 'FAIL')
            print(variant, name, status, flush=True)
    count = len(results) // 2
    for base, candidate in zip(results[:count], results[count:]):
        if (base.get('exit_code'), base.get('files')) != (candidate.get('exit_code'), candidate.get('files')):
            errors.append('differential/' + base['case'])
    report = dict(baseline_sha256=pins['Bio.cs.dll'], candidate_sha256=digest(args.candidate),
                  godot_sha256=digest(args.godot_candidate or args.bin / 'godotdec.exe'),
                  negative_control=args.expect_godot_corruption,
                  evidence_directory=str(root), results=results, errors=errors, passed=not errors)
    (args.output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
    if errors:
        raise SystemExit('Failed: ' + ', '.join(errors))
    print('All', len(results), 'assertions and differential checks passed;',
          'shipped Godot corruption reproduced.' if args.expect_godot_corruption else 'all extraction outputs correct.')


if __name__ == '__main__':
    main()
