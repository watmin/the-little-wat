;; fn-typed-param-clj.wat: F-010 repro. A Clojure/EDN-spelled fn literal whose PARAMETER
;; has a function type. The same shape works in :wat::core::fn (fn-typed-param-kw.wat) and
;; in wat.core/defn. Expected once fixed: 2
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [apply-to-1 (wat.core/fn [f :- [wat.type/i64 :-> wat.type/i64]] :- wat.type/i64
                              (f 1))]
    (wat.kernel/println (apply-to-1 (wat.core/fn [n :- wat.type/i64] :- wat.type/i64 (wat.core/+ n 1))))))
