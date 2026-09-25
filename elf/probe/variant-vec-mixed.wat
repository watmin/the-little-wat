;; Stone 6 adversarial: variants of both kinds held in one Vector of the parent, read back out.
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])
(wat.core/defn user/len [o :- (:user::Opt :- [wat.type/String])] :- wat.type/i64
  (:wat::core::match o [:user::Opt.None {} -1] [:user::Opt.Some {:value v} (wat.string/length (wat.string/concat v "!"))]))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [xs (wat.core/Vector :- [(:user::Opt :- [wat.type/String])] (:user::Opt.Some {:value "ab"}) (:user::Opt.None {}) (:user::Opt.Some {:value "c"}))]
    (wat.kernel/println (user/len (wat.core/nth xs 0)))
    (wat.kernel/println (user/len (wat.core/nth xs 1)))
    (wat.kernel/println (user/len (wat.core/nth xs 2)))
    (wat.kernel/println (user/len (wat.core/nth xs 1)))))
