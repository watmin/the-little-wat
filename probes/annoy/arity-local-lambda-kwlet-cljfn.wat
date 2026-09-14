;; F-014 2x2, corner: keyword let + Clojure fn.
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [f (wat.core/fn [x :- wat.type/i64] :- wat.type/i64 x)]
    (:wat::kernel::println (f 1 2))))
