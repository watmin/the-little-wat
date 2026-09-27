(:wat::load-file! "common.wat")

(wat.core/defn user/build [i :- wat.type/i64 n :- wat.type/i64 v :- (wat.core/Vector :- [wat.type/i64])] :- (wat.core/Vector :- [wat.type/i64])
  (wat.core/if (wat.core/= i n) v
    (user/build (wat.core/+ i 1) n (wat.core/conj v i))))

(wat.core/defn user/sum [v :- (wat.core/Vector :- [wat.type/i64]) i :- wat.type/i64 n :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/>= i n) acc
    (user/sum v (wat.core/+ i 1) n (wat.core/+ acc (wat.core/nth v i)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [n (user/n-of)
                 v (user/build 0 n (wat.core/Vector :- [wat.type/i64]))]
    (wat.kernel/println (wat.string/concat "ANSWER " (wat.i64/to-string (user/sum v 0 n 0))))))
