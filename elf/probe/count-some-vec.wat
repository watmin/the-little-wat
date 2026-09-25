;; Stone 6. A Some of a Vector is the Vector: never a unit tag, never a literal. The count is a
;; bare incq. Missing it lets the callee extend the vector the Some still holds.
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])
(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))

(wat.core/defn user/grow [xs :- :user::Row] :- wat.type/i64
  (wat.core/length (wat.core/conj xs 9)))

(wat.core/defn user/via [s :- (:user::Opt.Some :- [:user::Row])] :- wat.type/i64
  (wat.core/let [{:keys [value]} s] (user/grow value)))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [s (:user::Opt.Some {:value (wat.core/Vector :- [wat.type/i64] 1 2 3)})]
    (wat.kernel/println (user/via s))
    (wat.kernel/println (wat.core/length
      (:wat::core::match s [:user::Opt.Some {:value v} v] [:user::Opt.None {} (wat.core/Vector :- [wat.type/i64])])))))
