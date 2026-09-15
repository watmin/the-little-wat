;; tuple-in-variant-binders.wat (a): a variant carrying a tuple, Topping of (a * a pizza), matched
;; with a tuple sub-pattern of binders in the field, {:t (x rest)}. Counts toppings. Expected: 3
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
    [:u::Pizza.Topping {:t (x rest)} (:wat::core::+ 1 (:u::count rest))]))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:u::count (:u::top (:u::Fish.Anchovy {}) (:u::top (:u::Fish.Lox {}) (:u::top (:u::Fish.Anchovy {}) (:u::bottom)))))))
