;; nested-pattern-positional.wat: nested-pattern.wat with the inner variant written
;; positionally, (:u::Kebab.Onion inner), in the field's position, the shape the checker's
;; Option message uses for narrowing patterns, `(Some (1 _))`. No catch-all arm.
;; Expected: two-onions, then one-onion
(:wat::core::defenum :u::Kebab :wat::enum::Pure
  :Skewer []
  :Onion [k <- :u::Kebab]
  :Lamb  [k <- :u::Kebab])
(:wat::core::defn :u::describe [k <- :u::Kebab] -> :wat::core::String
  (:wat::core::match k
    [:u::Kebab.Skewer {} "skewer"]
    [:u::Kebab.Onion {:k (:u::Kebab.Onion inner)} "two-onions"]
    [:u::Kebab.Onion {:k other} "one-onion"]
    [:u::Kebab.Lamb {:k rest} "lamb"]))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:u::describe (:u::Kebab.Onion {:k (:u::Kebab.Onion {:k (:u::Kebab.Skewer {})})})))
    (:wat::kernel::println (:u::describe (:u::Kebab.Onion {:k (:u::Kebab.Lamb {:k (:u::Kebab.Skewer {})})})))))
