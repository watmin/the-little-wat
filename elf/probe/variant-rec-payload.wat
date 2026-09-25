;; Stone 6 adversarial: a tier-1 Opt of a RECORD -- a bare incq -- passed as the variant, read out of a Vector of the parent.
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])
(:wat::core::defrecord :user::P [a <- :wat::core::i64 b <- :wat::core::String])
(wat.core/defn user/get [o :- (:user::Opt :- [:user::P])] :- wat.type/i64
  (:wat::core::match o [:user::Opt.None {} -1] [:user::Opt.Some {:value p} (wat.core/+ (:user::P/a p) (wat.string/length (:user::P/b p)))]))
(wat.core/defn user/take [o :- (:user::Opt.Some :- [:user::P])] :- wat.type/i64
  (wat.core/let [{:keys [value]} o] (wat.core/+ (user/get o) (:user::P/a value))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [s (:user::Opt.Some {:value (:user::P :a 5 :b "hi")})
                 xs (wat.core/Vector :- [(:user::Opt :- [:user::P])] s (:user::Opt.None {}) s)]
    (wat.kernel/println (user/take s))
    (wat.kernel/println (user/take s))
    (wat.kernel/println (user/get (wat.core/nth xs 1)))
    (wat.kernel/println (user/get (wat.core/nth xs 2)))))
