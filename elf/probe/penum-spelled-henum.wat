;; stone 0c STOP-2 probe: a tier-1 enum built by a constructor and bound by `let` is typed by
;; `:c::type-of-form`'s variant arm as `henum:`, while every declared use types it `penum:`.
;; The count on the let-bound name is the only thing between its payload and an in-place conj.
(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::defenum :user::O :wat::enum::Pure
  :No  []
  :Yes [xs <- :user::Row])

(wat.core/defn user/len [o :- :user::O] :- wat.type/i64
  (:wat::core::match o [:user::O.No {} 0] [:user::O.Yes {:xs xs} (wat.core/length xs)]))

(wat.core/defn user/poke [xs :- :user::Row o :- :user::O] :- wat.type/i64
  (:wat::core::match o
    [:user::O.No {} 0]
    [:user::O.Yes {:xs xs} (wat.core/length (wat.core/conj xs 99))]))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [e (wat.core/Vector :- [wat.type/i64])
                 o (:user::O.Yes {:xs (wat.core/Vector :- [wat.type/i64] 1 2 3)})
                 k (user/poke e o)]
    (wat.kernel/println k)                 ;; 4
    (wat.kernel/println (user/len o))))    ;; 3 -- 4 if the payload was extended in place
