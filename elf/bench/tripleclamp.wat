;; **The disconfirming probe for the three surviving overflow checks** (C-170, F-155).
;;
;; `elf/bench/triple.wat` carries three `jo`s that no interval analysis can delete: its
;; accumulators climb 89 million an iteration and the conditional subtract only removes one
;; million, so the interval grows without bound and C-170 measured that widening does not
;; help either. Three of the five uops we issue over `gcc -O2` on that loop are those checks.
;;
;; This file is `triple.wat` with ONE change: the accumulator CLAMPS to zero instead of
;; subtracting, so `a` is bounded by the threshold and the interval converges. Everything
;; else -- three independent chains, the same multipliers, the same counted loop, the same
;; diamond shape -- is identical. The existing `:c::dst-dead?` should therefore delete the
;; three checks it already knows how to delete, without a line of new compiler.
;;
;; **What it answers, before anyone builds anything.** If this runs at 17 uops and the cycles
;; do not move, then neither strength reduction (worth 2 uops) nor a progression-summing
;; bounds domain (worth 3) is worth the build, and F-156's lesson holds: uops removed are not
;; cycles saved. If the cycles DO move, the prize is measured and the brief can be written.
;;
;; It is not a benchmark of wat against C. It is a benchmark of wat against itself with the
;; checks deleted by a proof the compiler already has.
(wat.core/defn user/go [i :- wat.type/i64 a :- wat.type/i64 b :- wat.type/i64 c :- wat.type/i64]
    :- wat.type/i64
  (wat.core/if (wat.core/= i 0) (wat.core/+ a (wat.core/+ b c))
    (wat.core/let [a2 (wat.core/+ a (wat.core/* i 3))
                   b2 (wat.core/+ b (wat.core/* i 5))
                   c2 (wat.core/+ c (wat.core/* i 7))]
      (user/go (wat.core/- i 1)
        (wat.core/if (wat.core/> a2 1000000) 0 a2)
        (wat.core/if (wat.core/> b2 2000000) 0 b2)
        (wat.core/if (wat.core/> c2 3000000) 0 c2)))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/go 30000000 0 0 0)))
