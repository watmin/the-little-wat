(wat.core/defn user/build [i :- wat.type/i64 n :- wat.type/i64
                         v :- (wat.core/Vector :- [wat.type/i64])]
    :- (wat.core/Vector :- [wat.type/i64])
  (wat.core/if (wat.core/= i n) v
    (user/build (wat.core/+ i 1) n (wat.core/conj v i))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [v (user/build 0 20 (wat.core/Vector :- [wat.type/i64]))]
    (wat.core/let [w v
                   c (wat.core/conj v 99)]
      (wat.core/do
        (wat.kernel/println (wat.i64/to-string (wat.core/length v)))
        (wat.kernel/println (wat.i64/to-string (wat.core/nth c 20)))
        (wat.kernel/println (wat.i64/to-string (wat.core/length (user/build 0 5 v))))))))
