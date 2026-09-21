#!/usr/bin/env bash
# tools/bootstrap.sh [--fast]: the compiler compiles itself, and the result compiles itself again.
#
# --fast seeds the chain from the compiler binary already in elf/out/ instead of from the
# interpreter, which is the whole point of having bootstrapped: stage 0 through `wat` is 65-85 s
# and the compiled compiler does the same work in half a second. After a change to
# elf/compile.wat the old binary compiles the new source to stage 2, stage 2 compiles it again to
# stage 3, and **stage 2 == stage 3 is the fixpoint for the NEW compiler**. Stage 2 differing
# from the seed is expected -- that is what a change to the code generator means.
#
# Use --fast while iterating. Use the full run before committing, because only it proves the
# chain still starts from source a human can read rather than from a binary nobody can.
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
FAST=""; [ "${1:-}" = "--fast" ] && FAST=1
[ -n "$FAST" ] || [ -x "$WAT" ] || { echo "bootstrap: no wat binary at $WAT"; exit 2; }
SNAP=$(mktemp -d); trap 'rm -rf "$SNAP"' EXIT
fail=0
ms () { echo $(( ($(date +%s%N) - $1) / 1000000 )); }

if [ -n "$FAST" ]; then
  [ -x elf/out/compiler.elf ] || { echo "bootstrap --fast: no elf/out/compiler.elf to seed from."
                                   echo "                  run tools/bootstrap.sh once without --fast."; exit 2; }
  cp elf/out/compiler.elf elf/out/seed.elf; chmod +x elf/out/seed.elf
  echo "== stage 0: skipped; seeding from the compiler already built ($(stat -c%s elf/out/seed.elf) bytes) =="
  s=$(date +%s%N)
  ./elf/out/seed.elf > "$SNAP/stage0.log" 2>&1 || { echo "FAIL: the seed could not compile this source."
                                                    tail -3 "$SNAP/stage0.log"
                                                    echo "      (a new form may need the interpreter: run without --fast)"; exit 1; }
  # exit 0 is not enough: a seed left behind by an experiment can run, print something else and
  # write no binaries at all -- and then every comparison below passes because nothing moved.
  grep -q '"compile: ok"' "$SNAP/stage0.log" || { echo "FAIL: the seed ran but did not compile."
                                                  echo "      last line: $(tail -1 "$SNAP/stage0.log")"
                                                  echo "      (elf/out/compiler.elf is not a compiler: rebuild without --fast)"; exit 1; }
  t0=$(ms $s)
  chmod +x elf/out/*.elf
  cp elf/out/*.elf "$SNAP/"
  printf '   %s binaries in %s ms\n' "$(ls elf/out/*.elf | wc -l)" "$t0"
else
  echo "== stage 0: the interpreter runs the compiler =="
  s=$(date +%s%N)
  "$WAT" elf/compile.wat > "$SNAP/stage0.log" 2>&1 || { echo "FAIL: stage 0"; tail -3 "$SNAP/stage0.log"; exit 1; }
  t0=$(ms $s)
  chmod +x elf/out/*.elf
  cp elf/out/*.elf "$SNAP/"
  printf '   %s binaries in %s ms, the compiler among them (%s bytes)\n' \
         "$(ls elf/out/*.elf | wc -l)" "$t0" "$(stat -c%s elf/out/compiler.elf)"
fi

# **--fast REPORTS ONE SPURIOUS `DIFFER` AFTER ANY CHANGE TO THE EMITTED RUNTIME.**
# It seeds from the compiler already built, so the seed compiles the comparison set with the
# runtime it was BORN with while stage 1 compiles its set with the new one. They disagree for
# exactly one run, and --fast cannot tell that from a regression. Re-run it: the second pass
# seeds from a compiler carrying the new runtime and the two agree. A failed run also POISONS
# the seed, leaving a broken elf/out/compiler.elf so the next --fast dies on a source already
# fixed. Neither afflicts a full run, where stage 0 builds everything from the interpreter.
#
# **AND THE TIME PRINTED BELOW IS ONE SAMPLE. Do not use it as a regression guard.**
# Three times in one session a single stage-1 number sent someone chasing a regression that was
# not there (739, 828 -- both 546 or better on a real measurement). Use `tools/cc-time.sh`,
# which copies the binary, checks every exit status, takes the best of fourteen, and reports an
# INSTRUCTION COUNT -- which barely moves with machine load and is the number to compare.
#
# **the source must not move while this runs.** Stage 0 compiles what is on disk and stage 1
# compiles it again; edit the compiler in between and the two stages build DIFFERENT compilers,
# which surfaces as a baffling "DIFFER: compiler.elf" with the fixpoint still green. That has now
# happened twice in one session to someone who knew the rule, so it is a check rather than a rule.
#
# C-174 split the compiler into three files, so this hashes ALL of them -- hashing only
# compile.wat would let an edit to lib/x86.wat or lib/runtime.wat through, which is this very
# check defeated by the refactor that was supposed to make the file easier to edit.
sources () { echo elf/compile.wat elf/lib/*.wat; }
srcsum () { sha256sum $(sources) | sha256sum | cut -c1-16; }
SRC_SUM=$(srcsum)

# **the negative tests are a DERIVED artifact, so derive them** (F-152). elf/refuse-*.wat are
# elf/compile.wat with a different driver; they are committed, and nothing regenerated them,
# so they drifted across seven changes while still passing. tools/elf-run.sh now fails when
# they drift -- and caught the very next commit, one change after the check was written,
# because "remember to regenerate" was never going to hold. They are regenerated here instead,
# before anything is compiled, and the check in elf-run.sh is the backstop rather than the
# only defence.
tools/gen-refuse.sh >/dev/null || { echo "FAIL: could not regenerate the negative tests"; exit 1; }

cp elf/out/compiler.elf elf/out/stage1.elf
chmod +x elf/out/stage1.elf

echo
echo "== stage 1: the compiler, compiled, runs itself =="
s=$(date +%s%N)
./elf/out/stage1.elf > "$SNAP/stage1.log" 2>&1 || { echo "FAIL: stage 1 did not finish"; tail -3 "$SNAP/stage1.log"; exit 1; }
grep -q '"compile: ok"' "$SNAP/stage1.log" || { echo "FAIL: stage 1 ran but did not compile"
                                                echo "      last line: $(tail -1 "$SNAP/stage1.log")"; exit 1; }
t1=$(ms $s)
[ "$t1" -lt 1 ] && t1=1
if [ -n "$FAST" ]; then
  printf '   the same work in %s ms\n' "$t1"
else
  printf '   the same work in %s ms -- %sx faster than the interpreter\n' "$t1" "$(( t0 / t1 ))"
fi

echo
echo "== every binary, from both =="
n=0; d=0
for f in "$SNAP"/*.elf; do
  b=$(basename "$f"); [ "$b" = "stage1.elf" ] && continue
  n=$((n+1))
  cmp -s "$f" "elf/out/$b" || { echo "   DIFFER: $b"; d=$((d+1)); }
done
if [ $d -eq 0 ]; then echo "   $n binaries, all byte-identical"; else echo "   $d of $n differ"; fail=1; fi

if [ "$(srcsum)" != "$SRC_SUM" ]; then
  echo
  echo "FAIL: the compiler source changed WHILE this ran -- stage 0 and stage 1 compiled different"
  echo "      sources, so any DIFFER below is that, not a regression. Re-run without editing."
  exit 1
fi

echo
echo "== the fixpoint =="
if cmp -s elf/out/stage1.elf elf/out/compiler.elf; then
  echo "   stage$( [ -n "$FAST" ] && echo 2 || echo 1 ) == stage$( [ -n "$FAST" ] && echo 3 || echo 2 ), byte for byte ($(stat -c%s elf/out/stage1.elf) bytes)"
  echo "   The compiler reproduces itself."
else
  echo "   FAIL: stage 2 is not stage 1"; fail=1
fi

echo
[ $fail -eq 0 ] && echo "bootstrap: ok" || echo "bootstrap: FAILED"
exit $fail
