;; excursus 003 stone 1, the orchestrator's adversarial round: a variant passed at an indirect call to [Opt :-> i64]: agree 7.
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])
(wat.core/defn user/tag [o :- (:user::Opt :- [wat.type/i64])] :- wat.type/i64
  (:wat::core::match o [:user::Opt.None {} 0] [:user::Opt.Some {:value v} v]))
(wat.core/defn user/apply [f :- [(:user::Opt :- [wat.type/i64]) :-> wat.type/i64] n :- wat.type/i64] :- wat.type/i64
  (wat.core/+ (f (:user::Opt.Some {:value n})) (f (:user::Opt.None {}))))
(wat.core/defn user/main [] :- wat.type/nil (wat.kernel/println (user/apply user/tag 7)))
