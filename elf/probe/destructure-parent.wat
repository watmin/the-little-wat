;; Stone 5b fixture -- {:keys} on the PARENT. wat --check refuses it ("expects an aggregate type");
;; the native compiler must refuse it too.
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])
;; destructuring the PARENT, not a variant -- must the checker refuse it?
(wat.core/defn user/bad [o :- (:user::Opt :- [wat.type/String])] :- wat.type/i64
  (wat.core/let [{:keys [value]} o] (wat.string/length value)))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/bad (:user::Opt.Some {:value "ab"}))))
