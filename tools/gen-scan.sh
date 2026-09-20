#!/usr/bin/env bash
# tools/gen-scan.sh: the fixture elf/bench/scan.wat and scan.c both read.
#
# Generated rather than committed: 194 KB of pseudo-random words is data, not source, and a
# repository that keeps its own code should not carry a blob it can rebuild. The seed is fixed,
# so the file is byte-identical on every machine and both benchmarks count the same 6369 'e's.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
out=elf/out/scan.txt
[ "${1:-}" = "--force" ] || [ ! -f "$out" ] || exit 0
mkdir -p elf/out
python3 - "$out" <<'PY'
import random, sys
random.seed(7)
words = [''.join(random.choice('abcdefghijklmnopqrstuvwxyz')
                 for _ in range(random.randint(2, 9))) for _ in range(30000)]
text = ' '.join(words)
open(sys.argv[1], 'w').write(text)
print(f"gen-scan: {len(text)} bytes, {text.count('e')} occurrences of 'e'", file=sys.stderr)
PY
