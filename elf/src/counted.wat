;; **The counted loop, and the four ways of not being one** (C-170). A parameter that enters as a
;; non-negative literal, steps by a positive literal that divides it, and is guarded by
;; `(= p 0)` takes the bound `[0, entry]` -- and every overflow check that bound proves dead is
;; not emitted. `elf/bench/triple.wat` loses four of its seven checks that way.
;;
;; The bound is only sound because the reachable values are the progression `{0, k, 2k, ... e}`,
;; so the counter lands on zero rather than stepping past it. Everything here either is that
;; shape or deliberately is not; the answers must agree with the interpreter either way, and the
;; case where the bound would license a real overflow is in elf/bad/countedovf.wat.

;; the shape: steps by one, guarded at zero. The multiply and the decrement lose their checks.
(wat.core/defn user/down [i :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= i 0) acc
    (user/down (wat.core/- i 1) (wat.core/+ acc (wat.core/* i 3)))))

;; the same, stepping by three from a multiple of three -- it lands on zero exactly
(wat.core/defn user/by3 [i :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= i 0) acc
    (user/by3 (wat.core/- i 3) (wat.core/+ acc i))))

;; NOT the shape: the guard is not `(= p 0)`, so no bound is taken and the checks stay. It has
;; to terminate by itself, which `<` does and `=` would not.
(wat.core/defn user/lt [i :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/< i 1) acc
    (user/lt (wat.core/- i 3) (wat.core/+ acc i))))

;; NOT the shape: the entry is computed rather than written, so nothing bounds it
(wat.core/defn user/id [n :- wat.type/i64] :- wat.type/i64 n)
(wat.core/defn user/opaque [i :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= i 0) acc
    (user/opaque (wat.core/- i 1) (wat.core/+ acc (wat.core/* i 2)))))

;; called from two places with different literals: the bound must cover BOTH, so it is the
;; larger of them and the smaller call must still be right
(wat.core/defn user/two [i :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= i 0) acc
    (user/two (wat.core/- i 1) (wat.core/+ acc (wat.core/* i 7)))))

;; the bound is used but the product is near the edge: 100 * 92233720368547758 is inside i64,
;; and one more multiplier would not be
(wat.core/defn user/edge [i :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= i 0) acc
    (user/edge (wat.core/- i 1) (wat.core/* i 92233720368547758))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/down 10 0))
  (wat.kernel/println (user/down 0 77))
  (wat.kernel/println (user/by3 9 0))
  (wat.kernel/println (user/by3 0 5))
  (wat.kernel/println (user/lt 10 0))
  (wat.kernel/println (user/opaque (user/id 6) 0))
  (wat.kernel/println (user/two 4 0))
  (wat.kernel/println (user/two 9 0))
  (wat.kernel/println (user/edge 100 0))
  (wat.kernel/println (user/edge 1 0)))
