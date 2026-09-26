;; one function value stored into a Vector twice. The static object's count stays 0.
(wat.core/defn user/inc [n :- wat.type/i64] :- wat.type/i64 (wat.core/+ n 1))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [v (wat.core/conj
                    (wat.core/conj (wat.core/Vector :- [[wat.type/i64 :-> wat.type/i64]]) user/inc)
                    user/inc)]
    (wat.kernel/println (wat.core/+ ((wat.core/nth v 0) 20) ((wat.core/nth v 1) 21)))))
