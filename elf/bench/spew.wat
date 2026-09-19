(wat.core/defn user/spew [i :- wat.type/i64 n :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/>= i n) i
    (wat.core/do
      (wat.kernel/println i)
      (user/spew (wat.core/+ i 1) n))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [k (user/spew 0 100000)] nil))
