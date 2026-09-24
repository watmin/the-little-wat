;; A Vector bound from a MATCH is typed "i64" by :c::type-of-form (no match arm -- a guess), so
;; it is never shared when passed on: a callee that conj's its LINEAR parameter can extend the
;; caller's still-live vector in place. `m` comes from user/mk so its type is the ENUM, :user::M.
(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::defenum :user::M :wat::enum::Pure
  :Has [xs <- :user::Row]
  :Empty [])
(wat.core/defn user/mk [] :- :user::M
  (:user::M.Has {:xs (wat.core/Vector :- [wat.type/i64] 1 2 3)}))
(wat.core/defn user/bump [v :- :user::Row] :- wat.type/i64
  (wat.core/length (wat.core/conj v 99)))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [m (user/mk)
                 v (:wat::core::match m [:user::M.Has {:xs xs} xs] [:user::M.Empty {} (wat.core/Vector :- [wat.type/i64])])
                 k1 (user/bump v)
                 k2 (user/bump v)]
    (wat.kernel/println k1)                                 ;; 4
    (wat.kernel/println k2)))                               ;; 4 -- unless the first call grew v in place
