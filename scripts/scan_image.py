#!/usr/bin/env python3
"""
Scan a Jetson golden image for secrets before it is published.

Streams the raw (or gzipped) image once and looks for credentials that must
never leave the machine that built the card. Values are NEVER printed — only
their kind, length, and where the evidence sits.

Exit codes:  0 = clean   1 = findings that block publishing   2 = usage error

Why this exists: a golden image is a byte-for-byte copy of a real, used
system. Anything that was on the source card ships to every person who
flashes it, and a public release cannot be recalled.
"""
import argparse, re, sys, subprocess, collections

WINDOW = 4096          # bytes of context kept around a hit
CHUNK  = 8 << 20

# A binary that merely *mentions* "BEGIN RSA PRIVATE KEY" is not a leak; the
# string is compiled into openssh, libnm, openssl. A real key has a long
# base64 body right after the header. Same idea throughout: match structure,
# not just a keyword.
B64 = re.compile(rb'[A-Za-z0-9+/=\s]{200,}')

# Markers that identify upstream documentation and unit-test fixtures. These
# ship inside Ubuntu/PyPI packages, are public already, and are not the
# builder's secrets. Without this filter the scanner blocks on wpa_supplicant's
# own man-page examples and PyCryptodome's test suite, and gets ignored.
DOC_MARKERS = (b'%s', b'%02x', b'usage:', b'Example', b'example',
               b'unittest', b'TestCase', b'_testData', b'generated with openssl',
               b'Generated with openssl', b'man page', b'/* ', b'#include')

def _is_doc(near):
    return any(m in near for m in DOC_MARKERS)

def real_private_key(ctx, pos):
    """A real key file: base64 body right after the header, no test-suite
    scaffolding around it. Binaries merely *mention* the header string."""
    near = ctx[max(0, pos - 500): pos + 200]
    if _is_doc(near):
        return False
    tail = ctx[pos:pos + 400]
    nl = tail.find(b'\n')
    return nl != -1 and bool(B64.match(tail[nl + 1:]))

def real_wifi_psk(ctx, pos):
    """NetworkManager keyfiles carry [wifi-security] + key-mgmt=.
    wpa_supplicant.conf wraps psk= in an uncommented network={ block.
    Both shapes also appear verbatim in shipped documentation, hence _is_doc."""
    near = ctx[max(0, pos - 2048): pos + 2048]
    if _is_doc(near):
        return False
    line_start = ctx.rfind(b'\n', 0, pos) + 1
    if ctx[line_start:pos].lstrip().startswith(b'#'):   # commented-out example
        return False
    value = ctx[pos + 4:pos + 200].split(b'\n')[0].strip().strip(b'"')
    plausible = (8 <= len(value) <= 63) or re.fullmatch(rb'[0-9a-fA-F]{64}', value)
    if not plausible:
        return False
    return (b'[wifi-security]' in near and b'key-mgmt=' in near) or \
           (b'network={' in near and b'ssid=' in near)

def real_aws(ctx, pos):
    near = ctx[max(0, pos - 400): pos + 400]
    if _is_doc(near):
        return False
    return b'secret_access_key' in near.lower() or b'aws_secret' in near.lower()

CHECKS = [
    # (name, needle, severity, structural validator or None)
    ('wifi-psk',        b'psk=',                        'BLOCK', real_wifi_psk),
    ('ssh-private-key', b'BEGIN OPENSSH PRIVATE KEY',   'BLOCK', real_private_key),
    ('rsa-private-key', b'BEGIN RSA PRIVATE KEY',       'BLOCK', real_private_key),
    ('ec-private-key',  b'BEGIN EC PRIVATE KEY',        'BLOCK', real_private_key),
    ('dsa-private-key', b'BEGIN DSA PRIVATE KEY',       'BLOCK', real_private_key),
    ('pgp-private-key', b'BEGIN PGP PRIVATE',           'BLOCK', real_private_key),
    ('aws-key',         b'AKIA',                        'BLOCK', real_aws),
    ('netrc',           b'\nmachine ',                  'WARN',  None),
    ('shadow-hash',     b'\njetson:$',                  'WARN',  None),
    ('shadow-hash',     b'\nroot:$',                    'WARN',  None),
    ('bash-history',    b'.bash_history',               'INFO',  None),
    ('authorized-keys', b'authorized_keys',             'INFO',  None),
]

SECRET_VALUE = re.compile(
    rb'(?<=psk=)[!-~]{1,200}|'
    rb'(?<=PRIVATE KEY-----\n)[A-Za-z0-9+/=\s]{40,}|'
    rb'AKIA[0-9A-Z]{16}')

