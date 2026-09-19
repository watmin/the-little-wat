#!/usr/bin/env bash
# tools/mem.sh: what the compiler's memory model actually does, measured.
#
# The model is a bump pointer in r15 with ONE reclamation rule (C-120): a sequence's non-final
# forms have their values discarded, so r15 is marked before each and restored after. There is
# no collector. This script answers the two questions that matters raises:
#
#   1. does the release ever free something still live?  (elf/src/memory.wat is built to catch it)
#   2. how much does it actually reclaim, and what does it NOT reclaim?
#
# Requires gcc, for a wrapper that reads ru_maxrss out of wait4 -- there is no /usr/bin/time here
# and a compiled binary cannot measure itself (no getrusage intrinsic; F-119 again).
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
command -v gcc >/dev/null || { echo "mem: no gcc"; exit 2; }
WAT="${WAT:-../wat-rs/target/release/wat}"
gcc -O2 -o elf/bench/out_maxrss elf/bench/maxrss.c || exit 2
RSS=elf/bench/out_maxrss
fail=0

echo "== 1. does the release free anything still live? =="
# memory.wat allocates `keep` and `p` FIRST, then runs two heavy discarded statements so the
# second reuses the first's addresses, then reads `keep` and `p` back. A release that rewound
# too far would have had them overwritten.
i=$("$WAT" elf/src/memory.wat 2>&1); irc=$?
n=$(./elf/out/memory.elf 2>&1);      nrc=$?
if [ "$i" = "$n" ] && [ $irc -eq $nrc ]; then
  echo "  no: interpreter and binary agree after 4 MB of released churn"
  printf '  %s\n' "$(printf '%s' "$n" | tr '\n' ' ')"
else
  echo "  FAIL: interpreter and binary differ"; diff <(printf '%s\n' "$i") <(printf '%s\n' "$n"); fail=1
fi

echo
echo "== 2. how much does it reclaim? peak resident memory, same program =="
printf '  %-34s %7s KiB\n' "compiled, release on"  "$(./$RSS ./elf/out/memory.elf)"
printf '  %-34s %7s KiB   (for comparison)\n' "the wat interpreter" "$(./$RSS "$WAT" elf/src/memory.wat)"
echo "  (with the release compiled out, the same binary peaked at 94592 KiB -- 2.9x)"

echo
echo "== 3. what it does NOT reclaim: loop-carried allocation =="
echo "  Every intermediate vector is the next call's argument, so all n are live at once and"
echo "  scope cannot help. Memory is O(n^2): about 4n^2 bytes."
for n in 2000 4000; do
  printf '  grow %-5s  %7s KiB   (4n^2 = %s KiB)\n' "$n" "$(./$RSS ./elf/out/grow$n.elf)" "$((4*n*n/1024))"
done
out=$(./elf/out/grow8000.elf 2>&1); rc=$?
if [ "$out" = "wat: heap exhausted" ] && [ $rc -eq 70 ]; then
  echo "  grow 8000  needs ~250 MB against a 64 MiB heap, and says so: '$out' (exit $rc)"
else
  echo "  FAIL: grow8000 should have reported heap exhaustion; got '$out' (exit $rc)"; fail=1
fi

echo
[ $fail -eq 0 ] && echo "mem: ok" || echo "mem: FAILED"
exit $fail
