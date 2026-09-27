;; The vector is the function's parameter and each conj is its last use, so the owned
;; path runs. Past eight elements that path copies, and the copied slots are strings.
(wat.core/defn user/grow [n :- wat.type/i64 v :- (wat.core/Vector :- [wat.type/String])] :- (wat.core/Vector :- [wat.type/String])
  (wat.core/if (wat.core/= n 0) v
    (user/grow (wat.core/- n 1)
      (wat.core/conj v (wat.string/concat "n" (wat.i64/to-string n))))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [v (user/grow 10 (wat.core/Vector :- [wat.type/String]))]
    (wat.kernel/println (wat.core/length v))
    (wat.kernel/println (wat.core/nth v 0))
    (wat.kernel/println (wat.core/nth v 9))))
