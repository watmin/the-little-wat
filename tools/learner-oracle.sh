#!/usr/bin/env bash
# tools/learner-oracle.sh: run a Little Learner chapter's oracle, oracle/learner/NAME.rkt,
# under Racket with malt (the book's own library, MIT; `raco pkg install --auto malt`),
# and keep its shown values, one per line, in oracle/learner/NAME.expected (and any
# recorded random draws in oracle/learner/NAME.draws).
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
# Random draws malt will make, recorded ahead of time (see oracle/learner/show.rkt's
# record-draws), one batch of numbers per line, replayed by the wat side.
draws="oracle/learner/$name.draws"
if printf '%s\n' "$raw" | grep -q '^draws=> '; then
  printf '%s\n' "$raw" | sed -n 's/^draws=> //p' > "$draws"
  echo "learner-oracle: $(wc -l < "$draws") draw lines -> $draws"
fi
# Data malt holds that the wat side needs as input (a data set, a fixed theta), printed in
# the same canonical form as the values (show-data), one per line.
data="oracle/learner/$name.data"
if printf '%s\n' "$raw" | grep -q '^data=> '; then
  printf '%s\n' "$raw" | sed -n 's/^data=> //p' > "$data"
  echo "learner-oracle: $(wc -l < "$data") data lines -> $data"
fi
