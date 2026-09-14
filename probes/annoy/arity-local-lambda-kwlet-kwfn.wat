;; F-014 2x2, corner: keyword let + keyword fn. A let-bound lambda called with the wrong
;; arity through its bare name f. Startup (exit 3) or runtime (exit 1)?
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [f (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64 x)]
    (:wat::kernel::println (f 1 2))))
