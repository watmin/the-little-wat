;; F-200 adversarial: an Opt over a HEAP enum with a unit variant -- tier 3 after the fix, the inner Dot tag distinguished.
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])
(:wat::core::defenum :user::Sh :wat::enum::Pure
  :Dot []
  :Box [w <- :wat::core::i64]
  :Tag [s <- :wat::core::String])
(wat.core/defn user/dot [] :- :user::Sh (:user::Sh.Dot {}))
(wat.core/defn user/tag [] :- :user::Sh (:user::Sh.Tag {:s "ab"}))
(wat.core/defn user/f [o :- (:user::Opt :- [:user::Sh])] :- wat.type/i64
  (:wat::core::match o [:user::Opt.None {} -1]
    [:user::Opt.Some {:value v} (:wat::core::match v [:user::Sh.Dot {} 0] [:user::Sh.Box {:w w} w] [:user::Sh.Tag {:s s} (wat.string/length (wat.string/concat s "!"))])]))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [a (:user::Opt.Some {:value (user/dot)})
                 b (:user::Opt.Some {:value (user/tag)})]
    (wat.kernel/println (wat.core/+ (user/f a) (user/f a)))
    (wat.kernel/println (wat.core/+ (user/f b) (user/f b)))))
