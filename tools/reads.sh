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
#   3. `:c::read-out` still emits the count, and `:c::count-hex` has its six callers.
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
LOADS=':c::load-at|:c::mov-rm|:c::movzb|:c::rm "8b"|"4[89cd]8b|0fb6[0-9a-b]'
# pattern | how many times it may appear outside read-out | why it is not a counted read
ALLOW=(
  '"488b00"|2|`peek` (a raw machine word) and `length` (the header): both answer i64'
  '"488b0424"|1|`wait`: the status word is on the STACK, not in a heap object'
  '(:c::movzb-sib sr ir)|1|`code-point-at`: a byte, i64'
  '"480fb6440808"|1|`code-point-at`: a byte, i64'
  '(:c::load-at 8)|1|`match` tier 3: slot 0 is the TAG, i64'
  '(:c::mov-rm r d r)|1|`scalar-bytes`: the prologue of a scalarised record parameter. The register IS the field, and every use of it is an accessor, counted by read-out'"'"'s :Reg arm'
  '(:c::mov-rm (:c::rsp)|1|the entry stub: totalram from the sysinfo struct on the stack, not a container'
  '(:c::mov-rm32 (:c::rsp)|1|the entry stub: mem_unit, a u32 in that same stack struct'
  # excursus 008 stone 3b-1 round 3 (G1): every load below is inside a drop-GLUE routine, reading
  # a field OF THE OBJECT THAT IS DYING so it can be dropped in turn -- the field's one reference
  # is being given back, never duplicated, so none of these is the F-188 shape :c::read-out
  # guards against (a read that keeps a NEW reference while the container still holds its own).
  '(:c::mov-rm (:c::rbx) (:wat::core::+ 8 (:wat::core::* 8 i)) (:c::rax))|1|:c::rec-glue-fields: a record field read to be dropped as the record dies'
  '(:c::mov-rm (:c::rbx) (:wat::core::+ 8 (:wat::core::* 8 (:wat::core::+ j 1)))|1|:c::henum-glue-drop-fields: a payload field read to be dropped as the payload dies'
  '(:c::mov-rm (:c::rbx) 8 (:c::rax))|1|:c::henum-glue-body: the tag at slot 0, i64, not a reference'
  '(:c::mov-rm (:c::rbx) 8 (:c::rdx))|1|:c::vec-glue-body: a trie Vector'"'"'s shift, i64, not a reference'
  '(:c::mov-rm (:c::rbx) 16 (:c::rax))|1|:c::vec-glue-body: the root node, read to drop it (its own count, not the Vector'"'"'s) as the Vector dies'
  # excursus 008 stone 3b-2 (F1/F2): every load below is inside a FREE routine, reading a
  # header field OF THE OBJECT BEING FREED (its length, or a closure'"'"'s code address) to
  # recompute the block'"'"'s size -- never a reference handed anywhere, so none of these is the
  # F-188 shape either.
  '(:c::mov-rm (:c::rax) 0 (:c::rdx))|1|:c::freestr-glue-body: a String'"'"'s length, read to size `:c::rt-cap` recomputes'
  '(:c::mov-rm (:c::rax) 0 (:c::r8))|2|:c::freerec-glue-body and :c::freevec-glue-body: a record/payload-enum'"'"'s or a flat Vector'"'"'s length, read to size `len*8+16`/`len*8+24`'
  '(:c::mov-rm (:c::rax) 0 (:c::r9))|1|:c::closize-glue-body: a closure'"'"'s code address (its length word, overwritten) -- not a field value, the lookup key for its own creation site'"'"'s capture count'
  '(:c::mov-rm (:c::r11) 0 (:c::r8))|1|:c::free-tail-emit: a free list'"'"'s head, read from the allocator'"'"'s own table (reached from r14) to link a dead block onto it -- not a read out of a container'
  # excursus 008 M2 census: the exit report reads its own counters out of the allocator
  # header at r14. Those words are i64s the program stored about itself, not a reference
  # taken out of a Vector, a record, or a payload variant.
  '(:c::mov-rm (:c::r14) disp (:c::rax))|1|:c::census-line: one census counter from the allocator header, an i64, not a container field'
  # excursus 008 stone 3b-3a: pend reads the worklist head out of the allocator header, and the
  # pending word out of a dead object'"'"'s count slot, to learn which body to run. Neither is a
  # reference taken from a container that still holds it.
  '(:c::mov-rm (:c::r14) (:c::hdr-wl-head) (:c::r8))|1|:c::pend-glue-body: the worklist head, an address in the allocator header'
  '(:c::mov-rm (:c::r14) (:c::hdr-wl-head) (:c::rax))|1|:c::pend-glue-body: the worklist head again, popped so the drain can walk it'
  '(:c::mov-rm (:c::rax) -8 (:c::r9))|1|:c::pend-glue-body: the pending word in the dead object count slot, decoded into k and next'
  # F-212: the census report reads the high-water word out of the allocator header. It is the
  # greatest bump pointer, not a reference taken from a container.
  '(:c::mov-rm (:c::r14) (:c::hdr-census-hiwater) (:c::rax))|1|:c::census-hiwater: the stored high-water bump pointer'
  # excursus 008 M2 census R2: the site table is the allocator header too. Each load is an
  # i64 the program stored about itself (a function address, a byte count, a name length).
  '(:c::mov-rm (:c::r9) src-disp (:c::r10))|1|:c::census-copy-word: one word of the site blob, an i64, into the allocator header'
  '(:c::mov-rm (:c::r11) 0 (:c::r11))|1|:c::census-load-r11: a site address or a live-byte count, an i64'
  '(:c::mov-rm (:c::r14) (:c::census-site-n) (:c::r10))|1|:c::census-load-n: how many functions the site table holds, an i64'
  '(:c::mov-rm32 (:c::r10) -8 (:c::r8))|1|:c::free-tail-emit: the allocating function index, the low 32 bits of the site word, an i64'
  '(:c::mov-rm (:c::r9) 0 (:c::rbx))|2|:c::census-sites and :c::census-holds: the byte length of a name in the census blob, an i64'
  '(:c::mov-rm (:c::r14) (:c::census-unmapped-live) (:c::r13))|1|:c::census-sites: bytes still charged to an unnamed caller, an i64'
  # `:c::rm "8b"` is a scaled heap load. The two in the vector glue read an element of the
  # vector being freed; the one in the owning assoc reads the field it is about to overwrite.
  # None of them keeps a new reference while the container still holds its own.
  '(:c::rm "8b" (:c::rax) (:c::rbx) (:c::r12)|2|:c::vec-glue-body: an element of the vector being freed, read to be dropped'
  '(:c::rm "8b" (:c::rax) (:c::rax) (:c::rcx)|1|:c::assoc-form owning path: the old pointer field, read to be dropped as the slot is overwritten'
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
NOTREAD+='cat cat-own slot slot-own varr vnew str bool put i64 drop1 '
# uflow (excursus 008 stone 3a round 8, R18): the check build's underflow abort -- it answers
# nothing a container holds; it is reached instead of `ud2` and ends the process. Not a read.
NOTREAD+='uflow '
# range (excursus 008 stone 3b-3a round 2): the worklist's 2^47 stop. It answers nothing a
# container holds; it names the address and exits 70.
NOTREAD+='range '
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
#
# excursus 008 stone 3b-1 (G5): `:c::count-hex` grew an `rt <- :c::Layout` parameter (the
# increment's own poison check needs `:c::at-uflow rt`), so `:c::read-out`'s call is now
# `(:c::count-hex t pg lo rt)`, not `(:c::count-hex t pg)`. The pattern follows the call, not
# the other way around.
echo "$code" | awk -F: -v s="$start" -v e="$end" '$1>=s && $1<=e' | grep -q '(:c::count-hex t pg lo rt)' \
  || { echo "reads: FAIL -- :c::read-out no longer emits :c::count-hex"; fail=1; }
callers=$(echo "$code" | grep -c '(:c::count-hex ')
# 3: share, read-out, and the copying conj, which takes one reference to its source
[ "$callers" -eq 6 ] || { echo "reads: FAIL -- :c::count-hex has $callers callers, expected 6 (:c::share, :c::read-out, copying conj, copying concat, copying assoc twice)"; fail=1; }

[ $fail -eq 0 ] && echo "reads: ok -- every read out of a container goes through :c::read-out (lines $start-$end)"
exit $fail
