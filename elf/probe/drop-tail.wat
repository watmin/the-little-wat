(wat.core/defn user/go [n :- wat.type/i64 v :- (wat.core/Vector :- [wat.type/i64])] :- wat.type/i64
  (wat.core/if (wat.core/= n 0) (wat.core/length v)
    (user/go (wat.core/- n 1) (wat.core/Vector :- [wat.type/i64]))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.i64/to-string
    (user/go 4 (user/build-one)))))

(wat.core/defn user/build-one [] :- (wat.core/Vector :- [wat.type/i64])
  (wat.core/conj (wat.core/Vector :- [wat.type/i64]) 7))
