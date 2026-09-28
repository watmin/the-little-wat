;; excursus 008 stone 3a round 7 (R16), the `match`-arm variant: a `match` arm's body is the
;; value of the whole `match` (routed through `:c::seq`, same as `if` and `do`/`let`). The
;; `:Some` arm's value is `b`, still read afterwards; the `:None` arm is a fresh literal.
(wat.core/defrecord :user::Box [n :- wat.type/i64 s :- wat.type/String])
(wat.core/defn user/take [b :- :user::Box] :- wat.type/i64
  (:user::Box/n b))
(:wat::core::defenum :user::Opt :wat::enum::Pure
  :Some []
  :None [])
(wat.core/defn user/pick [o :- :user::Opt b :- :user::Box] :- wat.type/i64
  (wat.core/+
    (user/take
      (:wat::core::match o
        [:user::Opt.Some {} b]
        [:user::Opt.None {} (:user::Box :n 7 :s "w")]))
    (:user::Box/n b)))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [b (:user::Box :n 3 :s (wat.string/concat "a" "b"))]
    (wat.kernel/println (user/pick (:user::Opt.Some {}) b))
    (wat.kernel/println (:user::Box/s b))))
