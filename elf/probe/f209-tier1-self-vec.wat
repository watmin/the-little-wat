;; a type recursive THROUGH a Vector: each Node holds a Vector of T. Nested 200,000 deep, then dropped.
(:wat::core::defenum :user::T :wat::enum::Pure
  :Leaf []
  :Node [kids <- (:wat::core::Vector :- [:user::T])])
(wat.core/defn user/main [] :- wat.type/nil (wat.kernel/println "1"))
