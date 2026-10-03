;; A cond clause that does not mention a record drops it when another clause's body holds
;; its last use. `user/pick` with k = 0 takes the silent clause; k = 1 reads the field;
;; k = 2 takes `:else`. `user/miss` with k = 0 takes an `:else` that does not mention the
;; record. Thirty fresh records on each path.
(wat.core/defrecord :user::TC [name :- wat.type/String])

(wat.core/defn user/pick [t :- :user::TC k :- wat.type/i64] :- wat.type/i64
  (wat.core/cond
    ((wat.core/= k 0) 1)
    ((wat.core/= k 1)
      (wat.core/if (wat.core/= (:user::TC/name t) "ab") 2 3))
    (:else 4)))

(wat.core/defn user/miss [t :- :user::TC k :- wat.type/i64] :- wat.type/i64
  (wat.core/cond
    ((wat.core/= k 7)
      (wat.core/if (wat.core/= (:user::TC/name t) "ab") 1 0))
    (:else 0)))

(wat.core/defn user/many [n :- wat.type/i64 k :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= n 0) acc
    (user/many (wat.core/- n 1) k
      (wat.core/+ acc (user/pick (:user::TC :name (wat.string/concat "a" "b")) k)))))

(wat.core/defn user/misses [n :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= n 0) acc
    (user/misses (wat.core/- n 1)
      (wat.core/+ acc (user/miss (:user::TC :name (wat.string/concat "a" "b")) 0)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    (wat.kernel/println (user/many 30 0 0))
    (wat.kernel/println (user/many 30 1 0))
    (wat.kernel/println (user/many 30 2 0))
    (wat.kernel/println (user/misses 30 0))))
