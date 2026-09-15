;; fn-parametric-param-kw.wat: control for fn-parametric-param.wat, the lambda in the keyword
;; spelling. Expected: 1
(wat.core/defn u/some [x :- wat.type/i64] :- (wat.type/Option :- [wat.type/i64]) (:wat::core::Option.Some {:value x}))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.core/length
    (:wat::core::into [] (:wat::core::filter (:wat::core::fn [o <- (:wat::core::Option :- [:wat::core::i64])] -> :wat::core::bool
                                               (:wat::core::match o [:wat::core::Option.Some {:value _x} true] [:wat::core::Option.None {} false]))
                                             [(u/some 1) :wat::core::Option.None])))))
