;; a type recursive THROUGH a Vector: each Node holds a Vector of T. Nested 200,000 deep, then dropped.
(:wat::core::defenum :user::T :wat::enum::Pure
  :Leaf []
  :Tag  [n <- :wat::core::i64]
  :Node [kids <- (:wat::core::Vector :- [:user::T])])

(wat.core/defn user/nest [i :- wat.type/i64 acc :- :user::T] :- :user::T
  (wat.core/if (wat.core/= i 0) acc
    (user/nest (wat.core/- i 1)
      (:user::T.Node {:kids (wat.core/conj (wat.core/Vector :- [:user::T]) acc)}))))

(wat.core/defn user/build-and-drop [n :- wat.type/i64] :- wat.type/i64
  (wat.core/let [t (user/nest n (:user::T.Leaf {}))]
    n))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.i64/to-string (user/build-and-drop 2000000))))
