;; Stone 6 adversarial: a `match` whose arms build different variants joins to the PARENT.
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])
(wat.core/defn user/len [o :- (:user::Opt :- [wat.type/String])] :- wat.type/i64
  (:wat::core::match o [:user::Opt.None {} -1] [:user::Opt.Some {:value v} (wat.string/length (wat.string/concat v "!"))]))

(wat.core/defn user/flip [o :- (:user::Opt :- [wat.type/String])] :- wat.type/i64
  (wat.core/let [p (:wat::core::match o [:user::Opt.None {} (:user::Opt.Some {:value "zz"})] [:user::Opt.Some {:value v} (:user::Opt.None {})])]
    (wat.core/+ (user/len p) (user/len p))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/flip (:user::Opt.None {})))
  (wat.kernel/println (user/flip (:user::Opt.Some {:value "q"}))))
