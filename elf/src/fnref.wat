(wat.core/defn user/add [a :- wat.type/i64 b :- wat.type/i64] :- wat.type/i64 (wat.core/+ a b))
(wat.core/defn user/mul [a :- wat.type/i64 b :- wat.type/i64] :- wat.type/i64 (wat.core/* a b))

(wat.core/defn user/pick [which :- wat.type/bool] :- [wat.type/i64 wat.type/i64 :-> wat.type/i64]
  (wat.core/if which user/add user/mul))

(wat.core/defn user/go [op :- [wat.type/i64 wat.type/i64 :-> wat.type/i64]] :- wat.type/i64
  (op 6 7))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    (wat.kernel/println (user/go (user/pick true)))
    (wat.kernel/println (user/go (user/pick false)))
    (wat.kernel/println (user/go user/add))))
