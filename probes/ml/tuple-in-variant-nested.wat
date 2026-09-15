;; tuple-in-variant-nested.wat (b): ML's rem_anchovy shape, Topping(Anchovy, p), as a tuple sub-pattern
;; holding a nested variant, {:t ([:u::Fish.Anchovy {}] rest)}, then a binder fallback for
;; the other fish, {:t (other rest)}. Counts non-anchovy toppings. Expected: 1
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
    [:u::Pizza.Topping {:t (other rest)} (:wat::core::+ 1 (:u::count rest))]))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:u::count (:u::top (:u::Fish.Anchovy {}) (:u::top (:u::Fish.Lox {}) (:u::top (:u::Fish.Anchovy {}) (:u::bottom)))))))
