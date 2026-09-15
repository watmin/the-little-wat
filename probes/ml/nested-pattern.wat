;; nested-pattern.wat: can one match arm destructure a variant inside a variant, as ML's
;; `Onion(Onion(x))` does? No catch-all arm (the builder's doctrine: no `_`).
;; Expected: two-onions
(:wat::core::defenum :u::Kebab :wat::enum::Pure
  :Skewer []
  :Onion [k <- :u::Kebab]
  :Lamb  [k <- :u::Kebab])
(:wat::core::defn :u::describe [k <- :u::Kebab] -> :wat::core::String
  (:wat::core::match k
    [:u::Kebab.Skewer {} "skewer"]
    [:u::Kebab.Onion {:k (:u::Kebab.Onion {:k _inner})} "two-onions"]
    [:u::Kebab.Onion {:k _other} "one-onion"]
    [:u::Kebab.Lamb {:k _rest} "lamb"]))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:u::describe (:u::Kebab.Onion {:k (:u::Kebab.Onion {:k (:u::Kebab.Skewer {})})}))))
