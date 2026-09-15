;; vr-reify-linear-10000.wat: the same 10000 answers, reified, with the answer list built once
;; from a Vector (one splice) instead of rs/run-goal's splice per answer.
(:wat::load-file! "../../books/little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../../books/reasoned-schemer/lib/ch10-under-the-hood.wat")
(:wat::load-file! "../../books/reasoned-schemer/lib/ch06-the-fun-never-ends.wat")
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [q (rs/var 0)
                 sts (rs/take 10000 [] ((rs/very-recursiveo) (rs/start)))
                 answers (:wat::core::foldl (wat.core/fn [acc :- (wat.type/Vector :- [:wat::WatAST]) st :- :rs::State] :- (wat.type/Vector :- [:wat::WatAST])
                                              (wat.core/conj acc (rs/reify q st)))
                                            [] sts)]
    (wat.kernel/println (wat.core/length (wat.core/quasiquote (~@answers))))))
