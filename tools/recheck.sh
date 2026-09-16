#!/usr/bin/env bash
# tools/recheck.sh — NEXT.md §8. Re-check findings against a build and report what changed.
#
# A probe DOCUMENTS a defect: it passes while the defect is present, so "did the probe pass?" is
# the wrong question. Each check here is instead a minimal program plus the VERDICT expected while
# the finding is open. When a verdict flips, the finding's status changed — that is the signal.
#
#   OPEN   the finding still reproduces
#   FIXED  it no longer reproduces — go read the finding and close it
#   ?      the check itself failed to run
#
# Usage: tools/recheck.sh [path-to-wat-rs]
set -uo pipefail
RS="${1:-../wat-rs}"; WAT="$RS/target/release/wat"
T="${TMPDIR:-/tmp}/wat-recheck"; mkdir -p "$T"
open=0; fixed=0; unknown=0

# run <source> -> sets RC, OUT, ERR
run () { printf '%s\n' "$1" > "$T/c.wat"
         timeout -s KILL 120 "$WAT" "$T/c.wat" > "$T/c.out" 2> "$T/c.err"; RC=$?
         OUT=$(cat "$T/c.out"); ERR=$(cat "$T/c.err"); }

report () { # id, verdict, note
  case "$2" in
    OPEN)  open=$((open+1));;
    FIXED) fixed=$((fixed+1));;
    *)     unknown=$((unknown+1));;
  esac
  printf '  %-7s %-6s %s\n' "$1" "$2" "$3"
}

echo "=== re-checking findings against $RS ($(git -C "$RS" rev-parse --short HEAD 2>/dev/null || echo unknown)) ==="

# F-031 — (length <a String>) passes the checker and dies at runtime
run '(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:wat::core::length "abc")))'
if [ "$RC" -ne 0 ] && grep -q 'RuntimeError' "$T/c.err"; then report F-031 OPEN "length on a String still reaches runtime"
elif [ "$RC" -ne 0 ]; then report F-031 FIXED "now refused before running"
else report F-031 FIXED "length on a String now succeeds"; fi

# F-045 — first on an empty collection dies
run '(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:wat::core::first (:wat::core::Vector :- [:wat::core::i64]))))'
[ "$RC" -ne 0 ] && report F-045 OPEN "first of an empty Vector still fails" || report F-045 FIXED "first is total now"

# F-058 — a PersistentMap constructor refuses a nested bracketed type
run '(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:wat::core::length
    (:wat::core::PersistentMap :- [:wat::core::i64 (:wat::core::PersistentVector :- [:wat::core::i64])]))))'
[ "$RC" -ne 0 ] && report F-058 OPEN "nested bracketed type still refused" || report F-058 FIXED "nesting accepted"

# F-080 — filterv has no PersistentVector clause
run '(:wat::core::defn :u::odd? [x <- :wat::core::i64] -> :wat::core::bool (:wat::core::= x 1))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:wat::core::length (:wat::core::filterv :u::odd?
    (:wat::core::PersistentVector :- [:wat::core::i64] 1 2 3)))))'
[ "$RC" -ne 0 ] && report F-080 OPEN "filterv still refuses a PersistentVector" || report F-080 FIXED "filterv accepts one"

# F-088 — :wat::stream::collect does not exist
run '(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do (:wat::stream::collect 1) nil))'
grep -q 'not a builtin, not a registered function' "$T/c.err" \
  && report F-088 OPEN "stream::collect still unresolved" || report F-088 FIXED "stream::collect resolves"

# F-090 — rational arithmetic returns a bigint it did not declare
run '(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:wat::edn::write (:wat::rational::to-f64 (:wat::rational::+ 1/2 1/2)))))'
if grep -q 'expected rational, got wat::core::bigint' "$T/c.err"; then report F-090 OPEN "to-f64 still dies on a collapsed rational"
elif [ "$RC" -eq 0 ]; then report F-090 FIXED "to-f64 absorbs the collapse"
else report F-090 "?" "different failure: $(head -c 60 "$T/c.err")"; fi

