;; Stone 6 adversarial: an `if` of a Some-of-literal and a None joins to the PARENT, which keeps its guards.
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])
(wat.core/defn user/len [o :- (:user::Opt :- [wat.type/String])] :- wat.type/i64
  (:wat::core::match o [:user::Opt.None {} -1] [:user::Opt.Some {:value v} (wat.string/length (wat.string/concat v "!"))]))

(wat.core/defn user/pick [b :- wat.type/bool] :- wat.type/i64
  (wat.core/let [o (wat.core/if b (:user::Opt.Some {:value "ab"}) (:user::Opt.None {}))]
    (wat.core/+ (user/len o) (user/len o))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/pick true))
  (wat.kernel/println (user/pick false)))
