#!/usr/bin/env bash
# tools/vs-c.sh: the compiler in elf/ against C, on four axes, with the numbers stated rather
# than claimed.
#
# The opponents are built here, not committed: C with glibc (what a C program normally is),
# and C with libc REMOVED -- `-nostdlib -nostartfiles`, raw syscalls, its own `_start`. That
# second one is the honest opponent on size, because it is the same bargain elf/ makes.
#
# **FOUR opponents a row, because "beating C" is not a claim about one compiler at one
# setting.** Until F-145 every section here built `gcc -O2` and nothing else; `-O0` appeared
# once and `clang` never, while the repo carried a belief about both. The two optimisers
# disagree by more than we differ from either: on `fib` (F-133) `gcc -O2` is 0.66x us and
# `clang -O2` is 1.37x us, a 2x spread on the same source. A scoreboard with one column
# cannot see that.
#
# Requires gcc; clang rows appear when clang is installed. Exit code 0 when everything built
# and every pair computed the same answer.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
command -v gcc >/dev/null || { echo "vs-c: no gcc"; exit 2; }
HAVE_CLANG=0; command -v clang >/dev/null && HAVE_CLANG=1
WAT="${WAT:-../wat-rs/target/release/wat}"
B=elf/bench
fail=0

# four builds of every program: both optimisers, at the floor and at -O2
build4 () {                     # build4 <name> <source> [extra cc flags...]
  local n=$1 src=$2; shift 2
  gcc   -O0 -static "$@" -o $B/out_${n}_gcc0   $src || fail=1
  gcc   -O2 -static "$@" -o $B/out_${n}_gcc2   $src || fail=1
  [ $HAVE_CLANG -eq 1 ] || return 0
  clang -O0 -static "$@" -o $B/out_${n}_clang0 $src || fail=1
  clang -O2 -static "$@" -o $B/out_${n}_clang2 $src || fail=1
}

echo "== building the opponents (gcc $(gcc -dumpversion)$([ $HAVE_CLANG -eq 1 ] \
     && echo ", clang $(clang -dumpversion)")) =="
gcc -O2                         -o $B/out_four_dynamic $B/four.c      || fail=1
gcc -O2 -static -nostdlib -nostartfiles -Wl,--build-id=none \
    -Wl,-z,noseparate-code -Wl,-n -o $B/out_four_free  $B/four_free.c || fail=1
strip -s $B/out_four_free 2>/dev/null
if [ $HAVE_CLANG -eq 1 ]; then
  clang -O2 -static -nostdlib -nostartfiles -Wl,--build-id=none \
      -Wl,-z,noseparate-code -Wl,-n -o $B/out_four_free_clang $B/four_free.c 2>/dev/null \
      && strip -s $B/out_four_free_clang 2>/dev/null
fi
gcc -O2         -o $B/out_noop_dyn $B/noop.c || fail=1
build4 four    $B/four.c
build4 fib     $B/fib.c
build4 noop    $B/noop.c
build4 spew    $B/spew.c
build4 loopsum $B/loopsum.c
build4 triple  $B/triple.c

sz () { stat -c%s "$1"; }
# **every timed run is PINNED, and to the same core (F-149).** This is a hybrid CPU: the
# P-cores and E-cores run at different frequencies, so two unpinned programs are not timed
# in the same frequency domain and the comparison measures the scheduler. `strbuild`
# unpinned read 21 ms against C's 19; pinned and interleaved, best of 15, it is 22 against
# 31. The repo already knew to pin for instruction counts (tools/cc-time.sh, F-143); wall
# time needs it for exactly the same reason.
PIN="${PIN:-taskset -c 0}"
best () { local n=$1; shift; local b=99999999 s m
          for ((i=0;i<n;i++)); do s=$(date +%s%N); $PIN "$@" >/dev/null 2>&1
            m=$(( ($(date +%s%N)-s)/1000000 )); [ $m -lt $b ] && b=$m; done; echo $b; }
