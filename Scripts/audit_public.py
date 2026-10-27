#!/usr/bin/env python3
"""Publication guard. Reports paths/rules only; never echoes matched values."""
import argparse
import ipaddress
import re
import struct
import io
import wave
import zlib
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRIVATE_SUFFIXES = {
    '.pyc', '.pyo', '.pem', '.key', '.p8', '.p12', '.pfx', '.cer', '.mobileprovision',
    '.provisionprofile', '.xcuserstate', '.ipa', '.log', '.crash', '.ips', '.jks', '.keystore',
}
PRIVATE_DIRECTORIES = {
    '.git', '__pycache__', 'xcuserdata', 'deriveddata', '.build', '.swiftpm', 'builds', 'build',
    'takes', 'recordings', 'captures', 'exports', 'private', 'secrets',
}
PATTERNS = {
    'absolute-home-path': re.compile(r'(?:/(?:Users|home)/[^/\s<>]+/|[A-Za-z]:\\Users\\[^\\\s<>]+\\)'),
    'literal-signing-team': re.compile(r'(?:DEVELOPMENT_TEAM\s*=\s*|<key>DEVELOPMENT_TEAM</key>\s*<string>)[A-Z0-9]{10}\b'),
    'device-identifier': re.compile(r'(?i)(?<![a-z0-9])(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|[0-9a-f]{8}-[0-9a-f]{16})(?![a-z0-9])'),
    'private-key': re.compile(r'-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----'),
    'provider-token': re.compile(r'\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}|(?:AKIA|ASIA)[A-Z0-9]{16}|sk-(?:proj-|ant-)?[A-Za-z0-9_-]{20,}|(?:sk|rk)_live_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{20,}|AIza[A-Za-z0-9_-]{35})\b'),
    'credential-in-url': re.compile(r'https?://[^\s/:@]+:[^\s/@]+@'),
    'credential-assignment': re.compile(r'''(?im)["']?(?:api[_-]?key|client[_-]?secret|access[_-]?token|auth[_-]?token|password)["']?\s*[:=]\s*["']([^"'\n]{8,})["']'''),
}
EMAIL = re.compile(r'\b[A-Za-z0-9.!#$%&*+/=?^_`{|}~-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b')
IPV4 = re.compile(r'(?<![\w.])(?:\d{1,3}\.){3}\d{1,3}(?![\w.])')
SAFE_EMAIL_DOMAINS = {'example.com', 'example.org', 'example.net', 'users.noreply.github.com', 'threads.invalid'}


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, stderr=subprocess.DEVNULL)


def safe_email(address):
    return address.lower() == 'noreply@github.com' or address.rsplit('@', 1)[-1].lower() in SAFE_EMAIL_DOMAINS


def placeholder(value):
    return any(marker in value.lower() for marker in ('example', 'placeholder', 'your_', 'your-', '${', '$(', '<', 'changeme', 'replace_me'))


def inspect(path, data):
    findings = []
    parts = Path(path).parts
    name = Path(path).name.lower()
    private = (name in {'localsigning.xcconfig', '.ds_store', 'credentials.json'}
               or name.startswith(('service-account', 'id_rsa', 'id_ed25519'))
               or (name.startswith('.env') and name != '.env.example')
               or Path(path).suffix.lower() in PRIVATE_SUFFIXES
               or any(p.lower() in PRIVATE_DIRECTORIES or p.lower().endswith(('.app', '.xcarchive', '.xcresult', '.dsym', '.trace')) for p in parts)
               or path.lower().startswith('documentation/logs/'))
    if private:
        findings.append((path, 1, 'private-file-category'))
    if data.startswith(b'\x89PNG\r\n\x1a\n'):
        offset = 8
        while offset + 12 <= len(data):
            length = struct.unpack('>I', data[offset:offset + 4])[0]
            kind = data[offset + 4:offset + 8]
            if offset + length + 12 > len(data):
                findings.append((path, 1, 'malformed-png'))
                break
            chunk = data[offset:offset + length + 12]
            if len(chunk) == length + 12 and zlib.crc32(chunk[4:-4]) & 0xffffffff != struct.unpack('>I', chunk[-4:])[0]:
                findings.append((path, 1, 'malformed-png-checksum'))
            if kind in {b'eXIf', b'tEXt', b'zTXt', b'iTXt', b'tIME'}:
                findings.append((path, 1, 'image-metadata-needs-review'))
            offset += length + 12
        return findings
    if data.startswith(b'RIFF') and data[8:12] == b'WAVE':
        offset = 12
        while offset + 8 <= len(data):
            kind = data[offset:offset + 4]
            length = struct.unpack('<I', data[offset + 4:offset + 8])[0]
            if offset + 8 + length > len(data):
                findings.append((path, 1, 'malformed-audio'))
                break
            if kind not in {b'fmt ', b'data'}:
                findings.append((path, 1, 'audio-metadata-needs-review'))
            offset += 8 + length + (length % 2)
        try:
            with wave.open(io.BytesIO(data)) as audio:
                if audio.getnchannels() != 2 or audio.getsampwidth() != 2 or audio.getframerate() != 48000:
                    findings.append((path, 1, 'unexpected-audio-format'))
        except (wave.Error, EOFError):
            findings.append((path, 1, 'malformed-audio'))
        return findings
    try:
        text = data.decode('utf-8')
    except UnicodeDecodeError:
        findings.append((path, 1, 'unreviewed-binary'))
        return findings
    for rule, pattern in PATTERNS.items():
        for match in pattern.finditer(text):
            if rule == 'credential-assignment' and placeholder(match.group(1)):
                continue
            findings.append((path, text.count('\n', 0, match.start()) + 1, rule))
    for match in EMAIL.finditer(text):
        if not safe_email(match.group()):
            findings.append((path, text.count('\n', 0, match.start()) + 1, 'email-needs-review'))
    for match in IPV4.finditer(text):
        try:
            address = ipaddress.ip_address(match.group())
        except ValueError:
            continue
        if address.is_private or address.is_loopback:
            findings.append((path, text.count('\n', 0, match.start()) + 1, 'private-network-address'))
    return findings


