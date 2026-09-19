#!/usr/bin/env bash
# tools/bootstrap.sh: the compiler compiles itself, and the result compiles itself again.
#
# Three things are checked, in order of how much they say:
#
#   1. STAGE 1 EXISTS. `wat elf/compile.wat` compiles every program in elf/ -- and, last, the
#      compiler itself. That binary is stage 1.
#   2. STAGE 1 AGREES. Stage 1 compiles everything again. Every binary it writes must be
#      byte-identical to the one the interpreted compiler wrote, for all of them.
#   3. THE FIXPOINT. Among those binaries is the compiler. If stage 2 equals stage 1 byte for
#      byte, the compiler reproduces itself, which is the only definition of self-hosting that
#      means anything.
#
# Exit code 0 when all three hold.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
WAT="${WAT:-../wat-rs/target/release/wat}"
[ -x "$WAT" ] || { echo "bootstrap: no wat binary at $WAT"; exit 2; }
SNAP=$(mktemp -d); trap 'rm -rf "$SNAP"' EXIT
fail=0
ms () { echo $(( ($(date +%s%N) - $1) / 1000000 )); }

echo "== stage 0: the interpreter runs the compiler =="
s=$(date +%s%N)
"$WAT" elf/compile.wat > "$SNAP/stage0.log" 2>&1 || { echo "FAIL: stage 0"; tail -3 "$SNAP/stage0.log"; exit 1; }
t0=$(ms $s)
chmod +x elf/out/*.elf
cp elf/out/*.elf "$SNAP/"
printf '   %s binaries in %s ms, the compiler among them (%s bytes)\n' \
       "$(ls elf/out/*.elf | wc -l)" "$t0" "$(stat -c%s elf/out/compiler.elf)"

cp elf/out/compiler.elf elf/out/stage1.elf
chmod +x elf/out/stage1.elf

echo
echo "== stage 1: the compiler, compiled, runs itself =="
s=$(date +%s%N)
./elf/out/stage1.elf > "$SNAP/stage1.log" 2>&1 || { echo "FAIL: stage 1 did not finish"; tail -3 "$SNAP/stage1.log"; exit 1; }
t1=$(ms $s)
[ "$t1" -lt 1 ] && t1=1
printf '   the same work in %s ms -- %sx faster than the interpreter\n' "$t1" "$(( t0 / t1 ))"

echo
echo "== every binary, from both =="
n=0; d=0
for f in "$SNAP"/*.elf; do
  b=$(basename "$f"); [ "$b" = "stage1.elf" ] && continue
  n=$((n+1))
  cmp -s "$f" "elf/out/$b" || { echo "   DIFFER: $b"; d=$((d+1)); }
done
if [ $d -eq 0 ]; then echo "   $n binaries, all byte-identical"; else echo "   $d of $n differ"; fail=1; fi

echo
echo "== the fixpoint =="
if cmp -s elf/out/stage1.elf elf/out/compiler.elf; then
  echo "   stage1 == stage2, byte for byte ($(stat -c%s elf/out/stage1.elf) bytes)"
  echo "   The compiler reproduces itself."
else
  echo "   FAIL: stage 2 is not stage 1"; fail=1
fi

echo
[ $fail -eq 0 ] && echo "bootstrap: ok" || echo "bootstrap: FAILED"
exit $fail
