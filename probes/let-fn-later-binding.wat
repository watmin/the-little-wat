;; let-fn-later-binding.wat: an F-007 discriminator. g's body calls h, which is bound
;; AFTER g in the same let. Does the checker's let scope include later siblings? At runtime
;; g's closure was created before h existed.
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [g (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::i64
         (h n))
     h (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::i64
         (:wat::core::+ n 1))]
    (:wat::kernel::println (g 5))))
