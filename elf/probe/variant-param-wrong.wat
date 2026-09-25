;; Stone 5: a None where a Some is wanted. wat --check refuses it; the compiler must refuse it too.
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])
(wat.core/defn user/needs-opt [o :- (:user::Opt :- [wat.type/String])] :- wat.type/i64
  (:wat::core::match o [:user::Opt.Some {:value v} (wat.string/length v)] [:user::Opt.None {} 0]))
;; wants the VARIANT; uses it by handing it to a function that wants the PARENT (Liskov)
(wat.core/defn user/needs-some [s :- (:user::Opt.Some :- [wat.type/String])] :- wat.type/i64
  (user/needs-opt s))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    (wat.kernel/println (user/needs-some (:user::Opt.None {})))
    (wat.kernel/println (user/needs-opt  (:user::Opt.Some {:value "abc"})))
    (wat.kernel/println (user/needs-opt  (:user::Opt.None {})))))
