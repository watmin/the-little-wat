;; excursus 003 stone 1, the orchestrator's adversarial round: a function taking an Opt of [i64 :-> i64]: agree 3.
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])
(wat.core/defn user/inc [n :- wat.type/i64] :- wat.type/i64 (wat.core/+ n 1))
(wat.core/defn user/go [o :- (:user::Opt :- [[wat.type/i64 :-> wat.type/i64]])] :- wat.type/i64
  (:wat::core::match o [:user::Opt.None {} 0] [:user::Opt.Some {:value f} (f 2)]))
(wat.core/defn user/pass [g :- [(:user::Opt :- [[wat.type/i64 :-> wat.type/i64]]) :-> wat.type/i64]] :- wat.type/i64
  (g (:user::Opt.Some {:value user/inc})))
(wat.core/defn user/main [] :- wat.type/nil (wat.kernel/println (user/pass user/go)))
