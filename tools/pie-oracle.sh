#!/usr/bin/env bash
# tools/pie-oracle.sh: run Racket's Pie (the reference implementation for The Little Typer,
# installed with `raco pkg install pie`; AGPL-3.0, run as a black box, never copied) on a
# chapter's .pie file, and write one normalized result per line, so wat-Pie's output can
# be compared string for string.
#
# Normalizing: Pie pretty-prints each (the TYPE VALUE) over indented lines, with unicode
# (→ λ Π Σ) and 'atom quotes. Here each result becomes one line, whitespace collapsed, with
# the ASCII spellings Pie also accepts (-> lambda Pi Sigma) and (quote atom). wat's lexer
# does not read λ Π Σ → (F-032).
#
# Usage: tools/pie-oracle.sh books/little-typer/ch01-the-more-things-change.pie
#        writes oracle/typer/ch01-the-more-things-change.expected
set -u
src="$1"
name=$(basename "$src" .pie)
out="oracle/typer/$name.expected"
mkdir -p oracle/typer
raw=$(cd "$(dirname "$src")" && timeout -s KILL 300 racket "$(basename "$src")" 2>&1)
rc=$?
if [ $rc -ne 0 ]; then
  echo "pie-oracle: racket failed on $src (exit $rc):" >&2
  echo "$raw" >&2
  exit 1
fi
printf '%s\n' "$raw" \
  | awk 'NR > 1 && /^[^ ]/ { print line; line = "" } { sub(/^ +/, " "); line = line $0 } END { if (line != "") print line }' \
  | sed -e 's/→/->/g' -e 's/λ/lambda/g' -e 's/Π/Pi/g' -e 's/Σ/Sigma/g' \
        -e "s/'\\([A-Za-z0-9!?*<>=\\/+-]*\\)/(quote \\1)/g" \
        -e 's/  */ /g' -e 's/( /(/g' -e 's/ )/)/g' \
  > "$out"
echo "pie-oracle: $(wc -l < "$out") results -> $out"
