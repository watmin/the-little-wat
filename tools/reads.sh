#!/usr/bin/env bash
# tools/reads.sh -- is every read OUT OF A CONTAINER still going through `:c::read-out`?
#
# F-188: a pointer read out of a Vector, a record or a payload variant keeps count 1, so unless
# the read counts it, `vec_conj_own` / `str_cat_own` extend it in place while the container
# still holds it -- a silent wrong answer. Stone 0 counted at three sites by hand; stone 0a made
# `:c::read-out` the one function that emits such a read and counts it by construction. What no
# construction in this dialect can stop is a NEW verb -- a map `get` -- that emits its load, or
# calls its runtime routine, without mentioning `:c::read-out`. This is the check for that:
#
#   1. every heap-load SPELLING in elf/compile.wat is inside `:c::read-out`, or is one of the
#      named, COUNTED exceptions below (a new use of an allowed spelling raises its count and
#      fails too);
#   2. every runtime entry the compiler calls, `(:c::at-NAME rt)`, is classified here. An entry
#      that answers a value a container holds may appear only as a `:c::Read.*` argument. An
#      unclassified entry fails: whoever adds `map_get` has to come here and say which it is;
#   3. `:c::read-out` still emits the count, and `:c::count-hex` has exactly its two callers.
#
# Fail-closed on purpose: a reformatted line fails this rather than slipping past it.
# Exit: 0 clean, 1 a read that bypasses `:c::read-out` (or an unclassified entry).
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
F=elf/compile.wat
fail=0

# code only: comments dropped, line numbers kept
code=$(sed 's/;;.*//' "$F" | nl -ba -w1 -s: )
start=$(grep -n '^(:wat::core::defn :c::read-out ' "$F" | cut -d: -f1)
[ -n "$start" ] || { echo "reads: FAIL -- no :c::read-out in $F"; exit 1; }
end=$(awk -v s="$start" 'NR>s && /^\(/ {print NR-1; exit}' "$F")
inside () { [ "$1" -ge "$start" ] && [ "$1" -le "$end" ]; }

# ---- 1. heap-load spellings outside :c::read-out
# `:c::load` (no -at) is a FRAME slot and `480fb6c0` is movzx rax,al -- neither reads the heap.
LOADS=':c::load-at|:c::mov-rm|:c::movzb|"4[89cd]8b|0fb6[0-9a-b]'
# pattern | how many times it may appear outside read-out | why it is not a counted read
ALLOW=(
  '"488b00"|2|`peek` (a raw machine word) and `length` (the header): both answer i64'
  '"488b0424"|1|`wait`: the status word is on the STACK, not in a heap object'
  '(:c::movzb-sib sr ir)|1|`code-point-at`: a byte, i64'
  '"480fb6440808"|1|`code-point-at`: a byte, i64'
  '(:c::load-at 8)|1|`match` tier 3: slot 0 is the TAG, i64'
  '(:c::mov-rm r d r)|1|`scalar-bytes`: the prologue of a scalarised record parameter. The register IS the field, and every use of it is an accessor, counted by read-out'"'"'s :Reg arm'
)
hits=$(echo "$code" | grep -E "$LOADS" | grep -vE '0fb6c0')
while IFS= read -r h; do
  [ -z "$h" ] && continue
  n=${h%%:*}; inside "$n" && continue
  ok=0
  for a in "${ALLOW[@]}"; do pat=${a%%|*}; case "$h" in *"$pat"*) ok=1 ;; esac; done
  [ $ok -eq 1 ] || { echo "reads: FAIL -- a heap load outside :c::read-out, $F:$n"; echo "      ${h#*:}"; fail=1; }
done <<< "$hits"
for a in "${ALLOW[@]}"; do
  pat=${a%%|*}; rest=${a#*|}; want=${rest%%|*}
  got=$(echo "$hits" | while IFS= read -r h; do n=${h%%:*}; inside "$n" || echo "$h"; done | grep -cF -- "$pat")
  [ "$got" -eq "$want" ] || { echo "reads: FAIL -- '$pat' appears $got times outside :c::read-out, allowed $want"
                               echo "      (${rest#*|})"; fail=1; }
done

# ---- 2. runtime entries, classified
# READS: answers a value a container still holds -- only ever a :c::Read.* argument
READS=' tget '
# the rest answer something FRESH, the container ITSELF, a scalar, or nothing
NOTREAD=' flush subs starts contains tostr die wrhex rdfile rdhex vconj vconj-own streq quot rem ovf '
NOTREAD+='cat cat-own slot slot-own varr vnew str bool put i64 '
while IFS= read -r h; do
  [ -z "$h" ] && continue
  n=${h%%:*}
  for e in $(echo "$h" | grep -oE '\(:c::at-[a-z0-9-]+ rt\)' | sed -E 's/\(:c::at-(.*) rt\)/\1/'); do
    if [[ "$READS" == *" $e "* ]]; then
      # as a FIELD of a `:c::Read` variant -- `{:tget (:c::at-tget rt)}` -- and never called
      echo "$h" | grep -qE "\(:c::Read\.[A-Za-z]+ \{:[a-z]+ \(:c::at-$e rt\)\}\)" || inside "$n" || {
        echo "reads: FAIL -- runtime entry '$e' answers a held value, but $F:$n does not hand it to :c::read-out"
        echo "      ${h#*:}"; fail=1; }
    elif [[ "$NOTREAD" != *" $e "* ]]; then
      echo "reads: FAIL -- runtime entry '$e' ($F:$n) is not classified. If it answers a value a"
      echo "      container still holds (a map \`get\`), it is a read: give it a :c::Read variant and"
      echo "      add it to READS here. Otherwise add it to NOTREAD, with the reason in the commit."
      fail=1
    fi
  done
done <<< "$(echo "$code" | grep -E '\(:c::at-[a-z0-9-]+ rt\)')"

# ---- 3. the count is still there, and still one spelling
echo "$code" | awk -F: -v s="$start" -v e="$end" '$1>=s && $1<=e' | grep -q '(:c::count-hex t pg)' \
  || { echo "reads: FAIL -- :c::read-out no longer emits :c::count-hex"; fail=1; }
callers=$(echo "$code" | grep -c '(:c::count-hex ')
[ "$callers" -eq 2 ] || { echo "reads: FAIL -- :c::count-hex has $callers callers, expected 2 (:c::share, :c::read-out)"; fail=1; }

[ $fail -eq 0 ] && echo "reads: ok -- every read out of a container goes through :c::read-out (lines $start-$end)"
exit $fail
