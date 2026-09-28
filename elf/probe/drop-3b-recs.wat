;; excursus 008 stone 3b: a Vector of records of Strings, built and dropped, fifty times.
;; The glue walks three types: the Vector (a trie past eight elements), the record, the String.
(wat.core/defrecord :user::Row [id :- wat.type/i64 name :- wat.type/String])

(wat.core/defn user/fill [i :- wat.type/i64 n :- wat.type/i64
                          v :- (wat.core/Vector :- [:user::Row])] :- (wat.core/Vector :- [:user::Row])
  (wat.core/if (wat.core/= i n) v
    (user/fill (wat.core/+ i 1) n
      (wat.core/conj v (:user::Row :id i :name (wat.string/concat "row-" (wat.i64/to-string i)))))))

(wat.core/defn user/total [v :- (wat.core/Vector :- [:user::Row]) i :- wat.type/i64 acc :- wat.type/i64]
    :- wat.type/i64
  (wat.core/if (wat.core/>= i (wat.core/length v)) acc
    (user/total v (wat.core/+ i 1)
      (wat.core/+ acc (wat.string/length (:user::Row/name (wat.core/nth v i)))))))

(wat.core/defn user/rounds [r :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= r 0) acc
    (user/rounds (wat.core/- r 1)
      (wat.core/+ acc (user/total (user/fill 0 2000 (wat.core/Vector :- [:user::Row])) 0 0)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.i64/to-string (user/rounds 50 0))))