def redact(blob, name):
    """Printable context with the secret itself replaced by its length."""
    blob = SECRET_VALUE.sub(lambda m: b'<REDACTED %d chars>' % len(m.group()), blob)
    return ''.join(chr(b) if 32 <= b < 127 or b == 10 else '.' for b in blob)

def open_stream(path):
    if path == '-':
        return None, sys.stdin.buffer
    if path.endswith(('.gz', '.tgz')):
        prog = 'pigz' if _has('pigz') else 'gzip'
        p = subprocess.Popen([prog, '-dc', path], stdout=subprocess.PIPE)
        return p, p.stdout
    return None, open(path, 'rb')

def _has(prog):
    return subprocess.call(['which', prog], stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL) == 0

def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('image', help='image file (.img or .img.gz), or - for stdin')
    ap.add_argument('--report', help='write findings to this file')
    ap.add_argument('--context', metavar='FILE',
                    help='write redacted surrounding text for each blocking hit, '
                         'so a human can tell an upstream test fixture from a real secret')
    args = ap.parse_args()
    ctxf = open(args.context, 'w') if args.context else None

    proc, stream = open_stream(args.image)
    findings = collections.defaultdict(lambda: {'real': 0, 'filtered': 0, 'lens': []})
    overlap = max(len(n) for _, n, _, _ in CHECKS) + 2 * WINDOW
    buf, scanned, base = b'', 0, 0
    # Absolute offset past which each check has already accounted for hits.
    # Without this, every hit inside the retained tail would be counted again
    # on the next chunk.
    seen_upto = collections.defaultdict(int)

    while True:
        chunk = stream.read(CHUNK)
        last = not chunk
        if chunk:
            scanned += len(chunk)
            buf += chunk
        for name, needle, sev, validator in CHECKS:
            start = 0
            while True:
                i = buf.find(needle, start)
                if i < 0:
                    break
                start = i + 1
                # Defer a hit too close to the end to judge: the next chunk
                # gives the validator its full trailing context.
                if not last and i > len(buf) - WINDOW:
                    break
                abs_pos = base + i
                if abs_pos < seen_upto[name]:
                    continue
                seen_upto[name] = abs_pos + 1
                f = findings[(name, sev)]
                if validator and not validator(buf, i):
                    f['filtered'] += 1
                    continue
                f['real'] += 1
                if name == 'wifi-psk':
                    v = buf[i + 4:i + 200].split(b'\n')[0].strip()
                    f['lens'].append(len(v))
                if ctxf and sev == 'BLOCK' and f['real'] <= 12:
                    ctxf.write(f'=== {name} #{f["real"]} @ {abs_pos} ===\n')
                    ctxf.write(redact(buf[max(0, i - 260):i + 320], name) + '\n\n')
                    ctxf.flush()
        if last:
            break
        keep = min(overlap, len(buf))
        base += len(buf) - keep
        buf = buf[-keep:]
        print(f'\r    scanned {scanned / 2**30:.1f} GiB', end='', file=sys.stderr, flush=True)

    print('', file=sys.stderr)
    if ctxf:
        ctxf.close()
        print(f'    context written to {args.context}', file=sys.stderr)
    if proc:
        proc.stdout.close(); proc.wait()

    lines, blocking = [], 0
    for sev in ('BLOCK', 'WARN', 'INFO'):
        for (name, s), f in sorted(findings.items()):
            if s != sev or (f['real'] == 0 and f['filtered'] == 0):
                continue
            if f['real'] == 0:
                lines.append(f'  ok    {name:<18} 0 real  ({f["filtered"]} binary-string false positives filtered)')
                continue
            if sev == 'BLOCK':
                blocking += f['real']
            tag = {'BLOCK': 'BLOCK', 'WARN': 'warn ', 'INFO': 'info '}[sev]
            extra = f'  value lengths: {sorted(f["lens"])}' if f['lens'] else ''
            lines.append(f'  {tag} {name:<18} {f["real"]} real, {f["filtered"]} filtered{extra}')

    report = '\n'.join(lines) if lines else '  nothing matched'
    print(report)
    sys.stdout.flush()
    if args.report:
        with open(args.report, 'w') as fh:
            fh.write(f'image: {args.image}\nscanned: {scanned} bytes\n{report}\n')
            fh.write(f'result: {"BLOCKED" if blocking else "CLEAN"}\n')

    if blocking:
        print(f'\nFAIL — {blocking} credential(s) found. Do NOT publish this image.', file=sys.stderr)
        print('Run scripts/shrink-image.sh --prepare on the Jetson, reclone, and rescan.', file=sys.stderr)
        return 1
    print('\nPASS — no credentials detected. Values are never printed by this tool.')
    return 0

if __name__ == '__main__':
    sys.exit(main())
