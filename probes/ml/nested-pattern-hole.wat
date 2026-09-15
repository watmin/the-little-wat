;; nested-pattern-hole.wat: Onion is covered ONLY by a nested arm (an Onion whose field is an
;; Onion). An Onion around a Lamb matches no arm. Does exhaustiveness see inside nested
;; patterns and refuse this at startup, or does the hole surface only at runtime?
;; Expected (doctrine: an arm cannot be forgotten): refused at startup, naming the hole.
(:wat::core::defenum :u::Kebab :wat::enum::Pure
  :Skewer []
  :Onion [k <- :u::Kebab]
  :Lamb  [k <- :u::Kebab])
(:wat::core::defn :u::describe [k <- :u::Kebab] -> :wat::core::String
  (:wat::core::match k
    [:u::Kebab.Skewer {} "skewer"]
    [:u::Kebab.Onion {:k [:u::Kebab.Onion {:k inner}]} "two-onions"]
    [:u::Kebab.Lamb {:k rest} "lamb"]))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:u::describe (:u::Kebab.Onion {:k (:u::Kebab.Lamb {:k (:u::Kebab.Skewer {})})}))))
