#!/usr/bin/env bash
# run.sh: run every chapter program under books/ with the wat binary and report each.
#
# A chapter passes when `wat <file>` exits 0. Its checks are wat.test/assert-eq calls that
# stop the program at the first failure and say where (FINDINGS.md, C-002).
#
# Each line shows the chapter's wall time, which covers wat's startup (parse, check and
# freeze of the stdlib) plus the chapter itself. With RECORD=1, each chapter is also
# appended to timings.tsv (date, wat-rs commit, file, ms, exit), so interpreted-era
# numbers stay on disk for later comparison with a compiled wat.
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
WAT_REV="$(git -C ../wat-rs rev-parse --short HEAD 2>/dev/null || echo unknown)"
if [ -n "${RECORD:-}" ] && [ ! -f timings.tsv ]; then
  printf 'utc\twat_rs\tfile\tms\texit\n' > timings.tsv
fi

pass=0
fail=0
while IFS= read -r f; do
  start=$(date +%s%N)
  out="$("$WAT" "$f" 2>&1)"
  rc=$?
  ms=$(( ($(date +%s%N) - start) / 1000000 ))
  if [ "$rc" -eq 0 ]; then
    pass=$((pass + 1))
    echo "PASS  $f  (${ms} ms)"
  else
    fail=$((fail + 1))
    echo "FAIL  $f  (exit $rc, ${ms} ms)"
    printf '%s\n' "$out" | sed 's/^/      /'
  fi
  if [ -n "${RECORD:-}" ]; then
    printf '%s\t%s\t%s\t%s\t%s\n' "$(date -u +%FT%TZ)" "$WAT_REV" "$f" "$ms" "$rc" >> timings.tsv
  fi
done < <(find books -name '*.wat' -not -path '*/lib/*' | sort)   # lib/ files are definitions only, no main

echo "---"
echo "$pass passed, $fail failed  (wat-rs $WAT_REV)"

# Zero chapters found must not read as "all passed".
if [ $((pass + fail)) -eq 0 ]; then
  echo "run.sh: no chapter programs found under books/"
  exit 2
fi
[ "$fail" -eq 0 ]
