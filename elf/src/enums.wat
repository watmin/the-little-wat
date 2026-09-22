(:wat::core::defenum :user::Kind :wat::enum::Pure
  :List []
  :Sym []
  :Int [])

(wat.core/defn user/pick [n :- wat.type/i64] :- :user::Kind
  (wat.core/if (wat.core/= n 0) (:user::Kind.List {})
    (wat.core/if (wat.core/= n 1) (:user::Kind.Sym {}) (:user::Kind.Int {}))))

(wat.core/defn user/name-of [k :- :user::Kind] :- wat.type/String
  (wat.core/cond
    ((wat.core/= k (:user::Kind.List {})) "list")
    ((wat.core/= k (:user::Kind.Sym {}))  "sym")
    (:else "int")))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    (wat.kernel/println (user/name-of (user/pick 0)))
    (wat.kernel/println (user/name-of (user/pick 1)))
    (wat.kernel/println (user/name-of (user/pick 2)))))
