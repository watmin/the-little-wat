(wat.core/defn user/call [f :- [wat.type/i64 :-> wat.type/i64] n :- wat.type/i64] :- wat.type/i64
  (f n))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [f (wat.core/fn [n :- wat.type/i64] :- wat.type/i64 n)]
    (wat.kernel/println (wat.i64/to-string (f (user/call f 7))))))
