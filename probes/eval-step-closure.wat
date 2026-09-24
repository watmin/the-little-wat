;; the builder's example: a fn that CAPTURES x from the let around it
(wat.core/defn user/make [] :- [wat.type/i64 :-> wat.type/i64]
  (wat.core/let [x 42]
    (wat.core/fn [y :- wat.type/i64] :- wat.type/i64
      (wat.core/+ x y))))

;; a plain top-level function: captures NOTHING
(wat.core/defn user/add1 [n :- wat.type/i64] :- wat.type/i64 (wat.core/+ n 1))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [f (user/make)]
    (wat.kernel/println (f 0))                                                          ;; 42: the capture works
    (wat.kernel/println (wat.core/str (:wat::eval-step! (:wat::core::quote (user/add1 3)))))))  ;; step the EMPTY-capture fn
