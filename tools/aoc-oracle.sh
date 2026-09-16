#!/usr/bin/env bash
# tools/aoc-oracle.sh: run a puzzle's reference implementation, oracle/aoc/NAME.clj (our own
# Clojure, reading the same input file the wat solution reads), and keep its answers, one per
# line, in oracle/aoc/NAME.expected. An answer is a line the program prints after "=> ".
#
# The puzzles are our own, in Advent of Code's shape: an input file, and two answers from it.
# Advent of Code's own texts and inputs are not redistributable, so none are here.
#
# Usage: tools/aoc-oracle.sh day01-sonar      (needs the clojure CLI)
set -u
name="$1"
src="oracle/aoc/$name.clj"
out="oracle/aoc/$name.expected"
raw=$(timeout -s KILL 600 clojure -M "$src" 2>&1)
rc=$?
if [ $rc -ne 0 ]; then
  echo "aoc-oracle: clojure failed on $src (exit $rc):" >&2
  echo "$raw" >&2
  exit 1
fi
printf '%s\n' "$raw" | sed -n 's/^=> //p' > "$out"
echo "aoc-oracle: $(wc -l < "$out") answers -> $out"
