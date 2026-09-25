;; a function type as an enum's type argument, and a function type whose argument is that enum.
;; The spelling nests both ways: `henum:Box;fn:…` and `fn:…henum:Box;…`.
(:wat::core::defenum :user::Box :- [T] :wat::enum::Pure
  :Full [value <- :T])
(wat.core/defn user/inc [x :- wat.type/i64] :- wat.type/i64 (wat.core/+ x 1))
(wat.core/defn user/box [f :- [wat.type/i64 :-> wat.type/i64]]
    :- (:user::Box.Full :- [[wat.type/i64 :-> wat.type/i64]])
  (:user::Box.Full {:value f}))
(wat.core/defn user/unbox [b :- (:user::Box :- [[wat.type/i64 :-> wat.type/i64]])] :- wat.type/i64
  (:wat::core::match b [:user::Box.Full {:value f} (f 2)]))
(wat.core/defn user/main [] :- wat.type/nil (wat.kernel/println (user/unbox (user/box user/inc))))
