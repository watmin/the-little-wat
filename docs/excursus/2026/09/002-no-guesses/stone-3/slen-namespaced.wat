;; F-196 probe, NAMESPACED spelling: a wrong-typed call (i64 into a :user::S parameter).
(:wat::core::defenum :user::S :wat::enum::Pure
  :None []
  :Some [s <- :wat::core::String])

(wat.core/defn user/slen [o :- :user::S] :- wat.type/i64
  (:wat::core::match o [:user::S.None {} 0] [:user::S.Some {:s s} (wat.string/length s)]))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [k (user/slen 5)]
    (wat.kernel/println k)))
