(:wat::load-file! "common.wat")

(wat.core/defn user/build [i :- wat.type/i64 n :- wat.type/i64 v :- (wat.core/Vector :- [wat.type/String])] :- (wat.core/Vector :- [wat.type/String])
  (wat.core/if (wat.core/= i n) v
    (user/build (wat.core/+ i 1) n (wat.core/conj v (wat.string/concat "a" "b")))))

(wat.core/defn user/sum [v :- (wat.core/Vector :- [wat.type/String]) i :- wat.type/i64 n :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/>= i n) acc
    (user/sum v (wat.core/+ i 1) n (wat.core/+ acc (wat.string/length (wat.core/nth v i))))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [n (user/n-of)
                 v (user/build 0 n (wat.core/Vector :- [wat.type/String]))]
    (wat.kernel/println (wat.string/concat "ANSWER " (wat.i64/to-string (user/sum v 0 n 0))))))
