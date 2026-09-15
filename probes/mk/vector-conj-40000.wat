;; vector-conj-40000.wat: 40000 conj's onto a Vector in a loop, against a loop that only adds.
;; If conj copies the Vector, the first grows quadratically. Prints the two results.
(wat.core/defn u/fill [n :- wat.type/i64 acc :- (wat.type/Vector :- [wat.type/i64])] :- (wat.type/Vector :- [wat.type/i64])
  (wat.core/if (wat.core/= n 0) acc (u/fill (wat.core/- n 1) (wat.core/conj acc n))))
(wat.core/defn u/spin [n :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= n 0) acc (u/spin (wat.core/- n 1) (wat.core/+ acc 1))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.core/length (u/fill 40000 []))))
