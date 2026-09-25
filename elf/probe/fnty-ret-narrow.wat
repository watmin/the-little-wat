;; F-202. A function RETURNING a variant passed where one returning the parent is wanted: wat
;; accepts it (covariant return). Interpreter 4. The native compiler at beb513d REFUSED it.
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])
;; a function RETURNING a variant, passed where one returning the parent is wanted
(wat.core/defn user/mk [n :- wat.type/i64] :- (:user::Opt.Some :- [wat.type/i64]) (:user::Opt.Some {:value n}))
(wat.core/defn user/apply [f :- [wat.type/i64 :-> (:user::Opt :- [wat.type/i64])]] :- wat.type/i64
  (:wat::core::match (f 4) [:user::Opt.None {} 0] [:user::Opt.Some {:value v} v]))
(wat.core/defn user/main [] :- wat.type/nil (wat.kernel/println (user/apply user/mk)))
