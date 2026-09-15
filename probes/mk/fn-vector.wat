;; fn-vector.wat: a Vector holding functions, folded over (miniKanren's conde takes a list of goals).
;; Expected: 6
(wat.core/defn u/apply-all [fs :- (wat.type/Vector :- [[wat.type/i64 :-> wat.type/i64]]) x :- wat.type/i64] :- wat.type/i64
  (:wat::core::foldl (:wat::core::fn [acc <- :wat::core::i64 f <- [:wat::core::i64 :-> :wat::core::i64]] -> :wat::core::i64 (f acc))
                     x fs))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (u/apply-all [(wat.core/fn [n :- wat.type/i64] :- wat.type/i64 (wat.core/+ n 1))
                                    (wat.core/fn [n :- wat.type/i64] :- wat.type/i64 (wat.core/* n 2))]
                                   (wat.core/+ 1 1))))
