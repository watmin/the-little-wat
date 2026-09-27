(:wat::load-file! "common.wat")

(wat.core/defn user/build [i :- wat.type/i64 n :- wat.type/i64
                           v :- (wat.core/Vector :- [wat.type/i64])
                           vs :- (wat.core/Vector :- [(wat.core/Vector :- [wat.type/i64])])]
  :- (wat.core/Vector :- [(wat.core/Vector :- [wat.type/i64])])
  (wat.core/if (wat.core/= i n) vs
    (wat.core/let [v2 (wat.core/conj v i)]
      (user/build (wat.core/+ i 1) n v2 (wat.core/conj vs v2)))))

(wat.core/defn user/readall [vs :- (wat.core/Vector :- [(wat.core/Vector :- [wat.type/i64])])
                             i :- wat.type/i64 n :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/>= i n) acc
    (user/readall vs (wat.core/+ i 1) n (wat.core/+ acc (wat.core/nth (wat.core/nth vs i) i)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [n (user/n-of)
                 vs (user/build 0 n (wat.core/Vector :- [wat.type/i64])
                      (wat.core/Vector :- [(wat.core/Vector :- [wat.type/i64])]))]
    (wat.kernel/println (wat.string/concat "ANSWER " (wat.i64/to-string (user/readall vs 0 n 0))))))
