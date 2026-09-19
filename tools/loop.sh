#!/usr/bin/env bash
# tools/loop.sh: the iteration loop, once the compiler can build itself.
#
# Edit elf/compile.wat, run this, read three lines. It does the two checks that matter and
# neither of them touches the interpreter's 65-second compile:
#
#   * the FIXPOINT -- the compiler already in elf/out/ builds the new source to stage 2, stage 2
#     builds it again to stage 3, and stage 2 must equal stage 3. A code-generator change makes
#     stage 2 differ from the seed; that is expected. Stage 2 differing from stage 3 is the bug.
#   * the DIFFERENTIAL suite -- every program in elf/src/ run both ways, compiled and
#     interpreted, with the binaries as they now are rather than rebuilt.
#
# About a dozen seconds, against three to five minutes for the full path. Run
# `tools/bootstrap.sh` without --fast before committing: only that proves the chain still starts
# from source rather than from a binary nobody can read.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
s=$(date +%s%N)

tools/bootstrap.sh --fast || { echo "loop: the fixpoint failed -- stopping before the suite"; exit 1; }
echo
SKIP_BUILD=1 tools/elf-run.sh | tail -4
rc=${PIPESTATUS[0]}

echo
printf 'loop: %s in %s ms\n' "$( [ $rc -eq 0 ] && echo ok || echo FAILED )" \
       "$(( ($(date +%s%N) - s) / 1000000 ))"
exit $rc
