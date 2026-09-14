;; let-fn-unknown-symbol.wat: an F-007 discriminator. A let-bound fn whose body calls a
;; name that exists NOWHERE (zzz). If startup accepts this too, the checker does not
;; resolve bare names inside fn bodies at all. If startup refuses it, the checker only lets
;; a let binding see its OWN name.
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [g (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::i64
         (zzz n))]
    (:wat::kernel::println (g 5))))
