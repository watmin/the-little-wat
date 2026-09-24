;; Does own? fire on a LET binding that SHADOWS a linear parameter? No borrowed pointer crosses a
;; call here: `e` is passed as a Symbol (shared), and the borrowed row is bound INSIDE bump.
(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::typealias :user::Grid (:wat::core::Vector :- [:user::Row]))
(wat.core/defn user/bump [v :- :user::Row g :- :user::Grid] :- wat.type/i64
  (wat.core/let [v (wat.core/nth g 3)]
    (wat.core/nth (wat.core/conj v 99) 2)))
(wat.core/defn user/fill [n :- wat.type/i64 acc :- :user::Grid] :- :user::Grid
  (wat.core/if (wat.core/= n 0) acc
    (user/fill (wat.core/- n 1)
      (wat.core/conj acc (wat.core/Vector :- [wat.type/i64] n 20 30)))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [e (wat.core/Vector :- [wat.type/i64])
                 g (user/fill 4 (wat.core/Vector :- [:user::Row]))
                 k (user/bump e g)]
    (wat.kernel/println k)
    (wat.kernel/println (wat.core/length (wat.core/nth g 3)))
    (wat.kernel/println (wat.core/nth (wat.core/nth g 3)
      (wat.core/- (wat.core/length (wat.core/nth g 3)) 1)))))
