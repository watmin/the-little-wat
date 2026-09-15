;; vr-count-20000.wat: very-recursiveo's search, 20000 answers COUNTED (no Vector accumulator).
;; Compare vr-take-20000.wat, which conj's each state onto a Vector.
(:wat::load-file! "../../books/little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../../books/reasoned-schemer/lib/ch10-under-the-hood.wat")
(:wat::load-file! "../../books/reasoned-schemer/lib/ch06-the-fun-never-ends.wat")
(wat.core/defn u/count [n :- wat.type/i64 k :- wat.type/i64 s :- :rs::Stream] :- wat.type/i64
  (wat.core/if (wat.core/= n 0)
    k
    (:wat::core::match (:wat::stream::next s)
      [:wat::stream::NextOutcome.Exhausted {} k]
      [:wat::stream::NextOutcome.Item {:value v :rest r}
        (:wat::core::match v
          [:wat::core::Option.Some {:value _st} (u/count (wat.core/- n 1) (wat.core/+ k 1) r)]
          [:wat::core::Option.None {} (u/count n k r)])])))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (u/count 20000 0 ((rs/very-recursiveo) (rs/start)))))