# F-093 — a wrongly-typed argument at a Clojure-spelled call is not checked
run '(wat.core/defn bad/ident [n :- wat.type/i64] :- wat.type/i64 n)
(wat.core/defn user/main [] :- wat.type/nil (wat.kernel/println (wat.edn/write (bad/ident "a String"))))'
[ "$RC" -eq 0 ] && report F-093 OPEN "clojure call site still unchecked (ran, exit 0)" \
                || report F-093 FIXED "the call is type-checked now"

# F-083 — re-putting a key into a HolographicLru deletes it
run '(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [h (:wat::cache::HolographicLru::new (:wat::holon::filter-accept-any) 8)
                    k (:wat::holon::leaf "a")
                    _1 (:wat::cache::HolographicLru::put h k (:wat::holon::leaf "v1"))
                    _2 (:wat::cache::HolographicLru::put h k (:wat::holon::leaf "v2"))]
    (:wat::kernel::println (:wat::cache::HolographicLru::len h))))'
case "$OUT" in *0*) report F-083 OPEN "a re-put still empties the cache (len 0)";;
               *1*) report F-083 FIXED "len is 1 after a re-put";;
               *)   report F-083 "?" "unexpected: $OUT";; esac

# F-089 — no --help; every unknown flag is read as a filename
timeout -s KILL 30 "$WAT" --help >/dev/null 2>"$T/h.err"; hrc=$?
grep -q 'No such file or directory' "$T/h.err" && report F-089 OPEN "--help still read as a filename (exit $hrc)" \
  || report F-089 FIXED "--help does something"

# F-085 — the guide's mandated Uuid/v4 is retired
run '(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:wat::uuid::to-string (:wat::core::Uuid/v4))))'
grep -q 'is retired' "$T/c.err" && report F-085 OPEN "Uuid/v4 still retired (the guide still mandates it)" \
  || report F-085 FIXED "Uuid/v4 resolves"

# F-096 — a defrecord accessor costs multiples of a defstruct accessor.
# The body repeats the read 10x for the same reason bench/lib/timer.wat does: with one op per
# iteration the ~3.6 us loop overhead compresses a real 5.0x down to 2.15x, and this check
# reported FIXED the first time it ran.
run '(:wat::core::defrecord :r::R [v <- :wat::core::i64])
(:wat::core::defstruct :r::S [v <- :wat::core::i64])
(:wat::core::defn :r::gr [n <- :wat::core::i64 b <- :r::R] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0) 0 (:wat::core::do (:r::R/v b) (:r::R/v b) (:r::R/v b) (:r::R/v b) (:r::R/v b) (:r::R/v b) (:r::R/v b) (:r::R/v b) (:r::R/v b) (:r::R/v b) (:r::gr (:wat::core::- n 1) b))))
(:wat::core::defn :r::gs [n <- :wat::core::i64 b <- :r::S] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0) 0 (:wat::core::do (:r::S/v b) (:r::S/v b) (:r::S/v b) (:r::S/v b) (:r::S/v b) (:r::S/v b) (:r::S/v b) (:r::S/v b) (:r::S/v b) (:r::S/v b) (:r::gs (:wat::core::- n 1) b))))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [n 20000
     t1 (:wat::time::epoch-nanos (:wat::time::now)) _1 (:r::gr n (:r::R :v 1))
     e1 (:wat::core::- (:wat::time::epoch-nanos (:wat::time::now)) t1)
     t2 (:wat::time::epoch-nanos (:wat::time::now)) _2 (:r::gs n (:r::S :v 1))
     e2 (:wat::core::- (:wat::time::epoch-nanos (:wat::time::now)) t2)]
    (:wat::kernel::println (:wat::core::/ (:wat::core::* e1 100) e2))))'
ratio=$(printf '%s' "$OUT" | tr -dc '0-9')
if [ -n "$ratio" ] && [ "$ratio" -ge 250 ] 2>/dev/null; then report F-096 OPEN "defrecord/defstruct read ratio ${ratio}%"
elif [ -n "$ratio" ]; then report F-096 FIXED "ratio down to ${ratio}%"
else report F-096 "?" "no ratio"; fi

echo
echo "  OPEN=$open  FIXED=$fixed  UNKNOWN=$unknown"
