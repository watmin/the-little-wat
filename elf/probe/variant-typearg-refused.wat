;; F-201. A valid program the native compiler refuses: a Some of a unit-enum VARIANT passed where
;; (Opt :- [Color]) is wanted. Interpreter: 2|2|0. Refused at HEAD and at stone 6 alike.
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])
(:wat::core::defenum :user::Color :wat::enum::Pure :Red [] :Green [])
(wat.core/defn user/c [o :- (:user::Opt :- [:user::Color])] :- wat.type/i64
  (:wat::core::match o [:user::Opt.None {} 0]
    [:user::Opt.Some {:value v} (:wat::core::match v [:user::Color.Red {} 1] [:user::Color.Green {} 2])]))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [a (:user::Opt.Some {:value (:user::Color.Red {})})
                 b (:user::Opt.Some {:value (:user::Color.Green {})})
                 xs (wat.core/Vector :- [(:user::Opt :- [:user::Color])] a b (:user::Opt.None {}))]
    (wat.kernel/println (wat.core/+ (user/c a) (user/c a)))
    (wat.kernel/println (user/c (wat.core/nth xs 1)))
    (wat.kernel/println (user/c (wat.core/nth xs 2)))))
