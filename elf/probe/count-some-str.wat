;; Stone 6. A Some of a String literal IS that literal. The count keeps the literal guard and
;; drops only the tag test: a bare incq writes the read-only page.
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])

(wat.core/defn user/bang [s :- (:user::Opt.Some :- [wat.type/String])] :- wat.type/i64
  (wat.core/let [{:keys [value]} s]
    (wat.string/length (wat.string/concat value "!"))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [s (:user::Opt.Some {:value "ab"})]
    (wat.kernel/println (user/bang s))
    (wat.kernel/println (wat.string/length
      (:wat::core::match s [:user::Opt.Some {:value v} v] [:user::Opt.None {} ""])))))
