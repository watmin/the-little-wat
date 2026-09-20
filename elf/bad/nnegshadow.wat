;; C-166 drops the overflow check on `(- x k)` inside a branch that proved `x >= 0` -- inside the
;; THEN arm of `(> x 0)`, `x - 1` cannot underflow, so the `jo` guarding it is dead code.
;;
;; **The proof is about a VALUE, and a `let` that rebinds the name binds a different one.** Here
;; the outer `x` is 1 and the inner `x` is the most negative i64, so `(- x 1)` underflows and must
;; still trap -- which it only does if the fact is dropped when the name is rebound.
;;
;; It lives here rather than in elf/src for the same reason overflow.wat does: it always stops,
;; and the differential compares programs that finish. `tools/elf-run.sh` checks that BOTH stop.
(wat.core/defn user/neg [] :- wat.type/i64 -9223372036854775808)
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [x 1]
    (wat.kernel/println
      (wat.core/if (wat.core/> x 0)
        (wat.core/let [x (user/neg)] (wat.core/- x 1))
        x))))
