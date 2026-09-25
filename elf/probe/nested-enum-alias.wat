;; F-200 behind a typealias: Opt<MS> with MS = Opt<String>. HEAD native 0|0, interpreter 9|9.
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])
(:wat::core::typealias :user::MS (:user::Opt :- [:wat::core::String]))
(wat.core/defn user/none [] :- :user::MS (:user::Opt.None {}))
(wat.core/defn user/len [o :- :user::MS] :- wat.type/i64
  (:wat::core::match o [:user::Opt.None {} -1] [:user::Opt.Some {:value v} (wat.string/length (wat.string/concat v "!"))]))
(wat.core/defn user/which [o :- (:user::Opt :- [:user::MS])] :- wat.type/i64
  (:wat::core::match o [:user::Opt.None {} 0] [:user::Opt.Some {:value v} (wat.core/+ 10 (user/len v))]))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [a (:user::Opt.Some {:value (user/none)})]
    (wat.kernel/println (user/which a))
    (wat.kernel/println (user/which a))))
