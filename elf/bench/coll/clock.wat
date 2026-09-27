(wat.core/defn user/spin [i :- wat.type/i64 n :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= i n) 0
    (user/spin (wat.core/+ i 1) n)))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [a (wat.os/clock-ns)]
    (wat.core/do
      (user/spin 0 200000)
      (wat.core/let [b (wat.os/clock-ns)]
        (wat.kernel/println (wat.core/if (wat.core/> b a) 1 0))))))
