(:wat::core::typealias :user::Op [:wat::core::i64 :-> :wat::core::i64])
(:wat::core::typealias :user::Ops (:wat::core::Vector :- [:user::Op]))

(wat.core/defn user/inc1 [x :- wat.type/i64] :- wat.type/i64 (wat.core/+ x 1))
(wat.core/defn user/dbl  [x :- wat.type/i64] :- wat.type/i64 (wat.core/* x 2))

(wat.core/defn user/run [ops :- :user::Ops i :- wat.type/i64 v :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/>= i (wat.core/length ops)) v
    (user/run ops (wat.core/+ i 1) ((wat.core/nth ops i) v))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println
    (user/run (wat.core/conj (wat.core/conj (wat.core/Vector :- [:user::Op]) user/inc1) user/dbl) 0 20)))
