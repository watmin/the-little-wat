(wat.core/defn user/upto [n :- wat.type/i64 i :- wat.type/i64
                      acc :- (wat.core/Vector :- [wat.type/i64])]
    :- (wat.core/Vector :- [wat.type/i64])
  (wat.core/if (wat.core/>= i n) acc
    (user/upto n (wat.core/+ i 1) (wat.core/conj acc i))))

(wat.core/defn user/sum [v :- (wat.core/Vector :- [wat.type/i64])
                        i :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/>= i (wat.core/length v)) acc
    (user/sum v (wat.core/+ i 1) (wat.core/+ acc (wat.core/nth v i)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [v (user/upto 4 0 (wat.core/Vector :- [wat.type/i64]))]
    (wat.kernel/println (wat.i64/to-string
      (wat.core/+ (wat.core/* 1000000 (wat.core/length v))
        (wat.core/+ (wat.core/* 1000 (user/sum v 0 0))
          (wat.core/nth v 0)))))))
