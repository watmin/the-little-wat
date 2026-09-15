#!/usr/bin/env bash
# tools/pie-oracle-refusals.sh: run Racket's Pie (AGPL-3.0, run as a black box, never copied)
# on a chapter's refusals file, and write Pie's verdict on each case, so wat-Pie can be
# held to refuse what Pie refuses. A checker that accepts a wrong program fails silently;
# the results files (tools/pie-oracle.sh) only ever show what was accepted.
#
# A refusals file is #lang pie, then cases separated by blank lines. A case is one form per
# line (;; comments allowed); its last form is the one that must be refused, and the forms
# before it are setup, which must be accepted. Pie stops at the first error, so each case
# runs on its own twice: without its last form (must succeed) and with it (must fail).
#
# Output: one line per case, "refused: <Pie's message>", in oracle/typer/NAME.expected.
# Usage: tools/pie-oracle-refusals.sh books/little-typer/ch04-easy-as-pie-refusals.pie
set -u
src="$1"
name=$(basename "$src" .pie)
out="oracle/typer/$name.expected"
mkdir -p oracle/typer
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Split into cases: each paragraph's non-comment, non-blank lines, #lang dropped.
awk -v dir="$work" '
  NR == 1 && /^#lang/ { next }
  /^[[:space:]]*$/ { if (n > 0) { k++; n = 0 } next }
  /^[[:space:]]*;/ { next }
  { f = sprintf("%s/case%03d", dir, k); print >> f; close(f); n++ }
' "$src"

: > "$out"
count=0
for c in "$work"/case*; do
  count=$((count + 1))
  printf '#lang pie\n' > "$work/setup.pie"
  head -n -1 "$c" >> "$work/setup.pie"
  printf '#lang pie\n' > "$work/full.pie"
  cat "$c" >> "$work/full.pie"
  (cd "$work" && timeout -s KILL 300 racket setup.pie > setup.out 2>&1)
  rc=$?
  if [ $rc -ne 0 ]; then
    echo "pie-oracle-refusals: case $count's setup was refused (exit $rc):" >&2
    cat "$c" "$work/setup.out" >&2
    exit 1
  fi
  (cd "$work" && timeout -s KILL 300 racket full.pie > full.out 2> full.err)
  rc=$?
  if [ $rc -eq 0 ]; then
    echo "pie-oracle-refusals: case $count was accepted, not refused:" >&2
    cat "$c" "$work/full.out" >&2
    exit 1
  fi
  # Pie's message is every stderr line before "location...:", pretty-printed types and all;
  # joined to one line with the ASCII spellings, as tools/pie-oracle.sh does.
  msg=$(awk '/^[[:space:]]*location\.\.\.:/ { exit } { print }' "$work/full.err" | tr '\n' ' ' \
    | sed -e 's/→/->/g' -e 's/λ/lambda/g' -e 's/Π/Pi/g' -e 's/Σ/Sigma/g' \
          -e 's/[[:space:]][[:space:]]*/ /g' -e 's/( /(/g' -e 's/ )/)/g' -e 's/^ //' -e 's/ $//')
  printf 'refused: %s\n' "$msg" >> "$out"
done
echo "pie-oracle-refusals: $count cases refused -> $out"
