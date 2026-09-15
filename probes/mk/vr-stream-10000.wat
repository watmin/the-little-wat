;; vr-stream-10000.wat: 10000 very-recursiveo answers reified through the stdlib's lazy stream fns
;; (filter the answers, map reify, take, then into [], the stdlib's native materializer) instead of hand
;; accumulators. Compare vr-take-10000.wat and very-recursiveo-10000.wat.
(:wat::load-file! "../../books/little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../../books/reasoned-schemer/lib/ch10-under-the-hood.wat")
(:wat::load-file! "../../books/reasoned-schemer/lib/ch06-the-fun-never-ends.wat")
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [q (rs/var 0)
                 s ((rs/very-recursiveo) (rs/start))
                 answers (:wat::core::filter (wat.core/fn [o :- (wat.type/Option :- [:rs::State])] :- wat.type/bool
                                               (:wat::core::match o
                                                 [:wat::core::Option.Some {:value _st} true]
                                                 [:wat::core::Option.None {} false]))
                                             s)
                 reified (:wat::core::map (wat.core/fn [o :- (wat.type/Option :- [:rs::State])] :- :wat::WatAST
                                            (:wat::core::match o
                                              [:wat::core::Option.Some {:value st} (rs/reify q st)]
                                              [:wat::core::Option.None {} '()]))
                                          answers)
                 v (:wat::core::into [] (:wat::core::take reified 10000))]
    (wat.kernel/println (wat.core/length (wat.core/quasiquote (~@v))))))
