#!/usr/bin/env bash
# tools/euler-oracle.sh: run a problem's reference implementation, oracle/euler/NAME.clj (our own
# Clojure, solving the same problem the wat solution solves), and keep its answers, one per
# line, in oracle/euler/NAME.expected. An answer is a line the program prints after "=> ".
#
# Project Euler's problem statements are not reproduced here; each wat file states the problem
# in its own words. The answers are the point, and both implementations are our own.
#
# Clojure rather than guile because these problems lean on arbitrary-precision integers, and
# Clojure's bigints are the closest thing to what wat claims to have.
#
# Usage: tools/euler-oracle.sh p16-power-digits      (needs the clojure CLI)
set -u
name="$1"
src="oracle/euler/$name.clj"
out="oracle/euler/$name.expected"
raw=$(timeout -s KILL 600 clojure -M "$src" 2>&1)
rc=$?
if [ $rc -ne 0 ]; then
  echo "euler-oracle: clojure failed on $src (exit $rc):" >&2
  echo "$raw" >&2
  exit 1
fi
printf '%s\n' "$raw" | sed -n 's/^=> //p' > "$out"
echo "euler-oracle: $(wc -l < "$out") answers -> $out"
