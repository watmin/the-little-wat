#!/usr/bin/env bash
# audit.sh — NEXT.md §8. Point this at a wat-rs build and read what changed.
#
# This repository holds 340 runnable programs and ~150 findings. Most of that is a snapshot: it
# says what was true of one commit. The tools below are the part that keeps paying — each one is a
# reproducible MEASUREMENT rather than a one-shot investigation, so running them against a new
# build tells you what your fixes did.
#
#   tools/recheck.sh          per-finding: OPEN / FIXED / ?   <- the signal
#   tools/doc-names-audit.sh  every :wat:: verb the docs teach, checked against the compiler
#   tools/cli-surface.sh      the binary's modes, and which are documented
#   tools/bench.sh            the performance baseline (BASELINE.md)
#
# Usage: ./audit.sh [path-to-wat-rs] [--full]
#   --full also runs the slow ones: fix-roundtrip over probes/, and the bracket OS oracle.
set -uo pipefail
RS="${1:-../wat-rs}"; FULL="${2:-}"
[ -x "$RS/target/release/wat" ] || { echo "no wat binary at $RS/target/release/wat"; exit 2; }
rev=$(git -C "$RS" rev-parse --short HEAD 2>/dev/null || echo unknown)

echo "# wat audit — $(date -u +%Y-%m-%dT%H:%MZ)"
echo "# wat-rs: $rev"
echo
echo "## Findings status"
echo
./tools/recheck.sh "$RS" | sed 's/^/  /'
echo
echo "## Documentation"
echo
./tools/doc-names-audit.sh "$RS" 2>/dev/null | sed 's/^/  /'
echo
echo "## CLI surface"
echo
./tools/cli-surface.sh "$RS" 2>/dev/null | sed 's/^/  /'
echo
echo "## Performance"
echo
./tools/bench.sh "$RS" 3 2>/dev/null | sed 's/^/  /'

if [ "$FULL" = "--full" ]; then
  echo
  echo "## Codemod round-trip (slow)"
  echo
  ./tools/fix-roundtrip.sh "$RS" probes/*.wat 2>/dev/null | tail -3 | sed 's/^/  /'
  echo
  echo "## Parallelism ceiling (slow)"
  echo
  ./tools/bracket-os-oracle.sh "$RS" 16 2>/dev/null | sed 's/^/  /'
fi

echo
echo "# Read tools/recheck.sh's FIXED lines first: those are findings to close."
