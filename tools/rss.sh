#!/usr/bin/env bash
# What a wat program COMMITS, against what it reserves (F-185).
#
# The heap is one 1.9 GB MAP_ANONYMOUS|MAP_PRIVATE mapping, which is lazily committed --
# so the reservation is not the cost and never was. The cost is that nothing is ever
# reclaimed: RSS tracks every allocation the program has EVER made, not its live set.
#
# The load-bearing pair is optm/optmh: the SAME loop with the same answer, where only the
# enum tier differs. optm allocates nothing, optmh allocates once per iteration. The gap
# between them is pure garbage, and it is the measurement this script exists for.
set -u
cd "$(dirname "$0")/.."
M=elf/out/.maxrss
[ -x $M ] && [ $M -nt tools/maxrss.c ] || gcc -O2 -o $M tools/maxrss.c || exit 1
RES=1900000000
printf '%-22s %12s %10s %9s\n' program 'peak RSS' MB 'of resv'
for p in "${@:-four optm optmh grow2000000 vecsum strbuild scanfast deep}"; do
  for q in $p; do
    [ -x "elf/out/$q.elf" ] || { printf '%-22s %12s\n' "$q.elf" "(not built)"; continue; }
    r=$($M timeout -s KILL 300 "./elf/out/$q.elf" 2>&1 >/dev/null | tail -1)
    case $r in ''|*[!0-9]*) printf '%-22s %12s\n' "$q.elf" "(no reading)"; continue;; esac
    awk -v n="$q.elf" -v r="$r" -v res=$RES \
      'BEGIN{printf "%-22s %12s %10.1f %8.2f%%\n", n, r, r/1024, (r*1024)/res*100}'
  done
done
