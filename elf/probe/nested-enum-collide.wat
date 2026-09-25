;; F-200. `Opt<Opt<String>>` was tier 1 because its payload is a pointer type -- but that pointer is
;; another enum, which can be a unit tag. `Some(None)` and `None` were then the same word: HEAD
;; native prints 0|0, the interpreter 1|0. A silent wrong answer.
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])
(wat.core/defn user/none [] :- (:user::Opt :- [wat.type/String]) (:user::Opt.None {}))
(wat.core/defn user/which [o :- (:user::Opt :- [(:user::Opt :- [wat.type/String])])] :- wat.type/i64
  (:wat::core::match o [:user::Opt.None {} 0] [:user::Opt.Some {:value v} 1]))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/which (:user::Opt.Some {:value (user/none)})))
  (wat.kernel/println (user/which (user/outer-none))))
(wat.core/defn user/outer-none [] :- (:user::Opt :- [(:user::Opt :- [wat.type/String])]) (:user::Opt.None {}))
