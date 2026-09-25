;; Stone 6 adversarial: a Some of a Vector held in a Vector of the parent, read out, conj'd by the callee; the original keeps length 3.
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])
(wat.core/defn user/n [o :- (:user::Opt :- [(wat.core/Vector :- [wat.type/i64])])] :- wat.type/i64
  (:wat::core::match o [:user::Opt.None {} -1] [:user::Opt.Some {:value v} (wat.core/length (wat.core/conj v 9))]))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [v (wat.core/Vector :- [wat.type/i64] 1 2 3)
                 s (:user::Opt.Some {:value v})
                 xs (wat.core/Vector :- [(:user::Opt :- [(wat.core/Vector :- [wat.type/i64])])] s (:user::Opt.None {}) s)]
    (wat.kernel/println (user/n (wat.core/nth xs 0)))
    (wat.kernel/println (user/n (wat.core/nth xs 1)))
    (wat.kernel/println (user/n (wat.core/nth xs 2)))
    (wat.kernel/println (wat.core/length v))))
