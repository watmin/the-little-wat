#!/usr/bin/env bash
# tools/elf-run.sh: the two steps wat cannot take, and the check it cannot make.
#
# wat can compute the bytes of an ELF and write them, and elf/hello.wat and elf/compile.wat both
# verify what they wrote by reading it back. What wat cannot do is set the executable bit
# (`:wat::io::` has no chmod) or run the result (`:wat::kernel::spawn-process` forks a wat child
# that evaluates a source string, not an arbitrary program). This script does those, and then the
# check that matters most: for every program in elf/src/, the COMPILED BINARY and the wat
# INTERPRETER must print exactly the same thing and exit the same way.
#
# Exit code: 0 when every binary behaves and every differential comparison agrees.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

WAT="${WAT:-../wat-rs/target/release/wat}"
[ -x "$WAT" ] || { echo "elf-run: no wat binary at $WAT"; exit 2; }
fail=0

echo "== hand-written: elf/hello.wat =="
"$WAT" elf/hello.wat || exit 1
chmod +x elf/out/hello.elf elf/out/exit42.elf
out=$(./elf/out/hello.elf); rc=$?
[ "$out" = "hello from wat" ] && [ $rc -eq 0 ] || { echo "FAIL hello.elf: '$out' exit $rc"; fail=1; }
echo "hello.elf   printed '$out', exited $rc"
./elf/out/exit42.elf; rc=$?
[ $rc -eq 42 ] || { echo "FAIL exit42.elf: exit $rc"; fail=1; }
echo "exit42.elf  exited $rc, which wat computed as 6 * 7"

echo
echo "== compiled from wat source: elf/compile.wat =="
"$WAT" elf/compile.wat || exit 1
chmod +x elf/out/*.elf

echo
echo "== the check that matters: compiled binary vs wat interpreter =="
for name in four arith greet branch fib bench strings shadow churn deep logic vectors memory linear; do
  src="elf/src/$name.wat"; bin="elf/out/$name.elf"
  interp=$("$WAT" "$src" 2>&1); irc=$?
  native=$("./$bin" 2>&1); nrc=$?
  if [ "$interp" = "$native" ] && [ $irc -eq $nrc ]; then
    printf '%-8s agree (exit %d, %4s bytes native)  %s\n' "$name" "$nrc" "$(stat -c%s "$bin")" \
           "$(printf '%s' "$native" | tr '\n' ' ' | cut -c1-46)"
  else
    echo "FAIL $name: interpreter and binary differ"
    diff <(printf '%s\n' "$interp") <(printf '%s\n' "$native") | sed 's/^/      /'
    fail=1
  fi
done

# churn allocates 2.4 MB out of a 1 MiB heap and gives all of it back; before the compiler
# learned to release at statement boundaries it died here with a segmentation fault.
echo "         (churn allocates 2.4 MB against a 1 MiB heap -- it only agrees because the"
echo "          compiler releases what a discarded statement allocated: C-120)"
echo "         (deep is 1000000 tail calls -- wat eliminates them and so does this"
echo "          compiler, on the same frame: C-121)"
echo "         (linear proves BOTH halves of the in-place conj guard: remove the share"
echo "          increment and base comes back with 4 elements instead of 3: C-127)"
echo
echo "== native-only: syscalls the interpreter has no implementation of (F-119) =="
check_native () {   # name, expected output (newline separated)
  local name="$1" want="$2" bin="elf/out/$1.elf"
  local got rc
  got=$(timeout -s KILL 20 "./$bin" 2>&1); rc=$?
  if [ "$got" = "$want" ] && [ $rc -eq 0 ]; then
    printf '%-10s %4s bytes  %s\n' "$name" "$(stat -c%s "$bin")" "$(printf '%s' "$got" | tr '\n' ' ')"
  else
    echo "FAIL $name: got '$got' (exit $rc), wanted '$want'"
    fail=1
  fi
}
# fork: parent prints 1, child prints 2 and exits 7, parent reads that status back, then 1 1 4
check_native fork     "$(printf '1\n2\n7\n1\n1\n4')"
# clone with CLONE_VM: the child writes 22 into a page the parent mmap'd, and the parent sees it
check_native thread   "$(printf '11\n22')"
# four threads, each writing its own slot; 100 + 200 + 300 + 400
check_native threads4 "1000"

echo
echo "== what compiling is worth: fib(27), the same source both ways =="
s=$(date +%s%N); "$WAT" elf/src/bench.wat >/dev/null 2>&1; i=$(( ($(date +%s%N)-s)/1000000 ))
s=$(date +%s%N); ./elf/out/bench.elf  >/dev/null 2>&1; n=$(( ($(date +%s%N)-s)/1000000 ))
[ "$n" -lt 1 ] && n=1
printf 'interpreted %5s ms    native %3s ms    %sx\n' "$i" "$n" "$(( i / n ))"

echo
echo "== and the compiler refuses what it cannot translate =="
# Both files are generated from elf/compile.wat by tools/gen-refuse.sh, so they are the SAME
# compiler; both programs are valid wat that the interpreter runs.
refuses () {   # driver, needle, what it proves
  local drv="$1" needle="$2" why="$3" msg
  msg=$("$WAT" "$drv" 2>&1)
  if printf '%s' "$msg" | grep -qF "$needle"; then
    echo "$why"
  else
    echo "FAIL: $drv did not refuse as expected"
    printf '%s\n' "$msg" | head -3 | sed 's/^/      /'
    fail=1
  fi
}
refuses elf/refuse.wat          'cannot compile call: (wat.core/str 10)' \
        "refused elf/bad/unsupported.wat, naming the form:    (wat.core/str 10)"
refuses elf/refuse-nonascii.wat 'not encodable' \
        "refused elf/bad/nonascii.wat, naming the character:  e-acute (F-120: bytes vs chars)"

echo
if [ $fail -eq 0 ]; then
  echo "elf-run: ok -- twenty native binaries, eighteen of them compiled from wat source."
  echo "         Fourteen agree with the interpreter; three use syscalls it cannot run (F-119)."
else
  echo "elf-run: FAILED"
fi
exit $fail
