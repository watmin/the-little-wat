;; a function value passed through a Vector, then called
(wat.core/defn user/inc [n :- wat.type/i64] :- wat.type/i64 (wat.core/+ n 1))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [v (wat.core/conj (wat.core/Vector :- [[wat.type/i64 :-> wat.type/i64]]) user/inc)]
    (wat.kernel/println ((wat.core/nth v 0) 41))))
