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
echo "== 3. loop-carried allocation, which scope cannot touch =="
echo "  Every intermediate vector is the next call's argument, so all n are live at once."
echo "  Scope cannot free them; last-use plus a share count lets conj EXTEND IN PLACE instead."
for n in 20000 200000 2000000; do
  got=$(./elf/out/grow$n.elf 2>&1)
  [ "$got" = "$n" ] || { echo "  FAIL: grow$n printed '$got'"; fail=1; }
  printf '  grow %-8s %7s KiB   (%s bytes/element)\n' "$n" "$(./$RSS ./elf/out/grow$n.elf)" \
         "$(( ($(./$RSS ./elf/out/grow$n.elf) - 900) * 1024 / n ))"
done
echo "  Before the in-place path this was 4n^2: 63,548 KiB at n=4000 and heap exhaustion at 8000."

echo
echo "== 4. does it free at all? 650 MB allocated against a 64 MiB heap =="
got=$(./elf/out/freed.elf 2>&1 | tr '\n' ' ')
want="65536 100 6553700 65536 "
if [ "$got" = "$want" ]; then
  printf '  yes: completed, peak %s KiB -- about ONE round of 6.5 MB, not the 650 MB total\n' \
         "$(./$RSS ./elf/out/freed.elf)"
  echo "  (compile the statement release out and the same program stops after the first line"
  echo "   with 'wat: heap exhausted', exit 70)"
else
  echo "  FAIL: freed.elf printed '$got'"; fail=1
fi

echo
echo "== 5. the accumulators that used to be quadratic =="
for n in 32000; do
  printf '  concat x%-7s %7s KiB   -> %s   (was: heap exhausted at 8000)\n' "$n" \
         "$(./$RSS ./elf/out/cat$n.elf)" "$(./elf/out/cat$n.elf 2>&1)"
done

echo
echo "== 6. and the two proofs the in-place path needs =="
i=$("$WAT" elf/src/linear.wat 2>&1); n=$(./elf/out/linear.elf 2>&1)
if [ "$i" = "$n" ]; then
  echo "  linear.wat agrees. It fails loudly without EITHER half: drop the share increment and"
  echo "  base comes back with 4 elements instead of 3 ('99 4 5 4' rather than '99 3 102 3')."
else
  echo "  FAIL: linear.wat differs"; diff <(printf '%s\n' "$i") <(printf '%s\n' "$n"); fail=1
fi

echo
echo "== 7. what escapes a statement but not a CALL: the caller-side release =="
# escape.wat is the gap isolated: (user/len s) is an OPERAND of +, never a discarded non-final
# form, and inside user/len the concat is the FINAL form -- so C-120's statement release cannot
# reach either one. What reaches it is the release at the CALL: user/len's declared return type
# is i64, so nothing it allocated can come back, and the caller marks r15 before the arguments
# and restores it after the return. Measured at n = 1e6/2e6/3e6 the peak was 62.4/123.8/184.7 MB
# -- 63.8 bytes per iteration, LINEAR -- and is now flat at about 0.94 MB for all three.
i=$("$WAT" elf/src/escape.wat 2>&1); irc=$?
n=$(./elf/out/escape.elf 2>&1);      nrc=$?
if [ "$i" = "$n" ] && [ $irc -eq $nrc ]; then
  printf '  escape  %7s KiB   -> %s   (was 13768 KiB before the caller-side release)\n' \
         "$(./$RSS ./elf/out/escape.elf)" "$n"
  echo "  It is FLAT in n: 960 KiB at 1e6, 964 at 2e6, 972 at 3e6 -- the whole growth is gone."
else
  echo "  FAIL: escape.wat differs"; diff <(printf '%s\n' "$i") <(printf '%s\n' "$n"); fail=1
fi

echo
[ $fail -eq 0 ] && echo "mem: ok" || echo "mem: FAILED"
exit $fail