runs () { local n=$1; shift; local s=$(date +%s%N)
          for ((i=0;i<n;i++)); do $PIN "$@" >/dev/null 2>&1; done
          echo $(( ($(date +%s%N)-s)/1000000 )); }
row  () { printf '  %-34s %6s ms\n' "$1" "$2"; }
# every opponent for one program, in the order a reader wants them: the floor, then the two
# optimisers. `best` for a timed run, `runs` for a startup count -- `how` picks which.
rivals () {                     # rivals <how> <n> <name> [args...]
  local how=$1 n=$2 nm=$3; shift 3
  row "C, gcc -O0"   "$($how $n ./$B/out_${nm}_gcc0 "$@")"
  row "C, gcc -O2"   "$($how $n ./$B/out_${nm}_gcc2 "$@")"
  [ $HAVE_CLANG -eq 1 ] || return 0
  row "C, clang -O0" "$($how $n ./$B/out_${nm}_clang0 "$@")"
  row "C, clang -O2" "$($how $n ./$B/out_${nm}_clang2 "$@")"
}

echo
echo "== 1. size: a program that prints 4 =="
printf '  %-34s %9s\n' "ours (elf/src/four.wat)"        "$(sz elf/out/four.elf)"
printf '  %-34s %9s\n' "C, libc removed (gcc -nostdlib)" "$(sz $B/out_four_free)"
[ -f $B/out_four_free_clang ] && \
printf '  %-34s %9s\n' "C, libc removed (clang)"        "$(sz $B/out_four_free_clang)"
printf '  %-34s %9s\n' "C, glibc, dynamic"              "$(sz $B/out_four_dynamic)"
printf '  %-34s %9s\n' "C, glibc, static, gcc -O0"      "$(sz $B/out_four_gcc0)"
printf '  %-34s %9s\n' "C, glibc, static, gcc -O2"      "$(sz $B/out_four_gcc2)"
if [ $HAVE_CLANG -eq 1 ]; then
printf '  %-34s %9s\n' "C, glibc, static, clang -O0"    "$(sz $B/out_four_clang0)"
printf '  %-34s %9s\n' "C, glibc, static, clang -O2"    "$(sz $B/out_four_clang2)"
fi

echo
echo "== 2. startup: 500 runs of a program that does nothing =="
row "ours"            "$(runs 500 ./elf/out/four.elf)"
row "C, libc removed" "$(runs 500 ./$B/out_four_free)"
rivals runs 500 noop
row "C, glibc, dynamic" "$(runs 500 ./$B/out_noop_dyn)"

echo
echo "== 3. compute: fib(32), best of 5 =="
a=$(./elf/out/fib32.elf); b=$(./$B/out_fib_gcc2)
[ "$a" = "$b" ] || { echo "  FAIL: ours said $a, C said $b"; fail=1; }
printf '  %-34s %6s ms   (answer %s)\n' "ours"     "$(best 5 ./elf/out/fib32.elf)" "$a"
rivals best 5 fib
# F-133: gcc -O2's win here is a REASSOCIATION, which wat's trapping arithmetic forbids --
# it makes 364,490 calls where the naive recursion makes 7,049,155. Held to our semantics
# both optimisers lose: clang falls back to the naive recursion exactly.
printf '  %-34s %s\n' "" "F-133: gcc -O2 reassociates, which trapping forbids;"
printf '  %-34s %s\n' "" "held to wat's semantics we are 2.46x clang, 3.22x gcc"

echo
echo "== 4. output: 100000 integers, best of 5 -- both sides buffer, ~150 write syscalls =="
diff <(./elf/out/spew.elf) <(./$B/out_spew_gcc2) >/dev/null || { echo "  FAIL: different output"; fail=1; }
printf '  %-34s %6s ms   (4 KiB buffer, 70 bytes of runtime)\n' "ours" "$(best 5 ./elf/out/spew.elf)"
rivals best 5 spew

