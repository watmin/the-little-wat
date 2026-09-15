#!/usr/bin/env bash
# tools/sicp-oracle.sh: run a chapter's Scheme oracle, oracle/sicp/NAME.scm (our own Scheme on
# the section's topic, not the book's text), and keep its results, one per line, in
# oracle/sicp/NAME.expected. A result is a line the program prints after "=> ".
#
# Usage: tools/sicp-oracle.sh ch31-local-state      (needs guile)
set -u
name="$1"
src="oracle/sicp/$name.scm"
out="oracle/sicp/$name.expected"
raw=$(timeout -s KILL 300 guile --no-auto-compile "$src" 2>&1)
rc=$?
if [ $rc -ne 0 ]; then
  echo "sicp-oracle: guile failed on $src (exit $rc):" >&2
  echo "$raw" >&2
  exit 1
fi
printf '%s\n' "$raw" | sed -n 's/^=> //p' > "$out"
echo "sicp-oracle: $(wc -l < "$out") results -> $out"
