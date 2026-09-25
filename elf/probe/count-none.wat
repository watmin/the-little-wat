;; Stone 6. A value typed as None is the tag, not a pointer. Counting it at all reads or writes
;; below a small integer. Passing it on must agree, and must not fault.
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])

(wat.core/defn user/hold [n :- (:user::Opt.None :- [wat.type/String])] :- wat.type/i64
  (:wat::core::match n [:user::Opt.None {} 7] [:user::Opt.Some {:value v} (wat.string/length v)]))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [n (:user::Opt.None {})]
    (wat.kernel/println (user/hold n))
    (wat.kernel/println (user/hold n))))
