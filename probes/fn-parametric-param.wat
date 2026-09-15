;; fn-parametric-param.wat: a wat.core/fn whose parameter type is PARAMETRIC,
;; [o :- (wat.type/Option :- [wat.type/i64])], passed straight to filter. F-010 is the same
;; misread for a fn-typed parameter. Control: fn-parametric-param-kw.wat.
;; The input vector is built with u/some, which widens Some to Option (F-019).
;; Expected: 1
(wat.core/defn u/some [x :- wat.type/i64] :- (wat.type/Option :- [wat.type/i64]) (:wat::core::Option.Some {:value x}))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.core/length
    (:wat::core::into [] (:wat::core::filter (wat.core/fn [o :- (wat.type/Option :- [wat.type/i64])] :- wat.type/bool
                                               (:wat::core::match o [:wat::core::Option.Some {:value _x} true] [:wat::core::Option.None {} false]))
                                             [(u/some 1) :wat::core::Option.None])))))
