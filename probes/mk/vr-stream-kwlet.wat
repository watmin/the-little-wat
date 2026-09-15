;; vr-stream-kwlet.wat: variant A, the stream pipeline under the KEYWORD let. Expected: 10000
;; Load the engine and ch 6.
(:wat::load-file! "../../books/little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../../books/reasoned-schemer/lib/ch10-under-the-hood.wat")
(:wat::load-file! "../../books/reasoned-schemer/lib/ch06-the-fun-never-ends.wat")
(wat.core/defn u/answer? [o :- (wat.type/Option :- [:rs::State])] :- wat.type/bool
  (:wat::core::match o [:wat::core::Option.Some {:value _st} true] [:wat::core::Option.None {} false]))
(wat.core/defn u/reify0 [o :- (wat.type/Option :- [:rs::State])] :- :wat::WatAST
  (:wat::core::match o [:wat::core::Option.Some {:value st} (rs/reify (rs/var 0) st)] [:wat::core::Option.None {} (quote (x))]))
(wat.core/defn user/main [] :- wat.type/nil
  (:wat::core::let [s ((rs/very-recursiveo) (rs/start))
                    v (:wat::core::into [] (:wat::core::take (:wat::core::map u/reify0 (:wat::core::filter u/answer? s)) 10000))]
    (wat.kernel/println (wat.core/length (wat.core/quasiquote (~@v))))))
