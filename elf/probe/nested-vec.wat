(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::typealias :user::Grid (:wat::core::Vector :- [:user::Row]))

(wat.core/defn user/mkrow [n :- wat.type/i64 i :- wat.type/i64 acc :- :user::Row] :- :user::Row
  (wat.core/if (wat.core/= i n) acc
    (user/mkrow n (wat.core/+ i 1) (wat.core/conj acc (wat.core/* i 10)))))

(wat.core/defn user/sumgrid [g :- :user::Grid i :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/>= i (wat.core/length g)) acc
    (user/sumgrid g (wat.core/+ i 1)
      (wat.core/+ acc (wat.core/nth (wat.core/nth g i) 2)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println
    (user/sumgrid
      (wat.core/conj (wat.core/conj (wat.core/Vector :- [:user::Row])
                       (user/mkrow 5 0 (wat.core/Vector :- [wat.type/i64])))
        (user/mkrow 5 0 (wat.core/Vector :- [wat.type/i64])))
      0 0)))
