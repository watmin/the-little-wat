;; excursus 003 stone 1, the orchestrator's adversarial round: variance two deep -- contravariance of contravariance is covariance: wat accepts; agree 5.
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])
;; h takes a [Opt.Some :-> i64]; wanted: something taking a [Opt :-> i64]. to-arg [Opt->i64] must fit from-arg [Some->i64]: Some fits Opt -> fits.
(wat.core/defn user/onopt [o :- (:user::Opt :- [wat.type/i64])] :- wat.type/i64 5)
(wat.core/defn user/h [g :- [(:user::Opt.Some :- [wat.type/i64]) :-> wat.type/i64]] :- wat.type/i64 (g (:user::Opt.Some {:value 1})))
(wat.core/defn user/use [k :- [[(:user::Opt :- [wat.type/i64]) :-> wat.type/i64] :-> wat.type/i64]] :- wat.type/i64 (k user/onopt))
(wat.core/defn user/main [] :- wat.type/nil (wat.kernel/println (user/use user/h)))
