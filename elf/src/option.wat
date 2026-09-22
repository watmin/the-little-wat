(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])

(wat.core/defn user/pick [n :- wat.type/i64] :- (:user::Opt :- [wat.type/i64])
  (wat.core/if (wat.core/> n 0) (:user::Opt.Some {:value n}) (:user::Opt.None {})))

(wat.core/defn user/name [n :- wat.type/i64] :- (:user::Opt :- [wat.type/String])
  (wat.core/if (wat.core/> n 0) (:user::Opt.Some {:value "yes"}) (:user::Opt.None {})))

(wat.core/defn user/showi [o :- (:user::Opt :- [wat.type/i64])] :- wat.type/String
  (:wat::core::match o
    [:user::Opt.Some {:value v} (wat.i64/to-string v)]
    [:user::Opt.None {}         "none"]))

(wat.core/defn user/shows [o :- (:user::Opt :- [wat.type/String])] :- wat.type/String
  (:wat::core::match o
    [:user::Opt.Some {:value v} (wat.string/concat "<" (wat.string/concat v ">"))]
    [:user::Opt.None {}         "none"]))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    (wat.kernel/println (user/showi (user/pick 7)))
    (wat.kernel/println (user/showi (user/pick 0)))
    (wat.kernel/println (user/shows (user/name 1)))
    (wat.kernel/println (user/shows (user/name 0)))))
