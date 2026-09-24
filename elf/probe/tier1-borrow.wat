;; A tier-1 enum (one payload variant, a pointer) is the payload itself. An Opt read out of a
;; Vector by `nth`, matched, and its payload conj'd under a name that shadows a linear parameter.
(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::defenum :user::O :wat::enum::Pure
  :No  []
  :Yes [xs <- :user::Row])
(:wat::core::typealias :user::Os (:wat::core::Vector :- [:user::O]))

(wat.core/defn user/fill [n :- wat.type/i64 acc :- :user::Os] :- :user::Os
  (wat.core/if (wat.core/= n 0) acc
    (user/fill (wat.core/- n 1)
      (wat.core/conj acc (:user::O.Yes {:xs (wat.core/Vector :- [wat.type/i64] n 20 30)})))))

(wat.core/defn user/len [o :- :user::O] :- wat.type/i64
  (:wat::core::match o [:user::O.No {} 0] [:user::O.Yes {:xs xs} (wat.core/length xs)]))

(wat.core/defn user/poke [xs :- :user::Row g :- :user::Os] :- wat.type/i64
  (:wat::core::match (wat.core/nth g 3)
    [:user::O.No {} 0]
    [:user::O.Yes {:xs xs} (wat.core/length (wat.core/conj xs 99))]))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [e (wat.core/Vector :- [wat.type/i64])
                 g (user/fill 4 (wat.core/Vector :- [:user::O]))
                 k (user/poke e g)]
    (wat.kernel/println k)                                        ;; 4
    (wat.kernel/println (user/len (wat.core/nth g 3)))))          ;; 3