def inspect_history():
    findings = []
    for record in git('log', '--all', '--format=%H%x09%ae%x09%ce%x09%an%x09%cn').decode().splitlines():
        sha, author, committer, author_name, committer_name = record.split('\t')
        for name in (author_name, committer_name):
            if name != 'THREADS Contributors' and not re.fullmatch(r'[A-Za-z0-9_.\-\[\]]+', name):
                findings.append(('commit ' + sha[:12], 1, 'commit-name-needs-review'))
        if not safe_email(author) or not safe_email(committer):
            findings.append(('commit ' + sha[:12], 1, 'commit-email-needs-review'))
    objects = {}
    for record in git('rev-list', '--objects', '--all').decode().splitlines():
        if ' ' in record:
            sha, path = record.split(' ', 1)
            objects[sha] = path
    if not objects:
        return findings
    # Batch mode checks historical bytes, including files removed in later commits.
    result = subprocess.check_output(['git', 'cat-file', '--batch'], cwd=ROOT,
                                     input=''.join(sha + '\n' for sha in objects).encode())
    offset = 0
    for path in objects.values():
        end = result.index(b'\n', offset)
        sha, kind, size = result[offset:end].split()
        offset = end + 1
        data = result[offset:offset + int(size)]
        offset += int(size) + 1
        if kind == b'blob':
            findings.extend((f'history/{sha.decode()[:12]}/{p}', line, rule) for p, line, rule in inspect(path, data))
    return findings


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--staged', action='store_true', help='Read exactly the Git index, including partially staged files.')
    mode.add_argument('--tree', type=Path, help='Inspect every file in an unpacked source archive.')
    parser.add_argument('--history', action='store_true', help='Also inspect historical blobs and author/committer email privacy.')
    args = parser.parse_args()
    findings, count = [], 0
    if args.tree:
        entries = []
        for p in sorted(args.tree.rglob('*')):
            if p.is_symlink():
                findings.append((p.relative_to(args.tree).as_posix(), 1, 'symlink-needs-review'))
            elif p.is_file():
                entries.append((p.relative_to(args.tree).as_posix(), p.read_bytes()))
    else:
        try:
            paths = git('ls-files', '-z').decode().split('\0')
            entries = []
            for path in filter(None, paths):
                if args.staged:
                    data = git('show', ':' + path)
                else:
                    p = ROOT / path
                    if p.is_symlink():
                        findings.append((path, 1, 'symlink-needs-review'))
                        continue
                    if not p.is_file():
                        findings.append((path, 1, 'tracked-file-missing'))
                        continue
                    data = p.read_bytes()
                entries.append((path, data))
        except (subprocess.CalledProcessError, FileNotFoundError):
            parser.error('Run inside the Git checkout, or use --tree on a source archive.')
    for path, data in entries:
        count += 1
        findings.extend(inspect(path, data))
    if not count:
        parser.error('No files found; refusing an empty audit.')
    if args.history:
        try:
            findings.extend(inspect_history())
        except subprocess.CalledProcessError:
            parser.error('History inspection requires a Git checkout with commits.')
    for path, line, rule in sorted(set(findings)):
        print(f'{path}:{line}: {rule}')
    print(f'Publication guard: {count} files; {len(set(findings))} findings.')
    return bool(findings)


if __name__ == '__main__':
    raise SystemExit(main())