echo
# fib(32) asks two questions at once -- how good is our straight-line code, and how expensive is
# our CALL. This asks only the first: C-121 turns a self tail call into a `jmp` on the same frame,
# so no call survives the loop. C-153 measured 26 instructions an iteration against gcc's 6, and
# 1.34x the CYCLES, because the loop is latency-bound on its own accumulator and the machine has
# issue width to spare. The first version of this benchmark was summed away in CLOSED FORM by
# gcc -- 231,032 instructions for the whole program -- so the conditional subtraction is load
# bearing.
echo "== 5. straight-line code: a loop with no calls in it, 100M iterations, best of 3 =="
a=$(./elf/out/loopsum.elf); b=$(./$B/out_loopsum_gcc2)
if [ "$a" = "$b" ]; then
  printf '  %-34s %6s ms   (answer %s)\n' "ours"     "$(best 3 ./elf/out/loopsum.elf)" "$a"
  rivals best 3 loopsum
else
  echo "  FAIL: ours '$a', C '$b'"; fail=1
fi
if command -v perf >/dev/null && [ -r /proc/sys/kernel/perf_event_paranoid ]; then
  ins () { taskset -c 2 perf stat -e cpu_core/instructions/ "$1" 2>&1 \
           | awk '/instructions/{gsub(",","",$1); print $1}'; }
  o=$(ins ./elf/out/loopsum.elf); c=$(ins ./$B/out_loopsum_gcc2)
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
a=$(./elf/out/triple.elf); b=$(./$B/out_triple_gcc2)
if [ "$a" = "$b" ]; then
  printf '  %-34s %6s ms   (answer %s)\n' "ours"     "$(best 3 ./elf/out/triple.elf)" "$a"
  rivals best 3 triple
else
  echo "  FAIL: ours '$a', C '$b'"; fail=1
fi
if command -v perf >/dev/null && [ -r /proc/sys/kernel/perf_event_paranoid ]; then
  ins () { taskset -c 2 perf stat -e cpu_core/instructions/ "$1" 2>&1 \
           | awk '/instructions/{gsub(",","",$1); print $1}'; }
  o=$(ins ./elf/out/triple.elf); c=$(ins ./$B/out_triple_gcc2)
  [ -n "$o" ] && [ -n "$c" ] && printf '  %-34s %s vs %s  (%s vs %s an iteration)\n' \
    "instructions retired" "$o" "$c" "$((o/30000000))" "$((c/30000000))"
fi

echo
echo "== 8. strings: count one byte in a 194 KB text file =="
tools/gen-scan.sh
build4 scan elf/bench/scan.c
a=$(./elf/out/scanfast.elf); b2=$(./$B/out_scan_gcc2)
if [ "$a" = "$b2" ]; then
  printf '  %-34s %6s ms   (answer %s)\n' "ours, code-point-at"  "$(best 5 ./elf/out/scanfast.elf)" "$a"
  printf '  %-34s %6s ms   (F-135: subs allocates per character)\n' "ours, subs per character" "$(best 5 ./elf/out/scan.elf)"
  rivals best 5 scan
else
  echo "  FAIL: ours '$a', C '$b2'"; fail=1
fi

