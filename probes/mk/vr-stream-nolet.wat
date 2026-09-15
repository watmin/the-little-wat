;; vr-stream-nolet.wat: variant B, the stream pipeline as one nested expression. Expected: 10000
;; Load the engine and ch 6.
(:wat::load-file! "../../books/little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../../books/reasoned-schemer/lib/ch10-under-the-hood.wat")
(:wat::load-file! "../../books/reasoned-schemer/lib/ch06-the-fun-never-ends.wat")
(wat.core/defn u/answer? [o :- (wat.type/Option :- [:rs::State])] :- wat.type/bool
  (:wat::core::match o [:wat::core::Option.Some {:value _st} true] [:wat::core::Option.None {} false]))
(wat.core/defn u/reify0 [o :- (wat.type/Option :- [:rs::State])] :- :wat::WatAST
  (:wat::core::match o [:wat::core::Option.Some {:value st} (rs/reify (rs/var 0) st)] [:wat::core::Option.None {} (quote (x))]))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.core/length
    (:wat::core::into [] (:wat::core::take (:wat::core::map u/reify0 (:wat::core::filter u/answer? ((rs/very-recursiveo) (rs/start)))) 10000)))))
