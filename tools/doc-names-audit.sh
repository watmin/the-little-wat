#!/usr/bin/env bash
# tools/doc-names-audit.sh — every :wat:: verb the user-facing docs name, checked against wat.
#
# The method is deliberately not "grep the stdlib and diff": a name can be a Rust intrinsic, a
# wat defn, a defmacro, or generated, so set membership proves nothing. Instead EVERY candidate
# is handed to the compiler on its own and classified by what the compiler says:
#
#   MISSING  "not a builtin, not a registered function"   (a resolution failure)
#   RETIRED  "... is retired; use ... instead"            (an explicit retirement)
#   EXISTS   anything else, including arity/type errors   (the name resolved)
#
# One name per run, because a bulk file stops at the first two type errors and masks the rest.
#
# Usage: tools/doc-names-audit.sh [path-to-wat-rs]     (default ../wat-rs)
set -uo pipefail
RS="${1:-../wat-rs}"
WAT="$RS/target/release/wat"
OUT="${TMPDIR:-/tmp}/doc-names-audit"
mkdir -p "$OUT"
DOCS="$RS/docs/USER-GUIDE.md $RS/docs/WAT-CHEATSHEET.md $RS/docs/CLOJURE-ROSETTA.md $RS/docs/README.md"

# Candidates: :wat::ns::verb tokens with a lowercase final segment, at least three segments,
# excluding prose placeholders (*, <, >) and the lowercase PRIMITIVE TYPES, which are not
# callable and would be false positives when tested as a call head.
grep -ohE ':wat(::[A-Za-z0-9_?!*<>=+-]+)+' $DOCS 2>/dev/null \
  | grep -E '::[a-z][A-Za-z0-9_?!*<>=+-]*$' \
  | grep -vE '\*|<|>' \
  | grep -E ':wat(::[^:]+){2,}' \
  | grep -vE ':wat::core::(bool|i64|f64|nil|keyword|true)$' \
  | sort -u > "$OUT/candidates.txt"

: > "$OUT/verdicts.tsv"
while read -r n; do
  printf '(:wat::core::defn :user::main [] -> :wat::core::nil\n  (:wat::core::do (%s) nil))\n' "$n" > "$OUT/one.wat"
  timeout -s KILL 30 "$WAT" "$OUT/one.wat" > /dev/null 2>"$OUT/one.err"
  rc=$?
  if   [ $rc -eq 0 ]; then v=EXISTS; d=""
  elif grep -q 'not a builtin, not a registered function' "$OUT/one.err"; then v=MISSING; d=""
  elif grep -q 'is retired' "$OUT/one.err"; then v=RETIRED; d=$(grep -o "is retired[^\"]*" "$OUT/one.err" | head -1 | cut -c1-120)
  else v=EXISTS; d=$(grep -o ':message "[^"]*"' "$OUT/one.err" | head -1 | cut -c11-80)
  fi
  printf '%s\t%s\t%s\n' "$v" "$n" "$d" >> "$OUT/verdicts.tsv"
done < "$OUT/candidates.txt"

# A name the docs mention ONLY to say it does not exist is the documentation being CORRECT.
# Counting those against it is a false positive -- 6 of 87 on the first run of this audit.
: > "$OUT/disclaimed.txt"
grep -E '^(MISSING|RETIRED)' "$OUT/verdicts.tsv" | cut -f2 | while read -r n; do
  lines=$(grep -hF "$n" $DOCS 2>/dev/null)
  total=$(printf '%s\n' "$lines" | grep -c .)
  clean=$(printf '%s\n' "$lines" | grep -vicE 'retired|no longer|does not exist|neither of which|removed|deprecated|not exist|previously named')
  [ "$total" -gt 0 ] && [ "$clean" -eq 0 ] && echo "$n" >> "$OUT/disclaimed.txt"
done

echo "candidates: $(wc -l < "$OUT/candidates.txt")"
cut -f1 "$OUT/verdicts.tsv" | sort | uniq -c | sort -rn
echo "named only to disclaim (not counted): $(wc -l < "$OUT/disclaimed.txt")"
echo "TAUGHT AND REJECTED: $(( $(grep -cE '^(MISSING|RETIRED)' "$OUT/verdicts.tsv") - $(wc -l < "$OUT/disclaimed.txt") )) of $(wc -l < "$OUT/candidates.txt")"
echo "full table: $OUT/verdicts.tsv"
