#!/usr/bin/env bash
# tools/variant.sh <compiler-variant.wat> [label] -- build a whole compiler variant and RUN
# it, in about two seconds instead of tools/bootstrap.sh's 8.5 minutes.
#
# Why this is sound. elf/out/compiler.elf is the compiler at its FIXPOINT: bootstrap proved
# it emits byte-identical output to the interpreter for all 74 programs. So using it as the
# seed builds exactly the "stage 1" binary bootstrap would build -- and stage 1 is where a
# miscompiled compiler actually faults. What this SKIPS is stage 2 and the fixpoint check,
# so it answers "does this variant work", never "does this variant reproduce itself".
#
# **It is a bisecting tool, not a gate.** Nothing lands on its word alone; run
# tools/bootstrap.sh before committing.
#
#   tools/variant.sh scratch/try-this.wat
#
# Exit: 0 the variant built and ran itself, 1 it faulted or failed, 2 setup is wrong.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
REPO=$PWD
SRC="${1:?usage: tools/variant.sh <compiler-variant.wat> [label]}"
[ -f "$SRC" ] || { echo "variant: no such source: $SRC"; exit 2; }
SRC=$(realpath "$SRC")
LABEL="${2:-$(basename "$SRC" .wat)}"
SEED=elf/out/compiler.elf
[ -x "$SEED" ] || { echo "variant: no seed compiler at $SEED -- run tools/bootstrap.sh first"; exit 2; }

# A sandbox, so a variant never overwrites the seed it was built from -- the failure mode
# that leaves you with a broken elf/out/compiler.elf and no way back.
BOX=$(mktemp -d); trap 'rm -rf "$BOX"' EXIT
mkdir -p "$BOX/elf/out"
for d in lib src bad bench native; do ln -s "$REPO/elf/$d" "$BOX/elf/$d"; done
cp "$SRC" "$BOX/elf/compile.wat"
cp "$SEED" "$BOX/seed.elf"; chmod +x "$BOX/seed.elf"
cd "$BOX" || exit 2

# stage 0 equivalent: the seed builds the variant
timeout -s KILL 600 ./seed.elf > "$BOX/stage0.log" 2>&1; s0=$?
if [ $s0 -ne 0 ] || [ ! -f elf/out/compiler.elf ]; then
  echo "$LABEL: STAGE0-FAILED exit=$s0  $(tail -1 "$BOX/stage0.log")"
  cp "$BOX/stage0.log" "$REPO/elf/out/.variant-$LABEL.stage0.log" 2>/dev/null
  exit 1
fi
sz=$(stat -c%s elf/out/compiler.elf)

# stage 1: the variant compiler runs itself -- where a miscompile shows up
cp elf/out/compiler.elf ./s1.elf; chmod +x s1.elf
rm -f elf/out/*.elf
timeout -s KILL 600 ./s1.elf > "$BOX/stage1.log" 2>&1; s1=$?
nok=$(grep -c "verified" "$BOX/stage1.log")
last=$(tail -1 "$BOX/stage1.log")
cp "$BOX/stage1.log" "$REPO/elf/out/.variant-$LABEL.stage1.log" 2>/dev/null

if [ $s1 -eq 0 ]; then
  echo "$LABEL: GREEN   size=$sz  stage1 exit=0  compiled=$nok"; exit 0
elif [ $s1 -ge 128 ]; then
  echo "$LABEL: FAULT   size=$sz  stage1 signal=$((s1-128))  compiled=$nok"
  echo "        NOTE: the runtime buffers stdout and flushes at exit, so the last line is"
  echo "        NOT where it died (F-168). last: $last"
  exit 1
else
  echo "$LABEL: FAILED  size=$sz  stage1 exit=$s1  compiled=$nok  last: $last"; exit 1
fi