echo
echo "== 9. strings: BUILDING one, 5000000 appends (F-141, F-143) =="
build4 strbuild elf/bench/strbuild.c
# **The load-bearing comparison here has no C compiler in it.** strbuild2 is a copy of strbuild
# with one extra read of the accumulator -- a read that happens BEFORE the append and cannot
# observe it. Until C-176 that second mention disqualified the name and the copy went quadratic,
# exhausting the heap where this one finished in 19 ms (F-141). The two now agree, which is the
# regression test: if they ever diverge again, liveness has stopped working.
# **Two C controls, deliberately.** `f` is what gcc makes of the naive `s[i]='x'` loop -- a
# vectorised memset with NO per-element work, which is not appending at all. It is the floor.
# The default is the like-for-like: a call per character that checks capacity and grows, which
# is what `str_cat_own` does. Comparing against the fill measures the SEMANTICS (wat's concat
# returns a value and must check ownership); comparing against the append measures the CODE.
a=$(./elf/out/strbuild.elf); b2=$(./$B/out_strbuild_gcc2)
if [ "$a" = "$b2" ]; then
  printf '  %-34s %6s ms   (answer %s)\n' "ours, accumulator named once" "$(best 3 ./elf/out/strbuild.elf)" "$a"
  rivals best 3 strbuild
  printf '  %-34s %6s ms   (a memset; the floor, not an opponent)\n' "C, gcc -O2, buffer fill" "$(best 3 ./$B/out_strbuild_gcc2 f)"
else
  echo "  FAIL: ours '$a', C '$b2'"; fail=1
fi
o=$(./elf/out/strbuild2.elf 2>&1); orc=$?
if [ $orc -eq 0 ]; then
  printf '  %-34s %6s ms\n' "ours, named TWICE" "$(best 3 ./elf/out/strbuild2.elf)"
else
  printf '  %-34s %s (exit %s)\n' "ours, named TWICE" "$o" "$orc"
  printf '  %-34s %s\n' "" "F-141: one extra read, and the same n cannot finish"
fi

echo
echo "== 10. records: updating one field, 2000000 times (F-140) =="
build4 rec elf/bench/rec.c
# Again the load-bearing pair is ours-against-ours: recflat.wat is the IDENTICAL loop with the
# accumulator threaded as a bare i64. gcc keeps the struct in registers, and an earlier version
# of rec.c with a literal bound was folded to a closed form entirely -- under one instruction per
# iteration -- so the C column here is a floor, not an opponent.
a=$(./elf/out/rec.elf); b2=$(./elf/out/recflat.elf); c2=$(./$B/out_rec_gcc2)
if [ "$a" = "$b2" ] && [ "$a" = "$c2" ]; then
  printf '  %-34s %6s ms   (answer %s)\n' "ours, record assoc"       "$(best 5 ./elf/out/rec.elf)" "$a"
  printf '  %-34s %6s ms   (the same loop, nothing allocated)\n' "ours, bare i64" "$(best 5 ./elf/out/recflat.elf)"
  rivals best 5 rec
  # **rec1 has no C column and cannot have one (F-146).** It stores the counter --
  # `(assoc s :a i)` -- where rec.wat and rec.c accumulate, so it answers 1999999 rather
  # than 1999999000000 and does strictly less work an iteration. Giving rec.c a matching
  # store-only mode got it folded to a closed form, which is the point: `s.a = i` in a loop
  # IS dead code, only the last write is observable, so no C compiler will ever perform it.
  # It stays as ours-against-ours evidence, like strbuild2, and is answer-checked here.
  r1=$(./elf/out/rec1.elf)
  if [ "$r1" = "1999999" ]; then
    printf '  %-34s %6s ms   (ours-vs-ours: named ONCE, answers %s)\n' \
      "ours, store only, no C rival" "$(best 5 ./elf/out/rec1.elf)" "$r1"
  else
    echo "  FAIL: rec1 '$r1', expected 1999999"; fail=1
  fi
  printf '  %-34s %s\n' "" "C-175/C-176: the owning path, and liveness rather than"
  printf '  %-34s %s\n' "" "mention-counting, so the accumulating idiom reaches it"
else
  echo "  FAIL: record '$a', flat '$b2', C '$c2'"; fail=1
fi

