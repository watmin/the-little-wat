(:wat::core::typealias :user::Vec (:wat::core::Vector :- [:wat::core::i64]))

(wat.core/defn user/f [acc :- :user::Vec i :- wat.type/i64] :- wat.type/i64
  (wat.core/cond
    ((wat.core/> (wat.core/length (wat.core/conj acc i)) 0) (wat.core/length acc))
    (:else 0)))

(wat.core/defn user/grow [n :- wat.type/i64 i :- wat.type/i64 acc :- :user::Vec] :- :user::Vec
  (wat.core/if (wat.core/= i n) acc
    (user/grow n (wat.core/+ i 1) (wat.core/conj acc i))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/f (user/grow 3 0 (wat.core/Vector :- [wat.type/i64])) 9)))
