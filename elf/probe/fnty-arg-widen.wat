;; F-202. A function taking the PARENT passed where one taking a VARIANT is wanted: wat accepts
;; it (contravariant arguments). Interpreter 1; must agree.
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])
;; a function that takes the PARENT, passed where a function taking a VARIANT is wanted
(wat.core/defn user/onopt [o :- (:user::Opt :- [wat.type/i64])] :- wat.type/i64 1)
(wat.core/defn user/apply [f :- [(:user::Opt.Some :- [wat.type/i64]) :-> wat.type/i64]] :- wat.type/i64
  (f (:user::Opt.Some {:value 3})))
(wat.core/defn user/main [] :- wat.type/nil (wat.kernel/println (user/apply user/onopt)))
