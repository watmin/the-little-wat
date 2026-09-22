(:wat::core::typealias :user::Kids (:wat::core::Vector :- [:wat::core::i64]))
(wat.core/defn user/pt [a :- wat.type/i64 pg :- wat.type/String] :- wat.type/bool
  (wat.core/> a -1))
(wat.core/defn user/hoist [ks :- :user::Kids i :- wat.type/i64 seen? :- wat.type/bool
                           pg :- wat.type/String] :- wat.type/bool
  (wat.core/if (wat.core/>= i (wat.core/length ks)) seen?
    (wat.core/and (user/pt (wat.core/nth ks i) pg)
      (user/hoist ks (wat.core/+ i 1) seen? pg))))
(wat.core/defn user/grow [n :- wat.type/i64 i :- wat.type/i64 acc :- :user::Kids] :- :user::Kids
  (wat.core/if (wat.core/= i n) acc
    (user/grow n (wat.core/+ i 1) (wat.core/conj acc i))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    (wat.kernel/println (user/hoist (user/grow 40 0 (wat.core/Vector :- [wat.type/i64])) 0 true "p"))
    (wat.kernel/println (user/hoist (user/grow 40 0 (wat.core/Vector :- [wat.type/i64])) 0 false "p"))))
