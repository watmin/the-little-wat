;; nested-pattern-vector.wat: the canonical nested variant sub-pattern, [Variant {:k v}] with
;; no body (check.rs:7894), in a field's position. Every arm explicit, no catch-all.
;; Expected: two-onions, then one-onion
(:wat::core::defenum :u::Kebab :wat::enum::Pure
  :Skewer []
  :Onion [k <- :u::Kebab]
  :Lamb  [k <- :u::Kebab])
(:wat::core::defn :u::describe [k <- :u::Kebab] -> :wat::core::String
  (:wat::core::match k
    [:u::Kebab.Skewer {} "skewer"]
    [:u::Kebab.Onion {:k [:u::Kebab.Onion {:k inner}]} "two-onions"]
    [:u::Kebab.Onion {:k other} "one-onion"]
    [:u::Kebab.Lamb {:k rest} "lamb"]))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:u::describe (:u::Kebab.Onion {:k (:u::Kebab.Onion {:k (:u::Kebab.Skewer {})})})))
    (:wat::kernel::println (:u::describe (:u::Kebab.Onion {:k (:u::Kebab.Lamb {:k (:u::Kebab.Skewer {})})})))))