echo
echo "== 11. vectors: BUILD 2000000 by conj, then READ every element by nth (F-164) =="
build4 vec elf/bench/vec.c
# **Two paths in one program, and they go opposite ways.** `conj` has an in-place path when
# the accumulator is a last use (C-127) and the vector PROMOTES flat->tree so `conj` is
# O(log n) (C-145, a 1,580x cliff closed). That won the build. The same tree is what `nth`
# has to walk, where C indexes an array by arithmetic. The C control's `append` is noinline
# and checks capacity per element on purpose: a malloc-up-front fill measures the allocator,
# not the append, which is the F-140/F-143 mistake this repo has made twice.
a=$(./elf/out/vecsum.elf); b2=$(./$B/out_vec_gcc2)
if [ "$a" = "$b2" ]; then
  printf '  %-34s %6s ms   (answer %s)\n' "ours, conj + nth"       "$(best 3 ./elf/out/vecsum.elf)" "$a"
  printf '  %-34s %6s ms   (BUILD only -- we WIN this half)\n' "ours, conj alone" "$(best 3 ./elf/out/grow2000000.elf)"
  rivals best 3 vec
  printf '  %-34s %s\n' "" "F-164: conj 6.72 cyc/elem against gcc's 8.85 -- we win the build"
  printf '  %-34s %s\n' "" "at 74.5%% retiring against its 29.8%%. nth is 37 uops to its 3:"
  printf '  %-34s %s\n' "" "the tree C-145 promoted to is what C-145 made us pay for."
else
  echo "  FAIL: ours '$a', C '$b2'"; fail=1
fi

echo
echo "== 12. enums: an Option-shaped match, 20000000 times (C-205) =="
build4 opt elf/bench/opt.c
# **The fixture guards itself now (F-184).** This row silently measured nothing for as long
# as opt.c used a static const payload and literal loop bounds: gcc folded `pick` into a
# three-instruction clone that never read its argument, and every oracle stayed green because
# the ANSWER was still 80000000. An answer check cannot catch an opponent that optimises the
# measured operation away, so the shape of the emitted code is checked directly.
if nm ./$B/out_opt_gcc2 2>/dev/null | grep -q 'pick\.'; then
  echo "  FAIL: gcc cloned pick -- opt.c has stopped resisting constant propagation"; fail=1
elif ! objdump -d ./$B/out_opt_gcc2 2>/dev/null | sed -n '/<pick>:/,/ret/p' | grep -qE 'cmov|jns|js '; then
  echo "  FAIL: gcc elided pick's sign test -- opt.c is measuring a constant"; fail=1
fi
# **The load-bearing pair is ours-against-ours.** optm.wat and optmh.wat are the SAME loop;
# the only difference is a second payload variant in optmh, which forces the heap tier. So the
# delta between those two rows is pure REPRESENTATION, with the trap checks, the refcount
# share and the call overhead identical on both sides.
#
# C is an honest opponent here rather than a strawman: System V returns a 16-byte tagged union
# in RAX:RDX, so C allocates nothing either. Our tier 1 is EIGHT bytes and one register,
# because the payload variant simply IS its pointer -- but we still pay a trap check per add,
# a refcount guard per share, and stack argument passing, which C pays none of.
a=$(./elf/out/optm.elf); b2=$(./elf/out/optmh.elf); c2=$(./$B/out_opt_gcc2)
if [ "$a" = "$b2" ] && [ "$a" = "$c2" ]; then
  printf '  %-34s %6s ms   (answer %s)\n' "ours, tier 1 (the pointer)" "$(best 5 ./elf/out/optm.elf)" "$a"
  printf '  %-34s %6s ms   (the same loop, heap tier)\n' "ours, tier 3 (vec_new)" "$(best 5 ./elf/out/optmh.elf)"
  rivals best 5 opt
  printf '  %-34s %s\n' "" "C-205: the tier is derived from the enum's shape, per"
  printf '  %-34s %s\n' "" "instantiation -- Option and Result are not special-cased"
else
  echo "  FAIL: tier1 '$a', tier3 '$b2', C '$c2'"; fail=1
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
