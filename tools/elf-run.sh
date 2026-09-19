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
for name in four arith greet branch fib bench; do
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

echo
echo "== what compiling is worth: fib(27), the same source both ways =="
s=$(date +%s%N); "$WAT" elf/src/bench.wat >/dev/null 2>&1; i=$(( ($(date +%s%N)-s)/1000000 ))
s=$(date +%s%N); ./elf/out/bench.elf  >/dev/null 2>&1; n=$(( ($(date +%s%N)-s)/1000000 ))
[ "$n" -lt 1 ] && n=1
printf 'interpreted %5s ms    native %3s ms    %sx\n' "$i" "$n" "$(( i / n ))"

echo
echo "== and the compiler refuses what it cannot translate =="
msg=$("$WAT" elf/refuse.wat 2>&1)
if printf '%s' "$msg" | grep -q 'cannot compile call: (wat.core/quot 10 2)'; then
  echo "refused elf/bad/unsupported.wat, naming the form: (wat.core/quot 10 2)"
else
  echo "FAIL: the compiler did not refuse elf/bad/unsupported.wat as expected"
  printf '%s\n' "$msg" | head -3 | sed 's/^/      /'
  fail=1
fi

echo
if [ $fail -eq 0 ]; then
  echo "elf-run: ok -- eight native binaries, six of them compiled from wat source,"
  echo "         and every one agrees with the interpreter that produced it"
else
  echo "elf-run: FAILED"
fi
exit $fail
