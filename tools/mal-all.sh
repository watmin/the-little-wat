#!/usr/bin/env bash
# tools/mal-all.sh: every Make-a-Lisp step against mal's own tests (tools/mal-test.sh), in order,
# with one summary line each.
#
# Step 5's tests recur 10000 deep, and a mal call costs about 3 ms here (FINDINGS F-051), so every
# step runs with runtest's per-test timeout raised to 300 s.
#
# Exit code: 0 when every step passes all its hard tests; 1 otherwise. Read it directly, not
# through a pipe.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

steps="step0_repl step1_read_print step2_eval step3_env step4_if_fn_do step5_tco step6_file step7_quote step8_macros step9_try stepA_mal"
fail=0
for st in $steps; do
  start=$(date +%s)
  out="$(tools/mal-test.sh "$st" --continue-after-fail --test-timeout 300 2>&1)"
  rc=$?
  secs=$(( $(date +%s) - start ))
  passing=$(printf '%s\n' "$out" | sed -nE 's/^ +([0-9]+): passing tests/\1/p')
  failing=$(printf '%s\n' "$out" | sed -nE 's/^ +([0-9]+): failing tests/\1/p')
  soft=$(printf '%s\n' "$out" | sed -nE 's/^ +([0-9]+): soft failing tests/\1/p')
  verdict=PASS
  if [ "$rc" -ne 0 ]; then verdict=FAIL; fail=1; fi
  printf '%-18s %s  passing %4s  failing %s  soft-failing %2s  (%s s)\n' "$st" "$verdict" "${passing:-?}" "${failing:-?}" "${soft:-?}" "$secs"
done
exit "$fail"
