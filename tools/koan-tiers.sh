#!/usr/bin/env bash
# tools/koan-tiers.sh: every Clojure Koans row's tier, from the literal run and the idiom files.
#
# A row is one of:
#   literal  it ran with only its namespaces changed (koans/literal/NN-topic.tsv);
#   idiom    koans/idiom/NN-topic.wat asserts it the wat way (an assertion ending "; row K");
#   missing  there is no route in wat today, a gap (";; row K missing: ...");
#   refused  wat excludes it on purpose, a doctrine (";; row K refused: ...");
#   todo     none of these yet.
#
# Writes koans/tiers.tsv (topic, row, tier) and prints a summary per topic. Every idiom file
# must also pass (./run.sh runs them).
#
# Exit code: 0 when every row has exactly one tier; 1 when a row has none or two. Read it
# directly, not through a pipe.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

out=koans/tiers.tsv
printf 'topic\trow\ttier\n' > "$out"
bad=0
declare -A total=([rows]=0 [literal]=0 [idiom]=0 [missing]=0 [refused]=0 [todo]=0)
printf '%-28s %5s %8s %6s %8s %8s %5s\n' topic rows literal idiom missing refused todo

for src in koans/src/*.clj; do
  t=$(basename "$src" .clj)
  lit=koans/literal/$t.tsv
  idi=koans/idiom/$t.wat
  if [ ! -f "$lit" ]; then
    echo "koan-tiers: no $lit (run tools/koans.clj)"
    bad=1
    continue
  fi
  unset tier
  declare -A tier=()
  n=0
  while IFS=$'\t' read -r row verdict _; do
    n=$((n + 1))
    if [ "$verdict" = literal ]; then tier[$row]=literal; fi
  done < <(tail -n +2 "$lit")
  if [ -f "$idi" ]; then
    while read -r kind row; do
      if [ "$row" -gt "$n" ]; then
        echo "koan-tiers: $t row $row is marked $kind, but the topic has $n rows"
        bad=1
      elif [ -n "${tier[$row]:-}" ]; then
        echo "koan-tiers: $t row $row is both ${tier[$row]} and $kind"
        bad=1
      fi
      tier[$row]=$kind
    done < <(sed -nE 's/.*[^;]; row ([0-9]+)[[:space:]]*$/idiom \1/p; s/^[[:space:]]*;; row ([0-9]+) (missing|refused):.*/\2 \1/p' "$idi")
  fi
  unset c
  declare -A c=([literal]=0 [idiom]=0 [missing]=0 [refused]=0 [todo]=0)
  for ((k = 1; k <= n; k++)); do
    v=${tier[$k]:-todo}
    c[$v]=$((c[$v] + 1))
    printf '%s\t%s\t%s\n' "$t" "$k" "$v" >> "$out"
  done
  printf '%-28s %5s %8s %6s %8s %8s %5s\n' "$t" "$n" "${c[literal]}" "${c[idiom]}" "${c[missing]}" "${c[refused]}" "${c[todo]}"
  total[rows]=$((total[rows] + n))
  for v in literal idiom missing refused todo; do total[$v]=$((total[$v] + c[$v])); done
done

echo "---"
printf '%-28s %5s %8s %6s %8s %8s %5s\n' total "${total[rows]}" "${total[literal]}" "${total[idiom]}" "${total[missing]}" "${total[refused]}" "${total[todo]}"
if [ "${total[todo]}" -gt 0 ]; then bad=1; fi
exit "$bad"
