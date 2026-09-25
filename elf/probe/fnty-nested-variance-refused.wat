;; excursus 003 stone 1, the orchestrator's adversarial round: the other direction two deep: wat refuses; must be COMPILE-FAILED.
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])
;; the other way: h takes [Opt :-> i64]; wanted: taking [Opt.Some :-> i64]. to-arg [Some->i64] must fit [Opt->i64]: needs Opt fits Some -> refused.
(wat.core/defn user/onsome [o :- (:user::Opt.Some :- [wat.type/i64])] :- wat.type/i64 5)
(wat.core/defn user/h [g :- [(:user::Opt :- [wat.type/i64]) :-> wat.type/i64]] :- wat.type/i64 (g (:user::Opt.None {})))
(wat.core/defn user/use [k :- [[(:user::Opt.Some :- [wat.type/i64]) :-> wat.type/i64] :-> wat.type/i64]] :- wat.type/i64 (k user/onsome))
(wat.core/defn user/main [] :- wat.type/nil (wat.kernel/println (user/use user/h)))
