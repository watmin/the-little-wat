(wat.core/defn user/go [i :- wat.type/i64 n :- wat.type/i64 a :- wat.type/i64 b :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= i n) (wat.core/+ a b)
    (user/go (wat.core/+ i 1) n a b)))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/go 0 1000 3 4)))
