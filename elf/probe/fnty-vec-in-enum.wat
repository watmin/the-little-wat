;; excursus 003 stone 1, the orchestrator's adversarial round: Opt of a Vector of [i64 :-> i64] (element type by alias; see F-203): agree 11.
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])
(:wat::core::typealias :user::Op [wat.type/i64 :-> wat.type/i64])
(wat.core/defn user/inc [n :- wat.type/i64] :- wat.type/i64 (wat.core/+ n 1))
(wat.core/defn user/run [o :- (:user::Opt :- [(wat.core/Vector :- [:user::Op])])] :- wat.type/i64
  (:wat::core::match o [:user::Opt.None {} -1]
    [:user::Opt.Some {:value fs} ((wat.core/nth fs 1) 10)]))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/run (:user::Opt.Some {:value (wat.core/conj (wat.core/conj (wat.core/Vector :- [:user::Op]) user/inc) user/inc)}))))
