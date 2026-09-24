;; An inlined call must be typed as the CALL it replaces. `user/none` is small enough to inline, so
;; `(user/showi (user/none))` becomes `(user/showi (let [] (:user::Opt.None {})))` -- and a unit
;; variant says nothing about `T`. Typed from its body, the argument is `(:user::Opt)` with no
;; argument; typed as its origin, it is `user/none`'s declared `(:user::Opt :- [i64])`, which is
;; what the same call gets when it is NOT inlined (excursus 002 stone 4).
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])

(wat.core/defn user/none [] :- (:user::Opt :- [wat.type/i64])
  (:user::Opt.None {}))

(wat.core/defn user/showi [o :- (:user::Opt :- [wat.type/i64])] :- wat.type/String
  (:wat::core::match o
    [:user::Opt.Some {:value v} (wat.i64/to-string v)]
    [:user::Opt.None {}         "none"]))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/showi (user/none))))               ;; none
