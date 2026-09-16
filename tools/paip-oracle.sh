#!/usr/bin/env bash
# tools/paip-oracle.sh: run a chapter's Scheme oracle, oracle/paip/NAME.scm (our own Scheme on
# the chapter's topic, written from the algorithm — Norvig's own code is not read or copied),
# and keep its results, one per line, in oracle/paip/NAME.expected. A result is a line the
# program prints after "=> ".
#
# Scheme is the oracle here rather than Clojure because PAIP's unifier works on quoted
# S-expressions, where a variable is the symbol ?x. Guile keeps them that way.
#
# Usage: tools/paip-oracle.sh ch11-unification      (needs guile)
set -u
name="$1"
src="oracle/paip/$name.scm"
out="oracle/paip/$name.expected"
raw=$(timeout -s KILL 300 guile --no-auto-compile "$src" 2>&1)
rc=$?
if [ $rc -ne 0 ]; then
  echo "paip-oracle: guile failed on $src (exit $rc):" >&2
  echo "$raw" >&2
  exit 1
fi
printf '%s\n' "$raw" | sed -n 's/^=> //p' > "$out"
echo "paip-oracle: $(wc -l < "$out") results -> $out"
