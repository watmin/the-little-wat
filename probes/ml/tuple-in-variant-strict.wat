;; tuple-in-variant-strict.wat (c): the no-catch-all version of (b). Topping is covered by three nested
;; arms, one per fish (Anchovy, Lox, Tuna), and no binder fallback. That is complete
;; coverage, but written only in nested arms. Accepted, or refused like C-021's partial case?
;; Expected (if the checker sees the product): 1
(:wat::core::defenum :u::Fish :wat::enum::Pure :Anchovy [] :Lox [] :Tuna [])
(:wat::core::defenum :u::Pizza :- [A] :wat::enum::Pure
  :Bottom []
  :Topping [t <- (:wat::core::Tuple :- [A (:u::Pizza :- [A])])])
(:wat::core::defn :u::top [x <- :u::Fish p <- (:u::Pizza :- [:u::Fish])] -> (:u::Pizza :- [:u::Fish])
  (:u::Pizza.Topping {:t (:wat::core::Tuple x p)}))
(:wat::core::defn :u::bottom [] -> (:u::Pizza :- [:u::Fish]) (:u::Pizza.Bottom {}))
(:wat::core::defn :u::count [p <- (:u::Pizza :- [:u::Fish])] -> :wat::core::i64
  (:wat::core::match p
    [:u::Pizza.Bottom {} 0]
    [:u::Pizza.Topping {:t ([:u::Fish.Anchovy {}] rest)} (:u::count rest)]
    [:u::Pizza.Topping {:t ([:u::Fish.Lox {}] rest)} (:wat::core::+ 1 (:u::count rest))]
    [:u::Pizza.Topping {:t ([:u::Fish.Tuna {}] rest)} (:wat::core::+ 1 (:u::count rest))]))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:u::count (:u::top (:u::Fish.Anchovy {}) (:u::top (:u::Fish.Lox {}) (:u::top (:u::Fish.Anchovy {}) (:u::bottom)))))))
