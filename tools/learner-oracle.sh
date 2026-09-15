#!/usr/bin/env bash
# tools/learner-oracle.sh: run a Little Learner chapter's oracle, oracle/learner/NAME.rkt,
# under Racket with malt (the book's own library, MIT; `raco pkg install --auto malt`),
# and keep its shown values, one per line, in oracle/learner/NAME.expected.
#
# Usage: tools/learner-oracle.sh ch01-the-lines-sleep-tonight
set -u
name="$1"
src="oracle/learner/$name.rkt"
out="oracle/learner/$name.expected"
raw=$(timeout -s KILL 600 racket "$src" 2>&1)
rc=$?
if [ $rc -ne 0 ]; then
  echo "learner-oracle: racket failed on $src (exit $rc):" >&2
  echo "$raw" >&2
  exit 1
fi
printf '%s\n' "$raw" | sed -n 's/^=> //p' > "$out"
echo "learner-oracle: $(wc -l < "$out") values -> $out"
