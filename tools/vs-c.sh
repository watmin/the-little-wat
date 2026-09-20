#!/usr/bin/env bash
# tools/vs-c.sh: the compiler in elf/ against C, on four axes, with the numbers stated rather
# than claimed.
#
# The opponents are built here, not committed: gcc with glibc (what a C program normally is),
# and gcc with libc REMOVED -- `-nostdlib -nostartfiles`, raw syscalls, its own `_start`. That
# second one is the honest opponent, because it is the same bargain elf/ makes.
#
# Requires gcc. Exit code 0 when everything built and every pair computed the same answer.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
command -v gcc >/dev/null || { echo "vs-c: no gcc"; exit 2; }
WAT="${WAT:-../wat-rs/target/release/wat}"
B=elf/bench
fail=0

echo "== building the opponents (gcc $(gcc -dumpversion)) =="
gcc -O2 -static                 -o $B/out_four_static  $B/four.c      || fail=1
gcc -O2                         -o $B/out_four_dynamic $B/four.c      || fail=1
gcc -O2 -static -nostdlib -nostartfiles -Wl,--build-id=none \
    -Wl,-z,noseparate-code -Wl,-n -o $B/out_four_free  $B/four_free.c || fail=1
strip -s $B/out_four_free 2>/dev/null
gcc -O2 -static -o $B/out_fib_O2 $B/fib.c  || fail=1
gcc -O0 -static -o $B/out_fib_O0 $B/fib.c  || fail=1
gcc -O2 -static -o $B/out_noop   $B/noop.c || fail=1
gcc -O2         -o $B/out_noop_dyn $B/noop.c || fail=1
gcc -O2 -static -o $B/out_spew   $B/spew.c || fail=1
gcc -O2 -static -o $B/out_loopsum $B/loopsum.c || fail=1
gcc -O2 -static -o $B/out_triple  $B/triple.c  || fail=1

sz () { stat -c%s "$1"; }
best () { local n=$1; shift; local b=99999999 s m
          for ((i=0;i<n;i++)); do s=$(date +%s%N); "$@" >/dev/null 2>&1
            m=$(( ($(date +%s%N)-s)/1000000 )); [ $m -lt $b ] && b=$m; done; echo $b; }
runs () { local n=$1; shift; local s=$(date +%s%N)
          for ((i=0;i<n;i++)); do "$@" >/dev/null 2>&1; done
          echo $(( ($(date +%s%N)-s)/1000000 )); }

echo
echo "== 1. size: a program that prints 4 =="
printf '  %-34s %9s\n' "ours (elf/src/four.wat)"        "$(sz elf/out/four.elf)"
printf '  %-34s %9s\n' "C, libc removed (-nostdlib)"    "$(sz $B/out_four_free)"
printf '  %-34s %9s\n' "C, glibc, dynamic"              "$(sz $B/out_four_dynamic)"
printf '  %-34s %9s\n' "C, glibc, static"               "$(sz $B/out_four_static)"

echo
echo "== 2. startup: 500 runs of a program that does nothing =="
printf '  %-34s %6s ms\n' "ours"                  "$(runs 500 ./elf/out/four.elf)"
printf '  %-34s %6s ms\n' "C, libc removed"       "$(runs 500 ./$B/out_four_free)"
printf '  %-34s %6s ms\n' "C, glibc, static"      "$(runs 500 ./$B/out_noop)"
printf '  %-34s %6s ms\n' "C, glibc, dynamic"     "$(runs 500 ./$B/out_noop_dyn)"

echo
echo "== 3. compute: fib(32), best of 5 =="
a=$(./elf/out/fib32.elf); b=$(./$B/out_fib_O2)
[ "$a" = "$b" ] || { echo "  FAIL: ours said $a, C said $b"; fail=1; }
printf '  %-34s %6s ms   (answer %s)\n' "ours"     "$(best 5 ./elf/out/fib32.elf)" "$a"
printf '  %-34s %6s ms\n' "C, gcc -O0"             "$(best 5 ./$B/out_fib_O0)"
printf '  %-34s %6s ms\n' "C, gcc -O2"             "$(best 5 ./$B/out_fib_O2)"

