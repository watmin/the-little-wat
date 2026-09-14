;; fn-typed-param-kw.wat: F-010 control. The same lambda as fn-typed-param-clj.wat, in the
;; KEYWORD spelling (:wat::core::fn with <- binders). Expected: 2
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [apply-to-1 (:wat::core::fn [f <- [:wat::core::i64 :-> :wat::core::i64]] -> :wat::core::i64
                              (f 1))]
    (wat.kernel/println (apply-to-1 (wat.core/fn [n :- wat.type/i64] :- wat.type/i64 (wat.core/+ n 1))))))
