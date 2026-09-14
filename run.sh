#!/usr/bin/env bash
# run.sh: run every chapter program under books/ with the wat binary and report each.
#
# A chapter passes when `wat <file>` exits 0. Its checks are wat.test/assert-eq calls that
# stop the program at the first failure and say where (FINDINGS.md, C-002).
#
# WAT overrides the binary. The default is the release build in ../wat-rs; rebuild it
# there with `cargo build --release` after pulling wat-rs.
#
# Exit code: 0 when every chapter passes; 1 when any fails; 2 when no chapter was found or
# there is no binary. Read it directly, not through a pipe.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 2

WAT="${WAT:-../wat-rs/target/release/wat}"
if [ ! -x "$WAT" ]; then
  echo "run.sh: no wat binary at $WAT (build ../wat-rs with: cargo build --release)"
  exit 2
fi

pass=0
fail=0
while IFS= read -r f; do
  out="$("$WAT" "$f" 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    pass=$((pass + 1))
    echo "PASS  $f"
  else
    fail=$((fail + 1))
    echo "FAIL  $f  (exit $rc)"
    printf '%s\n' "$out" | sed 's/^/      /'
  fi
done < <(find books -name '*.wat' | sort)

echo "---"
echo "$pass passed, $fail failed"

# Zero chapters found must not read as "all passed".
if [ $((pass + fail)) -eq 0 ]; then
  echo "run.sh: no chapter programs found under books/"
  exit 2
fi
[ "$fail" -eq 0 ]