echo
echo "== 4. output: 100000 integers, best of 5 -- both sides buffer, ~150 write syscalls =="
diff <(./elf/out/spew.elf) <(./$B/out_spew) >/dev/null || { echo "  FAIL: different output"; fail=1; }
printf '  %-34s %6s ms   (4 KiB buffer, 70 bytes of runtime)\n' "ours" "$(best 5 ./elf/out/spew.elf)"
printf '  %-34s %6s ms   (glibc stdio, 4 KiB buffered)\n' "C, gcc -O2" "$(best 5 ./$B/out_spew)"

echo
# fib(32) asks two questions at once -- how good is our straight-line code, and how expensive is
# our CALL. This asks only the first: C-121 turns a self tail call into a `jmp` on the same frame,
# so no call survives the loop. C-153 measured 26 instructions an iteration against gcc's 6, and
# 1.34x the CYCLES, because the loop is latency-bound on its own accumulator and the machine has
# issue width to spare. The first version of this benchmark was summed away in CLOSED FORM by
# gcc -- 231,032 instructions for the whole program -- so the conditional subtraction is load
# bearing.
echo "== 5. straight-line code: a loop with no calls in it, 100M iterations, best of 3 =="
a=$(./elf/out/loopsum.elf); b=$(./$B/out_loopsum)
if [ "$a" = "$b" ]; then
  printf '  %-34s %6s ms   (answer %s)\n' "ours"     "$(best 3 ./elf/out/loopsum.elf)" "$a"
  printf '  %-34s %6s ms\n' "C, gcc -O2"             "$(best 3 ./$B/out_loopsum)"
else
  echo "  FAIL: ours '$a', C '$b'"; fail=1
fi
if command -v perf >/dev/null && [ -r /proc/sys/kernel/perf_event_paranoid ]; then
  ins () { taskset -c 2 perf stat -e cpu_core/instructions/ "$1" 2>&1 \
           | awk '/instructions/{gsub(",","",$1); print $1}'; }
  o=$(ins ./elf/out/loopsum.elf); c=$(ins ./$B/out_loopsum)
  [ -n "$o" ] && [ -n "$c" ] && printf '  %-34s %s vs %s  (%s vs %s an iteration)\n' \
    "instructions retired" "$o" "$c" "$((o/100000000))" "$((c/100000000))"
fi

# **the same loop with work to overlap.** Section 5 carries ONE accumulator, so both compilers
# wait on the same dependency chain and the machine's spare width hides our extra instructions --
# which is why we tie there while issuing 3.3x as many. C-153 predicted that tie would not survive
# a loop that is throughput-bound, and this is that loop: three independent chains. gcc's IPC goes
# from 1.97 to 4.34 and ours stays pinned at ~6.4, which is the issue width. On code of this shape
# the instruction count IS the ceiling.
echo
echo "== 6. throughput: three independent chains, 30M iterations, best of 3 =="
a=$(./elf/out/triple.elf); b=$(./$B/out_triple)
if [ "$a" = "$b" ]; then
  printf '  %-34s %6s ms   (answer %s)\n' "ours"     "$(best 3 ./elf/out/triple.elf)" "$a"
  printf '  %-34s %6s ms\n' "C, gcc -O2"             "$(best 3 ./$B/out_triple)"
else
  echo "  FAIL: ours '$a', C '$b'"; fail=1
fi
if command -v perf >/dev/null && [ -r /proc/sys/kernel/perf_event_paranoid ]; then
  ins () { taskset -c 2 perf stat -e cpu_core/instructions/ "$1" 2>&1 \
           | awk '/instructions/{gsub(",","",$1); print $1}'; }
  o=$(ins ./elf/out/triple.elf); c=$(ins ./$B/out_triple)
  [ -n "$o" ] && [ -n "$c" ] && printf '  %-34s %s vs %s  (%s vs %s an iteration)\n' \
    "instructions retired" "$o" "$c" "$((o/30000000))" "$((c/30000000))"
fi

echo
echo "== 7. tail calls: 1000000 deep, which wat eliminates and so must we =="
o=$(./elf/out/deep.elf); orc=$?
i=$("$WAT" elf/src/deep.wat 2>&1); irc=$?
if [ "$o" = "$i" ] && [ $orc -eq $irc ]; then
  echo "  ours $o (exit $orc), interpreter $i (exit $irc) -- constant stack both ways"
else
  echo "  FAIL: ours '$o' exit $orc, interpreter '$i' exit $irc"; fail=1
fi

echo
[ $fail -eq 0 ] && echo "vs-c: ok" || echo "vs-c: FAILED"
exit $fail
