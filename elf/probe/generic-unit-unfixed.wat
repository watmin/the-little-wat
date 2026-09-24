;; D9's remaining reach: a UNIT variant of a generic enum, passed where nothing fixes T.
;; It runs correctly (a unit variant is its tag in every tier) -- but both gates should flag it.
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])
(wat.core/defn user/shows [o :- (:user::Opt :- [wat.type/String])] :- wat.type/i64
  (:wat::core::match o [:user::Opt.Some {:value v} (wat.string/length v)] [:user::Opt.None {} 0]))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/shows (:user::Opt.None {}))))
